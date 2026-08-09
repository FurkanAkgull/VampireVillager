import time
import uuid
from typing import Dict, Optional

from app.core.config import settings
from app.core.security import generate_password, generate_session_id, generate_token, hash_password, verify_password
from app.models.enums import RoleName, SessionStatus
from app.models.player import Player
from app.models.session import GameSession
from app.repositories.session_repository import session_repository
from app.websocket.connection_manager import connection_manager
from app.websocket.events import Ev


class ServiceError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code


async def create_session(host_nickname: str, max_players: int, password: Optional[str], active_roles: Dict[str, int]) -> tuple[GameSession, Player, str]:
    if max_players < 2:
        raise ServiceError("maxPlayers must be at least 2")

    async with session_repository.lock():
        session_id = generate_session_id()
        while session_repository.exists(session_id):
            session_id = generate_session_id()

        plain_password = password or generate_password()
        host_id = str(uuid.uuid4())
        host = Player(
            player_id=host_id,
            nickname=host_nickname,
            session_id=session_id,
            token=generate_token(),
            is_host=True,
        )
        session = GameSession(
            session_id=session_id,
            password_hash=hash_password(plain_password),
            host_player_id=host_id,
            max_players=max_players,
            active_roles=active_roles,
        )
        session.players[host_id] = host
        session_repository.add_unlocked(session)

    # Plaintext password only ever returned once, at creation, to the host.
    return session, host, plain_password


async def join_session(session_id: str, password: str, nickname: str) -> tuple[GameSession, Player]:
    session = session_repository.get(session_id)
    if session is None:
        raise ServiceError("Session not found", 404)
    if not verify_password(password, session.password_hash):
        raise ServiceError("Invalid password", 403)
    if session.status != SessionStatus.WAITING:
        raise ServiceError("Session already started", 409)
    if len(session.players) >= session.max_players:
        raise ServiceError("Session is full", 409)

    player_id = str(uuid.uuid4())
    player = Player(
        player_id=player_id,
        nickname=nickname,
        session_id=session_id,
        token=generate_token(),
    )
    session.players[player_id] = player
    await connection_manager.broadcast(
        session_id, {"event": Ev.PLAYER_JOINED, "data": {"playerId": player_id, "nickname": nickname}}
    )
    await connection_manager.broadcast_state(session_id, session)
    return session, player


async def leave_session(session: GameSession, player_id: str) -> None:
    player = session.players.get(player_id)
    if player is None:
        return
    del session.players[player_id]
    connection_manager.disconnect(session.session_id, player_id)

    if not session.players:
        await session_repository.remove(session.session_id)
        return

    await connection_manager.broadcast(
        session.session_id, {"event": Ev.PLAYER_LEFT, "data": {"playerId": player_id}}
    )

    if player.is_host:
        new_host = next(iter(session.players.values()))
        new_host.is_host = True
        session.host_player_id = new_host.player_id
        await connection_manager.broadcast(
            session.session_id, {"event": Ev.HOST_CHANGED, "data": {"hostPlayerId": new_host.player_id}}
        )

    await connection_manager.broadcast_state(session.session_id, session)


async def update_settings(
    session: GameSession, player_id: str, detailed_night_results: Optional[bool]
) -> dict:
    """Host-only game settings (spec §1.5). The caller must already be authenticated;
    host ownership is re-checked here so no client can flip a server-held setting."""
    player = session.players.get(player_id)
    if player is None:
        raise ServiceError("Invalid credentials", 401)
    if not player.is_host:
        raise ServiceError("Only the host can change game settings", 403)

    if detailed_night_results is not None:
        session.detailed_night_results = bool(detailed_night_results)

    payload = {"detailedNightResults": session.detailed_night_results}
    await connection_manager.broadcast(
        session.session_id, {"event": Ev.SETTINGS_UPDATED, "data": payload}
    )
    await connection_manager.broadcast_state(session.session_id, session)
    return payload


def authenticate(session: GameSession, player_id: str, token: str) -> Player:
    player = session.players.get(player_id)
    if player is None or player.token != token:
        raise ServiceError("Invalid credentials", 401)
    return player


async def mark_connected(session: GameSession, player_id: str) -> None:
    player = session.players.get(player_id)
    if player:
        player.connected = True
        player.disconnected_at = None
        await connection_manager.broadcast_state(session.session_id, session)


async def mark_disconnected(session: GameSession, player_id: str) -> None:
    player = session.players.get(player_id)
    if player:
        player.connected = False
        player.disconnected_at = time.time()
        connection_manager.disconnect(session.session_id, player_id)
        await connection_manager.broadcast_state(session.session_id, session)
