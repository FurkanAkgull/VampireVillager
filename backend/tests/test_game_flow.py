import time

from app.game import game_engine
from app.repositories.session_repository import session_repository


def create_and_join(client, n_players=4, active_roles=None):
    """Creates a session with `n_players` total (host + n_players-1 joiners)."""
    active_roles = active_roles or {"VAMPIRE": 1, "DOCTOR": 1, "MEDIUM": 1}
    resp = client.post(
        "/api/v1/sessions",
        json={"nickname": "Host", "maxPlayers": n_players, "activeRoles": active_roles},
    )
    assert resp.status_code == 200, resp.text
    created = resp.json()
    players = [{"nickname": "Host", "playerId": created["hostPlayerId"], "token": created["token"]}]

    for i in range(n_players - 1):
        r = client.post(
            "/api/v1/sessions/join",
            json={"sessionId": created["sessionId"], "password": created["password"], "nickname": f"P{i}"},
        )
        assert r.status_code == 200, r.text
        j = r.json()
        players.append({"nickname": f"P{i}", "playerId": j["playerId"], "token": j["token"]})

    return created, players


def force_roles(session_id: str, role_by_index, players):
    session = session_repository.get(session_id)
    for i, p in enumerate(players):
        session.players[p["playerId"]].role = role_by_index[i]
    return session


def test_create_and_join_session():
    from fastapi.testclient import TestClient
    from main import app

    with TestClient(app) as client:
        created, players = create_and_join(client, n_players=3)
        assert len(created["sessionId"]) == 5
        assert created["sessionId"].isdigit()

        state = client.get(
            f"/api/v1/sessions/{created['sessionId']}/state",
            params={"playerId": players[0]["playerId"], "token": players[0]["token"]},
        ).json()
        assert len(state["players"]) == 3
        assert state["status"] == "WAITING"


def test_join_with_wrong_password_rejected(client):
    created, _ = create_and_join(client, n_players=2)
    r = client.post(
        "/api/v1/sessions/join",
        json={"sessionId": created["sessionId"], "password": "0000", "nickname": "Eve"},
    )
    assert r.status_code == 403


def test_join_nonexistent_session(client):
    r = client.post(
        "/api/v1/sessions/join", json={"sessionId": "99999", "password": "0000", "nickname": "Eve"}
    )
    assert r.status_code == 404


def test_join_full_session_rejected(client):
    created, _ = create_and_join(client, n_players=2)
    r = client.post(
        "/api/v1/sessions/join",
        json={"sessionId": created["sessionId"], "password": created["password"], "nickname": "Extra"},
    )
    assert r.status_code == 409


def test_only_host_can_start(client):
    created, players = create_and_join(client, n_players=2)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"]},
    )
    assert r.status_code == 403


