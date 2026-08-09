import asyncio
import time
from collections import Counter
from typing import Dict, List, Optional

from app.core.config import settings
from app.models.enums import RoleName, SessionStatus
from app.models.night_action import (
    ACTION_INSPECT,
    ACTION_KILL,
    ACTION_PROTECT,
    RESULT_KILLED,
    RESULT_PROTECTED,
    RESULT_SAVED,
    RESULT_TARGETED,
    NightAction,
)
from app.models.session import GameSession
from app.services.role_service import assign_roles
from app.websocket.connection_manager import connection_manager
from app.websocket.events import Ev

# sessionId -> pending phase-timeout task. Kept out of the dataclass: asyncio.Task isn't
# meaningfully serializable and every session mutation happens through this module anyway.
_phase_timers: Dict[str, asyncio.Task] = {}

# Sessions currently inside resolve_night(). The resolution holds an await (the spec §1.8
# delay) while status is still NIGHT, so the status check alone can't stop a double resolve.
_resolving: set = set()


class GameError(Exception):
    def __init__(self, message: str):
        self.message = message


def _cancel_timer(session_id: str) -> None:
    task = _phase_timers.pop(session_id, None)
    if task and not task.done():
        task.cancel()


async def start_game(session: GameSession) -> None:
    if session.status != SessionStatus.WAITING:
        raise GameError("Game already started")
    if len(session.players) < 2:
        raise GameError("Not enough players")

    session.status = SessionStatus.STARTING
    roles = assign_roles(list(session.players.keys()), session.active_roles)
    for player_id, role in roles.items():
        session.players[player_id].role = role

    await connection_manager.broadcast(session.session_id, {"event": Ev.GAME_STARTED, "data": {}})
    for player_id, player in session.players.items():
        await connection_manager.send_to(
            session.session_id, player_id, {"event": Ev.ROLE_ASSIGNED, "data": {"role": player.role}}
        )
    await _begin_night(session)


async def _broadcast_phase(session: GameSession) -> None:
    await connection_manager.broadcast_state(session.session_id, session)
    await connection_manager.broadcast(
        session.session_id,
        {
            "event": Ev.PHASE_CHANGED,
            "data": {
                "phase": session.current_phase,
                "round": session.round,
                "startedAt": session.phase_started_at,
                "endsAt": session.phase_ends_at,
            },
        },
    )


async def _begin_night(session: GameSession) -> None:
    _cancel_timer(session.session_id)
    session.status = SessionStatus.NIGHT
    session.current_phase = "NIGHT"
    session.round += 1
    session.night_actions = {}
    session.phase_started_at = time.time()
    session.phase_ends_at = session.phase_started_at + settings.night_seconds
    await _broadcast_phase(session)
    _phase_timers[session.session_id] = asyncio.create_task(
        _phase_timeout(session, settings.night_seconds, resolve_night)
    )


async def _begin_day(session: GameSession) -> None:
    _cancel_timer(session.session_id)
    session.status = SessionStatus.DAY
    session.current_phase = "DAY"
    session.votes = {}
    session.phase_started_at = time.time()
    session.phase_ends_at = session.phase_started_at + settings.day_seconds
    await _broadcast_phase(session)
    await connection_manager.broadcast(session.session_id, {"event": Ev.VOTE_STARTED, "data": {}})
    _phase_timers[session.session_id] = asyncio.create_task(
        _phase_timeout(session, settings.day_seconds, resolve_day)
    )


async def _phase_timeout(session: GameSession, seconds: int, resolver) -> None:
    try:
        await asyncio.sleep(seconds)
        await resolver(session)
    except asyncio.CancelledError:
        pass


def _required_night_actors(session: GameSession) -> int:
    return len(
        [
            p
            for p in session.alive_players()
            if p.role in (RoleName.VAMPIRE.value, RoleName.DOCTOR.value, RoleName.MEDIUM.value)
        ]
    )


