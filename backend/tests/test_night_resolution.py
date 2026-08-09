import time

from app.core.config import settings
from app.repositories.session_repository import session_repository
from app.services.role_service import assign_roles, build_role_pool
from tests.test_game_flow import create_and_join, force_roles


def _start(client, created, players):
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    assert r.status_code == 200, r.text


def _await_event(ws, event_name, max_events=15):
    for _ in range(max_events):
        msg = ws.receive_json()
        if msg["event"] == event_name:
            return msg
    raise AssertionError(f"{event_name} never arrived")


# --- role assignment (spec §2) ------------------------------------------------


def test_role_service_uses_secure_rng():
    import app.services.role_service as rs

    import secrets as _secrets

    assert isinstance(rs._rng, _secrets.SystemRandom)
    assert not hasattr(rs, "random")


def test_role_pool_keeps_mandatory_floor():
    pool = build_role_pool(6, {"VAMPIRE": 2, "DOCTOR": 1, "MEDIUM": 1})
    assert len(pool) == 6
    assert pool.count("VAMPIRE") >= 1
    assert "VILLAGER" in pool

    # Host asked for more special roles than there are seats -> still a valid pool.
    greedy = build_role_pool(3, {"VAMPIRE": 5, "DOCTOR": 5, "MEDIUM": 5})
    assert len(greedy) == 3
    assert "VAMPIRE" in greedy and "VILLAGER" in greedy


def test_assign_roles_is_shuffled():
    ids = [f"p{i}" for i in range(8)]
    orders = {
        tuple(assign_roles(ids, {"VAMPIRE": 2, "DOCTOR": 1, "MEDIUM": 1}).values())
        for _ in range(40)
    }
    assert len(orders) > 1  # not a fixed ordering


# --- night action log (spec §1.1) ---------------------------------------------


def test_night_actions_are_logged_with_round_and_timestamp(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    _start(client, created, players)
    session = force_roles(
        created["sessionId"], ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER", "VILLAGER"], players
    )
    round_no = session.round

    client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={
            "playerId": players[0]["playerId"],
            "token": players[0]["token"],
            "action": "KILL",
            "targetId": players[2]["playerId"],
        },
    )
    log = session.actions_for_round(round_no)
    assert len(log) == 1
    rec = log[0]
    assert rec.action_type == "KILL"
    assert rec.actor_player_id == players[0]["playerId"]
    assert rec.target_player_id == players[2]["playerId"]
    assert rec.created_at > 0
    assert rec.to_dict()["round"] == round_no


# --- host-only settings (spec §1.5) -------------------------------------------


def test_detailed_setting_defaults_off_and_is_in_state(client):
    created, players = create_and_join(client, n_players=3)
    state = client.get(
        f"/api/v1/sessions/{created['sessionId']}/state",
        params={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    ).json()
    assert state["settings"]["detailedNightResults"] is False


def test_only_host_can_change_settings(client):
    created, players = create_and_join(client, n_players=3)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/settings",
        json={
            "playerId": players[1]["playerId"],
            "token": players[1]["token"],
            "detailedNightResults": True,
        },
    )
    assert r.status_code == 403
    assert session_repository.get(created["sessionId"]).detailed_night_results is False

    ok = client.post(
        f"/api/v1/sessions/{created['sessionId']}/settings",
        json={
            "playerId": players[0]["playerId"],
            "token": players[0]["token"],
            "detailedNightResults": True,
        },
    )
    assert ok.status_code == 200
    assert ok.json()["settings"]["detailedNightResults"] is True
    assert session_repository.get(created["sessionId"]).detailed_night_results is True


def test_settings_with_bad_token_rejected(client):
    created, players = create_and_join(client, n_players=2)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/settings",
        json={"playerId": players[0]["playerId"], "token": "wrong", "detailedNightResults": True},
    )
    assert r.status_code == 401


# --- night resolution event (spec §1.4 - §1.8) --------------------------------