def test_role_assignment_mandatory_roles(client):
    created, players = create_and_join(client, n_players=6, active_roles={"VAMPIRE": 2, "DOCTOR": 1, "MEDIUM": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = session_repository.get(created["sessionId"])
    roles = [p.role for p in session.players.values()]
    assert roles.count("VAMPIRE") >= 1
    assert roles.count("VILLAGER") >= 1
    assert all(r in ("VAMPIRE", "VILLAGER", "DOCTOR", "MEDIUM") for r in roles)


def test_role_hidden_from_other_players(client):
    created, players = create_and_join(client, n_players=3)
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    state = client.get(
        f"/api/v1/sessions/{created['sessionId']}/state",
        params={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    ).json()
    me = next(p for p in state["players"] if p["playerId"] == players[0]["playerId"])
    others = [p for p in state["players"] if p["playerId"] != players[0]["playerId"]]
    assert me["role"] in ("VAMPIRE", "VILLAGER", "DOCTOR", "MEDIUM")
    assert all(o["role"] == "UNKNOWN" for o in others)


def test_vampire_kill_without_doctor_save(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER"], players)

    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={
            "playerId": players[0]["playerId"],
            "token": players[0]["token"],
            "action": "KILL",
            "targetId": players[1]["playerId"],
        },
    )
    assert r.status_code == 200, r.text

    time.sleep(0.5)  # early-resolution fires almost immediately once all night actors have acted
    assert session.players[players[1]["playerId"]].alive is False
    assert session.status.value == "DAY"


def test_doctor_saves_vampire_target(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(created["sessionId"], ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER"], players)

    client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"], "action": "KILL", "targetId": players[2]["playerId"]},
    )
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"], "action": "PROTECT", "targetId": players[2]["playerId"]},
    )
    assert r.status_code == 200, r.text

    time.sleep(2.5)
    assert session.players[players[2]["playerId"]].alive is True


def test_invalid_action_wrong_role_rejected(client):
    created, players = create_and_join(client, n_players=3, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    force_roles(created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER"], players)

    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"], "action": "KILL", "targetId": players[2]["playerId"]},
    )
    assert r.status_code == 400


def test_action_before_game_started_rejected(client):
    created, players = create_and_join(client, n_players=3)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"], "action": "KILL", "targetId": players[1]["playerId"]},
    )
    assert r.status_code == 400


def test_duplicate_action_submission_rejected(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    force_roles(created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER"], players)

    ok = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"], "action": "KILL", "targetId": players[1]["playerId"]},
    )
    assert ok.status_code == 200
    dup = client.post(
        f"/api/v1/sessions/{created['sessionId']}/action",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"], "action": "KILL", "targetId": players[2]["playerId"]},
    )
    assert dup.status_code == 400


def _reach_day_via_vampire_kill(client, session_id, players, vampire_index=0, victim_index=1):
    """Drives NIGHT -> DAY through the real request path (never call game_engine
    phase functions directly outside a request: asyncio.run() would tear down the
    loop before the spawned resolver task gets to run)."""
    r = client.post(
        f"/api/v1/sessions/{session_id}/action",
        json={
            "playerId": players[vampire_index]["playerId"],
            "token": players[vampire_index]["token"],
            "action": "KILL",
            "targetId": players[victim_index]["playerId"],
        },
    )
    assert r.status_code == 200, r.text
    time.sleep(0.5)


def test_voting_eliminates_top_target(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(
        created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER", "VILLAGER"], players
    )
    _reach_day_via_vampire_kill(client, created["sessionId"], players, victim_index=1)
    assert session.status.value == "DAY"

    target = players[2]["playerId"]
    for voter in [players[0], players[2], players[3], players[4]]:  # all 4 alive -> early resolution
        r = client.post(
            f"/api/v1/sessions/{created['sessionId']}/vote",
            json={"playerId": voter["playerId"], "token": voter["token"], "targetId": target},
        )
        assert r.status_code == 200, r.text

    time.sleep(0.5)
    assert session.players[target].alive is False


def test_vote_by_dead_player_rejected(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER"], players)
    _reach_day_via_vampire_kill(client, created["sessionId"], players, victim_index=1)
    assert session.status.value == "DAY"
    assert session.players[players[1]["playerId"]].alive is False

    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/vote",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"], "targetId": players[2]["playerId"]},
    )
    assert r.status_code == 400


def test_villagers_win_when_no_vampires_left(client):
    created, players = create_and_join(client, n_players=3, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(created["sessionId"], ["VAMPIRE", "VILLAGER", "VILLAGER"], players)
    session.players[players[0]["playerId"]].alive = False

    winner = game_engine.check_win_condition(session)
    assert winner == "VILLAGERS"


def test_vampires_win_when_equal_to_villagers(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 2})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = force_roles(created["sessionId"], ["VAMPIRE", "VAMPIRE", "VILLAGER", "VILLAGER"], players)
    session.players[players[3]["playerId"]].alive = False  # 2 vampires vs 1 villager

    winner = game_engine.check_win_condition(session)
    assert winner == "VAMPIRES"


def test_player_leaving_updates_list(client):
    created, players = create_and_join(client, n_players=3)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/leave",
        json={"playerId": players[2]["playerId"], "token": players[2]["token"]},
    )
    assert r.status_code == 200
    session = session_repository.get(created["sessionId"])
    assert players[2]["playerId"] not in session.players


def test_host_leaving_reassigns_host(client):
    created, players = create_and_join(client, n_players=3)
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/leave",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    assert r.status_code == 200
    session = session_repository.get(created["sessionId"])
    assert session.host_player_id != players[0]["playerId"]
    assert session.players[session.host_player_id].is_host is True


def test_last_player_leaving_closes_session(client):
    created, players = create_and_join(client, n_players=2)
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/leave",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"]},
    )
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/leave",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    assert session_repository.get(created["sessionId"]) is None