async def submit_night_action(session: GameSession, player_id: str, action: str, target_id: Optional[str]) -> dict:
    if session.status != SessionStatus.NIGHT:
        raise GameError("Not night phase")
    player = session.players.get(player_id)
    if player is None or not player.alive:
        raise GameError("Player not alive or not in session")
    if player_id in session.night_actions:
        raise GameError("Action already submitted")

    result: dict = {}
    log_result: Optional[str] = None
    if player.role == RoleName.VAMPIRE.value:
        if action != ACTION_KILL:
            raise GameError("Invalid action for role")
        target = session.players.get(target_id or "")
        if target is None or not target.alive or target.role == RoleName.VAMPIRE.value:
            raise GameError("Invalid target")
        session.night_actions[player_id] = {"action": ACTION_KILL, "target": target_id}
        log_result = RESULT_TARGETED
    elif player.role == RoleName.DOCTOR.value:
        if action != ACTION_PROTECT:
            raise GameError("Invalid action for role")
        target = session.players.get(target_id or "")
        if target is None or not target.alive:
            raise GameError("Invalid target")
        session.night_actions[player_id] = {"action": ACTION_PROTECT, "target": target_id}
        log_result = RESULT_PROTECTED
    elif player.role == RoleName.MEDIUM.value:
        if action != ACTION_INSPECT:
            raise GameError("Invalid action for role")
        target = session.players.get(target_id or "")
        if target is None or target.alive:
            raise GameError("Medium can only inspect dead players")
        session.night_actions[player_id] = {"action": ACTION_INSPECT, "target": target_id}
        result = {"revealedRole": target.role}
        log_result = target.role
    else:
        raise GameError("Role has no night action")

    # Full audit record for the night resolution (spec §1.1). Server-side only.
    session.night_action_log.append(
        NightAction(
            round=session.round,
            actor_player_id=player_id,
            action_type=session.night_actions[player_id]["action"],
            target_player_id=target_id,
            created_at=time.time(),
            result=log_result,
        )
    )

    if len(session.night_actions) >= _required_night_actors(session):
        _cancel_timer(session.session_id)
        asyncio.create_task(resolve_night(session))

    return result


def _nick(session: GameSession, player_id: Optional[str]) -> str:
    player = session.players.get(player_id or "")
    return player.nickname if player else "?"


def _entry(
    action_type: str,
    scope: str,
    message: str,
    actor_role: Optional[str] = None,
    actor_player_id: Optional[str] = None,
    target_player_id: Optional[str] = None,
    target_nickname: Optional[str] = None,
    result: Optional[str] = None,
    revealed_role: Optional[str] = None,
) -> dict:
    return {
        "actionType": action_type,
        "scope": scope,  # PUBLIC (everyone in this session sees it) | PRIVATE (own action only)
        "actorRole": actor_role,
        "actorPlayerId": actor_player_id,
        "targetPlayerId": target_player_id,
        "targetNickname": target_nickname,
        "result": result,
        "revealedRole": revealed_role,
        "message": message,
    }


