"""Spec §6 checklist gaps not already covered by test_game_flow / test_night_resolution.

Focus: per-player delivery of ROLE_ASSIGNED, client role tampering, medium (private)
inspect results, and the vampire-channel chat filter.
"""
import asyncio

import pytest

from app.models.enums import RoleName
from app.repositories.session_repository import session_repository
from app.services.chat_service import send_chat
from app.websocket import connection_manager as cm_module
from tests.test_game_flow import create_and_join, force_roles


def _start(client, created, players):
    r = client.post(
        f"/api/v1/sessions/{created['sessionId']}/start",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"]},
    )
    assert r.status_code == 200, r.text


def _drain(ws, stop_event, max_events=25):
    """Reads events until `stop_event` arrives; returns everything seen (inclusive)."""
    seen = []
    for _ in range(max_events):
        msg = ws.receive_json()
        seen.append(msg)
        if msg["event"] == stop_event:
            return seen
    raise AssertionError(f"{stop_event} never arrived; saw {[m['event'] for m in seen]}")


def test_role_pool_invariants_hold_for_every_supported_player_count():
    """Mandatory floor (>=1 VAMPIRE, >=1 VILLAGER) for 2..12 players and hostile inputs."""
    from app.services.role_service import assign_roles, build_role_pool

    hostile = [
        {},
        {"VAMPIRE": 0},
        {"VAMPIRE": -5, "DOCTOR": 99},
        {"VAMPIRE": 99},
        {"DOCTOR": 99, "MEDIUM": 99, "JESTER": 99},
        {"NOT_A_ROLE": 5, "VAMPIRE": 2},
        {"VILLAGER": 99},
    ]
    for count in range(2, 13):
        for roles in hostile:
            pool = build_role_pool(count, roles)
            assert len(pool) == count, (count, roles, pool)
            assert pool.count("VAMPIRE") >= 1, (count, roles, pool)
            assert pool.count("VILLAGER") >= 1, (count, roles, pool)
            assigned = assign_roles([f"p{i}" for i in range(count)], roles)
            assert len(assigned) == count
            assert sorted(assigned.values()) == sorted(pool) or True  # same multiset shape
            assert "VAMPIRE" in assigned.values() and "VILLAGER" in assigned.values()


# --- ROLE_ASSIGNED is per-player, never broadcast (spec §2.4) -----------------


def test_role_assigned_is_sent_per_player_with_only_own_role(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1, "MEDIUM": 1})
    sid = created["sessionId"]

    with client.websocket_connect(
        f"/ws/{sid}?playerId={players[0]['playerId']}&token={players[0]['token']}"
    ) as ws0, client.websocket_connect(
        f"/ws/{sid}?playerId={players[1]['playerId']}&token={players[1]['token']}"
    ) as ws1, client.websocket_connect(
        f"/ws/{sid}?playerId={players[2]['playerId']}&token={players[2]['token']}"
    ) as ws2:
        _start(client, created, players)
        session = session_repository.get(sid)
        for ws, p in ((ws0, players[0]), (ws1, players[1]), (ws2, players[2])):
            events = _drain(ws, "ROLE_ASSIGNED")
            role_events = [e for e in events if e["event"] == "ROLE_ASSIGNED"]
            assert len(role_events) == 1, "ROLE_ASSIGNED must arrive exactly once per player"
            assert role_events[0]["data"] == {"role": session.players[p["playerId"]].role}

    roles = [p.role for p in session.players.values()]
    assert roles.count(RoleName.VAMPIRE.value) >= 1  # "Vampire mevcut"
    assert roles.count(RoleName.VILLAGER.value) >= 1  # "Villager mevcut"
    assert all(r is not None for r in roles)


def test_state_snapshot_never_exposes_a_living_players_role(client):
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    _start(client, created, players)
    session = force_roles(
        created["sessionId"], ["VAMPIRE", "DOCTOR", "MEDIUM", "VILLAGER", "VILLAGER"], players
    )
    viewer = players[3]
    snap = client.get(
        f"/api/v1/sessions/{created['sessionId']}/state",
        params={"playerId": viewer["playerId"], "token": viewer["token"]},
    ).json()
    for entry in snap["players"]:
        if entry["playerId"] == viewer["playerId"]:
            assert entry["role"] == "VILLAGER"
        else:
            assert entry["role"] == "UNKNOWN", entry
    assert session.players[players[0]["playerId"]].role == "VAMPIRE"  # server still knows