def test_duplicate_session_ids_never_collide(monkeypatch, client):
    calls = {"n": 0}
    fixed_ids = ["11111", "11111", "22222"]

    def fake_generate():
        v = fixed_ids[calls["n"]]
        calls["n"] += 1
        return v

    monkeypatch.setattr("app.services.session_service.generate_session_id", fake_generate)

    r1 = client.post("/api/v1/sessions", json={"nickname": "A", "maxPlayers": 2})
    r2 = client.post("/api/v1/sessions", json={"nickname": "B", "maxPlayers": 2})
    assert r1.json()["sessionId"] == "11111"
    assert r2.json()["sessionId"] == "22222"  # first 11111 retry skipped since it's taken


def test_chat_rejected_for_dead_player(client):
    created, players = create_and_join(client, n_players=3)
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = session_repository.get(created["sessionId"])
    session.players[players[1]["playerId"]].alive = False

    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/chat",
        json={"playerId": players[1]["playerId"], "token": players[1]["token"], "message": "hi"},
    )
    assert r.status_code == 400


def test_reconnection_preserves_state(client):
    created, players = create_and_join(client, n_players=2)
    pid, token = players[1]["playerId"], players[1]["token"]

    with client.websocket_connect(f"/ws/{created['sessionId']}?playerId={pid}&token={token}") as ws1:
        first = ws1.receive_json()
        assert first["event"] == "GAME_STATE_UPDATED"

    session = session_repository.get(created["sessionId"])
    time.sleep(0.2)  # server-side disconnect handler runs slightly after the client-side close returns
    assert session.players[pid].connected is False  # disconnected, but not removed (spec §16)

    with client.websocket_connect(f"/ws/{created['sessionId']}?playerId={pid}&token={token}") as ws2:
        state = ws2.receive_json()
        assert state["data"]["sessionId"] == created["sessionId"]
        assert session.players[pid].connected is True


def test_reconnection_wrong_token_rejected(client):
    created, players = create_and_join(client, n_players=2)
    import pytest as _pytest
    from starlette.websockets import WebSocketDisconnect as WSD

    with _pytest.raises(WSD):
        with client.websocket_connect(
            f"/ws/{created['sessionId']}?playerId={players[1]['playerId']}&token=wrong"
        ):
            pass


def test_phase_timer_fields_present(client):
    created, players = create_and_join(client, n_players=3, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = session_repository.get(created["sessionId"])
    assert session.phase_started_at is not None
    assert session.phase_ends_at is not None
    assert session.phase_ends_at > session.phase_started_at


def test_night_times_out_and_advances_to_day(client):
    created, players = create_and_join(client, n_players=3, active_roles={"VAMPIRE": 1})
    client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    session = session_repository.get(created["sessionId"])
    assert session.status.value == "NIGHT"
    time.sleep(1.5)  # night_seconds=1 -> should auto-resolve with no actions taken.
    # (day_seconds is also 1 in tests, so don't wait long enough to cycle past DAY too.)
    assert session.status.value == "DAY"