async def resolve_night(session: GameSession) -> None:
    """Spec §1.2 fixed order: collect -> validate -> vampire -> doctor -> medium ->
    other roles -> deaths -> build resolution -> send -> (server-owned delay) -> DAY.
    Nothing here is client-triggerable; the day never starts before this completes."""
    if session.status != SessionStatus.NIGHT or session.session_id in _resolving:
        return
    _resolving.add(session.session_id)
    try:
        _cancel_timer(session.session_id)
        round_no = session.round

        # --- 1. Collect actions -------------------------------------------------
        records = session.actions_for_round(round_no)

        # --- 2. Validate actions (re-checked server-side at resolve time) --------
        valid: List[NightAction] = []
        for rec in records:
            actor = session.players.get(rec.actor_player_id)
            target = session.players.get(rec.target_player_id or "")
            if actor is None or not actor.alive or target is None:
                continue
            valid.append(rec)

        # --- 3. Resolve vampire action (majority target wins) -------------------
        kill_records = [r for r in valid if r.action_type == ACTION_KILL]
        killed_id: Optional[str] = None
        if kill_records:
            killed_id = Counter([r.target_player_id for r in kill_records]).most_common(1)[0][0]

        # --- 4. Resolve doctor action -------------------------------------------
        protect_records = [r for r in valid if r.action_type == ACTION_PROTECT]
        protected_ids = {r.target_player_id for r in protect_records}

        # --- 5. Resolve medium / seer (private information only) ----------------
        inspect_records = [r for r in valid if r.action_type == ACTION_INSPECT]

        # --- 6. Resolve other roles ---------------------------------------------
        # No further night-acting roles in the MVP role set (VAMPIRE/VILLAGER/DOCTOR/MEDIUM).

        # --- 7. Calculate deaths -------------------------------------------------
        saved = killed_id is not None and killed_id in protected_ids
        players_died: List[str] = []
        players_saved: List[str] = []

        if killed_id and not saved:
            victim = session.players.get(killed_id)
            if victim:
                victim.alive = False
                players_died.append(killed_id)
                await connection_manager.broadcast(
                    session.session_id, {"event": Ev.PLAYER_DIED, "data": {"playerId": killed_id}}
                )
        elif killed_id and saved:
            players_saved.append(killed_id)
            await connection_manager.broadcast(
                session.session_id, {"event": Ev.PLAYER_SAVED, "data": {"playerId": killed_id}}
            )

        # Write final outcomes back into the server-side log.
        for rec in kill_records:
            rec.result = RESULT_KILLED if rec.target_player_id in players_died else (
                RESULT_SAVED if rec.target_player_id in players_saved else RESULT_TARGETED
            )
        for rec in protect_records:
            rec.result = RESULT_SAVED if rec.target_player_id in players_saved else RESULT_PROTECTED

        # --- 8. Create the night resolution --------------------------------------
        summary = {"playersDied": players_died, "playersSaved": players_saved}
        public_actions = _build_public_actions(
            session, killed_id, saved, protect_records, bool(kill_records)
        )
        private_by_player = _build_private_actions(
            session, kill_records, protect_records, inspect_records, players_died, players_saved
        )

        # --- 9. Send results (per player; never one shared payload) ---------------
        await connection_manager.broadcast_state(session.session_id, session)
        for player_id in list(session.players.keys()):
            actions = public_actions + private_by_player.get(player_id, [])
            await connection_manager.send_to(
                session.session_id,
                player_id,
                {
                    "event": Ev.NIGHT_RESOLUTION,
                    "data": {"round": round_no, "summary": summary, "actions": actions},
                },
            )

        # --- 10. Server-owned delay, then DAY (spec §1.8) ------------------------
        delay = max(0, settings.night_resolution_delay_seconds)
        if delay:
            await asyncio.sleep(delay)
    finally:
        _resolving.discard(session.session_id)

    if session.status != SessionStatus.NIGHT:  # game closed/finished while we waited
        return
    winner = check_win_condition(session)
    if winner:
        await finish_game(session, winner)
        return
    await _begin_day(session)


def _build_public_actions(
    session: GameSession,
    killed_id: Optional[str],
    saved: bool,
    protect_records: List[NightAction],
    had_attack: bool,
) -> List[dict]:
    """What every player in the session may see (spec §1.4/§1.5).

    Detailed OFF -> one generic "an attack happened" line, no roles, no targets.
    Detailed ON  -> vampire target + doctor protection, phrased by role, never naming
    the acting players. Medium/Seer inspections are never public.
    """
    if not session.detailed_night_results:
        if not had_attack:
            return []
        return [
            _entry(
                "GENERIC",
                "PUBLIC",
                "Bu gece bir saldırı gerçekleşti.",
            )
        ]

    entries: List[dict] = []
    if killed_id:
        entries.append(
            _entry(
                ACTION_KILL,
                "PUBLIC",
                f"Vampirler {_nick(session, killed_id)} adlı oyuncuyu hedefledi.",
                actor_role=RoleName.VAMPIRE.value,
                target_player_id=killed_id,
                target_nickname=_nick(session, killed_id),
                result=RESULT_SAVED if saved else RESULT_KILLED,
            )
        )
    seen: set = set()
    for rec in protect_records:
        if rec.target_player_id in seen:
            continue
        seen.add(rec.target_player_id)
        entries.append(
            _entry(
                ACTION_PROTECT,
                "PUBLIC",
                f"Doktor {_nick(session, rec.target_player_id)} adlı oyuncuyu korudu.",
                actor_role=RoleName.DOCTOR.value,
                target_player_id=rec.target_player_id,
                target_nickname=_nick(session, rec.target_player_id),
                result=rec.result,
            )
        )
    return entries