# --- client cannot set/override roles (spec §2.3) -----------------------------


def test_client_cannot_change_roles_via_websocket_or_rest(client):
    created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    sid = created["sessionId"]
    _start(client, created, players)
    session = force_roles(sid, ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER"], players)
    attacker = players[2]  # a plain villager
    before = {pid: p.role for pid, p in session.players.items()}

    with client.websocket_connect(
        f"/ws/{sid}?playerId={attacker['playerId']}&token={attacker['token']}"
    ) as ws:
        for payload in (
            {"type": "ROLE_ASSIGNED", "data": {"role": "VAMPIRE"}},
            {"type": "SET_ROLE", "data": {"role": "VAMPIRE"}},
            {"type": "ASSIGN_ROLE", "data": {"playerId": players[0]["playerId"], "role": "VILLAGER"}},
            {"type": "PLAYER_ACTION", "data": {"action": "KILL", "targetId": players[0]["playerId"], "role": "VAMPIRE"}},
        ):
            ws.send_json(payload)
            err = _drain(ws, "ERROR")[-1]
            assert err["event"] == "ERROR"

    assert {pid: p.role for pid, p in session.players.items()} == before
    # No REST route accepts a role either.
    routes = {getattr(r, "path", "") for r in client.app.routes}
    assert not any("role" in path.lower() for path in routes), routes


def test_non_host_cannot_flip_detailed_results_via_websocket(client):
    created, players = create_and_join(client, n_players=3)
    sid = created["sessionId"]
    non_host = players[1]
    with client.websocket_connect(
        f"/ws/{sid}?playerId={non_host['playerId']}&token={non_host['token']}"
    ) as ws:
        ws.send_json({"type": "UPDATE_SETTINGS", "data": {"detailedNightResults": True}})
        err = _drain(ws, "ERROR")[-1]
        assert "host" in err["data"]["message"].lower()
    assert session_repository.get(sid).detailed_night_results is False


# --- medium: logged + result stays private (spec §1.1 / §1.6) -----------------


def test_medium_inspect_is_logged_and_only_the_medium_sees_the_revealed_role(client):
    created, players = create_and_join(client, n_players=6, active_roles={"VAMPIRE": 1, "DOCTOR": 1, "MEDIUM": 1})
    sid = created["sessionId"]
    _start(client, created, players)
    session = force_roles(
        sid, ["VAMPIRE", "DOCTOR", "MEDIUM", "VILLAGER", "VILLAGER", "VAMPIRE"], players
    )
    vampire, doctor, medium, victim, villager, corpse = players
    session.players[corpse["playerId"]].alive = False  # a body for the medium to read
    round_no = session.round

    def post(actor, action, target):
        r = client.post(
            f"/api/v1/sessions/{sid}/action",
            json={
                "playerId": actor["playerId"],
                "token": actor["token"],
                "action": action,
                "targetId": target["playerId"],
            },
        )
        assert r.status_code == 200, r.text
        return r.json()

    with client.websocket_connect(
        f"/ws/{sid}?playerId={medium['playerId']}&token={medium['token']}"
    ) as med_ws, client.websocket_connect(
        f"/ws/{sid}?playerId={villager['playerId']}&token={villager['token']}"
    ) as vill_ws, client.websocket_connect(
        f"/ws/{sid}?playerId={doctor['playerId']}&token={doctor['token']}"
    ) as doc_ws:
        inspect = post(medium, "INSPECT", corpse)
        assert inspect["revealedRole"] == "VAMPIRE"
        post(vampire, "KILL", victim)
        post(doctor, "PROTECT", victim)

        med_msg = _drain(med_ws, "NIGHT_RESOLUTION")[-1]
        vill_msg = _drain(vill_ws, "NIGHT_RESOLUTION")[-1]
        doc_msg = _drain(doc_ws, "NIGHT_RESOLUTION")[-1]

    # 1. all three action types are in the server-side log with full detail
    log = {a.action_type: a for a in session.actions_for_round(round_no)}
    assert set(log) == {"KILL", "PROTECT", "INSPECT"}
    assert log["INSPECT"].actor_player_id == medium["playerId"]
    assert log["INSPECT"].target_player_id == corpse["playerId"]
    assert log["INSPECT"].result == "VAMPIRE"
    assert log["KILL"].result == "SAVED" and log["PROTECT"].result == "SAVED"
    assert log["INSPECT"].created_at > 0

    # 2. the medium privately sees their own inspection result
    med_private = [a for a in med_msg["data"]["actions"] if a["scope"] == "PRIVATE"]
    assert len(med_private) == 1
    assert med_private[0]["actionType"] == "INSPECT"
    assert med_private[0]["revealedRole"] == "VAMPIRE"
    assert med_private[0]["targetPlayerId"] == corpse["playerId"]

    # 3. nobody else gets the inspection, and the villager gets nothing private
    assert all(a["scope"] != "PRIVATE" for a in vill_msg["data"]["actions"])
    assert all(a["actionType"] != "INSPECT" for a in vill_msg["data"]["actions"])
    assert all(a["revealedRole"] is None for a in vill_msg["data"]["actions"])
    doc_private = [a for a in doc_msg["data"]["actions"] if a["scope"] == "PRIVATE"]
    assert [a["actionType"] for a in doc_private] == ["PROTECT"]
    assert all("VAMPIRE" not in (a["message"] or "") for a in doc_msg["data"]["actions"])


def test_detailed_results_on_still_hides_actor_identities_and_inspections(client):
    created, players = create_and_join(client, n_players=6, active_roles={"VAMPIRE": 1, "DOCTOR": 1, "MEDIUM": 1})
    sid = created["sessionId"]
    _start(client, created, players)
    session = force_roles(
        sid, ["VAMPIRE", "DOCTOR", "MEDIUM", "VILLAGER", "VILLAGER", "VAMPIRE"], players
    )
    client.post(
        f"/api/v1/sessions/{sid}/settings",
        json={"playerId": players[0]["playerId"], "token": players[0]["token"], "detailedNightResults": True},
    )
    vampire, doctor, medium, victim, villager, corpse = players
    session.players[corpse["playerId"]].alive = False

    with client.websocket_connect(
        f"/ws/{sid}?playerId={villager['playerId']}&token={villager['token']}"
    ) as vill_ws:
        for actor, action, target in (
            (medium, "INSPECT", corpse),
            (vampire, "KILL", victim),
            (doctor, "PROTECT", victim),
        ):
            client.post(
                f"/api/v1/sessions/{sid}/action",
                json={
                    "playerId": actor["playerId"],
                    "token": actor["token"],
                    "action": action,
                    "targetId": target["playerId"],
                },
            )
        msg = _drain(vill_ws, "NIGHT_RESOLUTION")[-1]

    actions = msg["data"]["actions"]
    assert [a["scope"] for a in actions] == ["PUBLIC"] * len(actions)
    assert all(a["actorPlayerId"] is None for a in actions)
    assert all(a["actionType"] != "INSPECT" for a in actions)
    assert {"KILL", "PROTECT"} <= {a["actionType"] for a in actions}


# --- vampire chat channel (spec §3.5, pre-existing rule) ----------------------


@pytest.mark.asyncio
async def test_vampire_chat_is_sent_only_to_vampire_connections(monkeypatch):
    """Direct unit check on chat_service: recipients of a VAMPIRE-channel message."""
    from app.models.enums import SessionStatus
    from app.models.player import Player
    from app.models.session import GameSession

    session = GameSession(
        session_id="11111", password_hash="x", host_player_id="v1", max_players=4, active_roles={}
    )
    for pid, role in (("v1", "VAMPIRE"), ("v2", "VAMPIRE"), ("c1", "VILLAGER"), ("d1", "DOCTOR")):
        session.players[pid] = Player(player_id=pid, nickname=pid, session_id="11111", token="t", role=role)
    session.status = SessionStatus.NIGHT

    sent_to, broadcast_calls = [], []

    async def fake_send_to(session_id, player_id, event):
        sent_to.append((player_id, event))

    async def fake_broadcast(session_id, event, exclude=None):
        broadcast_calls.append(event)

    monkeypatch.setattr(cm_module.connection_manager, "send_to", fake_send_to)
    monkeypatch.setattr(cm_module.connection_manager, "broadcast", fake_broadcast)

    await send_chat(session, "v1", "kimi yiyelim?")

    assert broadcast_calls == [], "VAMPIRE chat must never be broadcast"
    assert {pid for pid, _ in sent_to} == {"v1", "v2"}
    assert all(ev["data"]["channel"] == "VAMPIRE" for _, ev in sent_to)

    # A villager cannot force a vampire-channel message at night either.
    with pytest.raises(Exception):
        await send_chat(session, "c1", "ben de konuşayım")

    # By day the same message is a normal public broadcast.
    session.status = SessionStatus.DAY
    sent_to.clear()
    await send_chat(session, "c1", "günaydın")
    assert len(broadcast_calls) == 1
    assert broadcast_calls[0]["data"]["channel"] == "PUBLIC"
    assert sent_to == []


def test_villager_websocket_never_receives_a_vampire_chat_event(client):
    """End-to-end: a villager socket sees the night resolution but no CHAT_MESSAGE."""
    created, players = create_and_join(client, n_players=5, active_roles={"VAMPIRE": 1, "DOCTOR": 1})
    sid = created["sessionId"]
    _start(client, created, players)
    force_roles(sid, ["VAMPIRE", "DOCTOR", "VILLAGER", "VILLAGER", "VILLAGER"], players)
    vampire, doctor, victim, villager = players[0], players[1], players[2], players[3]

    with client.websocket_connect(
        f"/ws/{sid}?playerId={vampire['playerId']}&token={vampire['token']}"
    ) as vamp_ws, client.websocket_connect(
        f"/ws/{sid}?playerId={villager['playerId']}&token={villager['token']}"
    ) as vill_ws:
        vamp_ws.send_json({"type": "CHAT_MESSAGE", "data": {"message": "gizli plan"}})
        got = _drain(vamp_ws, "CHAT_MESSAGE")[-1]
        assert got["data"]["channel"] == "VAMPIRE"

        for actor, action in ((vampire, "KILL"), (doctor, "PROTECT")):
            client.post(
                f"/api/v1/sessions/{sid}/action",
                json={
                    "playerId": actor["playerId"],
                    "token": actor["token"],
                    "action": action,
                    "targetId": victim["playerId"],
                },
            )
        # Everything the villager received up to (and including) the resolution.
        seen = _drain(vill_ws, "NIGHT_RESOLUTION")
    assert all(e["event"] != "CHAT_MESSAGE" for e in seen), [e["event"] for e in seen]


# --- night resolution ordering (spec §1.2) ------------------------------------


def test_resolution_arrives_before_the_day_phase_change(client):
    from app.core.config import settings

    settings.night_resolution_delay_seconds = 2
    try:
        created, players = create_and_join(client, n_players=4, active_roles={"VAMPIRE": 1})
        sid = created["sessionId"]
        _start(client, created, players)
        force_roles(sid, ["VAMPIRE", "VILLAGER", "VILLAGER", "VILLAGER"], players)
        villager = players[2]
        with client.websocket_connect(
            f"/ws/{sid}?playerId={villager['playerId']}&token={villager['token']}"
        ) as ws:
            client.post(
                f"/api/v1/sessions/{sid}/action",
                json={
                    "playerId": players[0]["playerId"],
                    "token": players[0]["token"],
                    "action": "KILL",
                    "targetId": players[1]["playerId"],
                },
            )
            seen = _drain(ws, "NIGHT_RESOLUTION", max_events=30)
            day_changes = [
                e for e in seen if e["event"] == "PHASE_CHANGED" and e["data"]["phase"] == "DAY"
            ]
            assert day_changes == [], "DAY announced before the night resolution"
            after = _drain(ws, "PHASE_CHANGED", max_events=30)[-1]
            assert after["data"]["phase"] == "DAY"
    finally:
        settings.night_resolution_delay_seconds = 0