def test_night_resolution_hides_details_from_villager_but_shows_own_action_to_vampire(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    _start(client, created, players)
    session = force_roles(
        created["sessionId"], ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER", "VILLAGER"], players
    )
    vampire, doctor, victim, villager = players[0], players[1], players[2], players[3]

    with client.websocket_connect(
        f"/ws/{created['sessionId']}?playerId={vampire['playerId']}&token={vampire['token']}"
    ) as vamp_ws, client.websocket_connect(
        f"/ws/{created['sessionId']}?playerId={villager['playerId']}&token={villager['token']}"
    ) as vill_ws:
        client.post(
            f"/api/v1/sessions/{created['sessionId']}/action",
            json={
                "playerId": vampire["playerId"],
                "token": vampire["token"],
                "action": "KILL",
                "targetId": victim["playerId"],
            },
        )
        client.post(
            f"/api/v1/sessions/{created['sessionId']}/action",
            json={
                "playerId": doctor["playerId"],
                "token": doctor["token"],
                "action": "PROTECT",
                "targetId": victim["playerId"],
            },
        )

        vamp_msg = _await_event(vamp_ws, "NIGHT_RESOLUTION")
        vill_msg = _await_event(vill_ws, "NIGHT_RESOLUTION")

    assert vamp_msg["data"]["summary"]["playersSaved"] == [victim["playerId"]]
    assert vamp_msg["data"]["summary"]["playersDied"] == []
    assert vill_msg["data"]["summary"] == vamp_msg["data"]["summary"]

    # Villager: only the generic line, no roles/targets leaked.
    vill_actions = vill_msg["data"]["actions"]
    assert all(a["scope"] == "PUBLIC" for a in vill_actions)
    assert all(a["actionType"] == "GENERIC" for a in vill_actions)
    assert all(a["targetPlayerId"] is None for a in vill_actions)

    # Vampire: always sees their own action outcome privately.
    own = [a for a in vamp_msg["data"]["actions"] if a["scope"] == "PRIVATE"]
    assert len(own) == 1
    assert own[0]["actionType"] == "KILL"
    assert own[0]["targetPlayerId"] == victim["playerId"]
    assert own[0]["result"] == "SAVED"
    assert session.players[victim["playerId"]].alive is True


def test_detailed_night_results_adds_public_action_lines(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    _start(client, created, players)
    force_roles(
        created["sessionId"], ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER", "VILLAGER"], players
    )
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/settings",
        json={
            "playerId": players[0]["playerId"],
            "token": players[0]["token"],
            "detailedNightResults": True,
        },
    )
    vampire, doctor, victim, villager = players[0], players[1], players[2], players[3]

    with client.websocket_connect(
        f"/ws/{created['sessionId']}?playerId={villager['playerId']}&token={villager['token']}"
    ) as vill_ws:
        client.post(
            f"/api/v1/sessions/{created['sessionId']}/action",
            json={
                "playerId": vampire["playerId"],
                "token": vampire["token"],
                "action": "KILL",
                "targetId": victim["playerId"],
            },
        )
        client.post(
            f"/api/v1/sessions/{created['sessionId']}/action",
            json={
                "playerId": doctor["playerId"],
                "token": doctor["token"],
                "action": "PROTECT",
                "targetId": victim["playerId"],
            },
        )
        msg = _await_event(vill_ws, "NIGHT_RESOLUTION")

    types = [a["actionType"] for a in msg["data"]["actions"]]
    assert "KILL" in types and "PROTECT" in types
    assert "GENERIC" not in types
    # Still no actor identities leaked publicly, and no medium info.
    assert all(a["actorPlayerId"] is None for a in msg["data"]["actions"])
    assert "INSPECT" not in types


def test_day_starts_only_after_the_server_owned_delay(client):
    settings.night_resolution_delay_seconds = 2
    try:
        created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1})
        _start(client, created, players)
        session = force_roles(
            created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER"], players
        )
        client.post(
            f"/api/v1/sessions/{created['sessionId']}/action",
            json={
                "playerId": players[0]["playerId"],
                "token": players[0]["token"],
                "action": "KILL",
                "targetId": players[1]["playerId"],
            },
        )
        time.sleep(0.6)
        assert session.players[players[1]["playerId"]].alive is False  # resolved
        assert session.status.value == "NIGHT"  # but not day yet
        time.sleep(2.0)
        assert session.status.value == "DAY"
    finally:
        settings.night_resolution_delay_seconds = 0