def _build_private_actions(
    session: GameSession,
    kill_records: List[NightAction],
    protect_records: List[NightAction],
    inspect_records: List[NightAction],
    players_died: List[str],
    players_saved: List[str],
) -> Dict[str, List[dict]]:
    """Each actor always privately sees the outcome of their OWN action (spec §1.6),
    regardless of the detailed-results setting. Sent only to that actor."""
    out: Dict[str, List[dict]] = {}

    for rec in kill_records:
        nickname = _nick(session, rec.target_player_id)
        outcome = (
            "Hedefiniz öldü." if rec.target_player_id in players_died
            else ("Hedefiniz korundu ve hayatta kaldı." if rec.target_player_id in players_saved else "")
        )
        out.setdefault(rec.actor_player_id, []).append(
            _entry(
                ACTION_KILL,
                "PRIVATE",
                f"Bu gece {nickname} adlı oyuncuyu hedeflediniz. {outcome}".strip(),
                actor_role=RoleName.VAMPIRE.value,
                actor_player_id=rec.actor_player_id,
                target_player_id=rec.target_player_id,
                target_nickname=nickname,
                result=rec.result,
            )
        )

    for rec in protect_records:
        nickname = _nick(session, rec.target_player_id)
        outcome = "Koruman bir saldırıyı engelledi." if rec.target_player_id in players_saved else ""
        out.setdefault(rec.actor_player_id, []).append(
            _entry(
                ACTION_PROTECT,
                "PRIVATE",
                f"Bu gece {nickname} adlı oyuncuyu korudun. {outcome}".strip(),
                actor_role=RoleName.DOCTOR.value,
                actor_player_id=rec.actor_player_id,
                target_player_id=rec.target_player_id,
                target_nickname=nickname,
                result=rec.result,
            )
        )

    for rec in inspect_records:
        nickname = _nick(session, rec.target_player_id)
        revealed = rec.result
        out.setdefault(rec.actor_player_id, []).append(
            _entry(
                ACTION_INSPECT,
                "PRIVATE",
                f"{nickname} adlı oyuncuyu inceledin. Sonuç: {revealed}.",
                actor_role=RoleName.MEDIUM.value,
                actor_player_id=rec.actor_player_id,
                target_player_id=rec.target_player_id,
                target_nickname=nickname,
                result=revealed,
                revealed_role=revealed,
            )
        )

    return out


async def submit_vote(session: GameSession, voter_id: str, target_id: str) -> None:
    if session.status != SessionStatus.DAY:
        raise GameError("Not day phase")
    voter = session.players.get(voter_id)
    target = session.players.get(target_id)
    if voter is None or not voter.alive:
        raise GameError("Only living players may vote")
    if target is None or not target.alive:
        raise GameError("Invalid vote target")
    session.votes[voter_id] = target_id
    await connection_manager.broadcast(
        session.session_id, {"event": Ev.VOTE_CAST, "data": {"voterId": voter_id, "targetId": target_id}}
    )

    if len(session.votes) >= len(session.alive_players()):
        _cancel_timer(session.session_id)
        asyncio.create_task(resolve_day(session))


async def resolve_day(session: GameSession) -> None:
    if session.status != SessionStatus.DAY:
        return

    eliminated_id = None
    if session.votes:
        tally = Counter(session.votes.values())
        top = tally.most_common()
        if len(top) == 1 or top[0][1] > top[1][1]:
            eliminated_id = top[0][0]

    if eliminated_id:
        victim = session.players.get(eliminated_id)
        if victim:
            victim.alive = False
            await connection_manager.broadcast(
                session.session_id,
                {"event": Ev.PLAYER_ELIMINATED, "data": {"playerId": eliminated_id, "role": victim.role}},
            )

    winner = check_win_condition(session)
    if winner:
        await finish_game(session, winner)
        return
    await _begin_night(session)


def check_win_condition(session: GameSession) -> Optional[str]:
    alive = session.alive_players()
    vampires = [p for p in alive if p.role == RoleName.VAMPIRE.value]
    villagers = [p for p in alive if p.role != RoleName.VAMPIRE.value]
    if not vampires:
        return "VILLAGERS"
    if len(vampires) >= len(villagers):
        return "VAMPIRES"
    return None


async def finish_game(session: GameSession, winner: str) -> None:
    _cancel_timer(session.session_id)
    session.status = SessionStatus.FINISHED
    session.current_phase = None
    session.winner = winner
    await connection_manager.broadcast_state(session.session_id, session)
    await connection_manager.broadcast(session.session_id, {"event": Ev.GAME_FINISHED, "data": {"winner": winner}})
