import time

from app.models.enums import RoleName, SessionStatus
from app.models.session import ChatMessage, GameSession
from app.services.session_service import ServiceError
from app.websocket.connection_manager import connection_manager
from app.websocket.events import Ev


async def send_chat(session: GameSession, player_id: str, message: str) -> None:
    """Chat rules (spec §12): dead players never talk; at night only vampires
    talk, and only to each other."""
    player = session.players.get(player_id)
    if player is None:
        raise ServiceError("Unknown player")
    if not player.alive:
        raise ServiceError("Dead players cannot chat")

    message = message.strip()[:500]
    if not message:
        raise ServiceError("Empty message")

    if session.status == SessionStatus.NIGHT:
        if player.role != RoleName.VAMPIRE.value:
            raise ServiceError("Only vampires may chat at night")
        channel = "VAMPIRE"
    else:
        channel = "PUBLIC"

    chat_message = ChatMessage(
        player_id=player_id, nickname=player.nickname, message=message, timestamp=time.time(), channel=channel
    )
    session.chat.append(chat_message)

    payload = {
        "event": Ev.CHAT_MESSAGE,
        "data": {
            "playerId": player_id,
            "nickname": player.nickname,
            "message": message,
            "timestamp": chat_message.timestamp,
            "channel": channel,
        },
    }

    if channel == "VAMPIRE":
        vampire_ids = {p.player_id for p in session.find_by_role(RoleName.VAMPIRE.value)}
        for vid in vampire_ids:
            await connection_manager.send_to(session.session_id, vid, payload)
    else:
        await connection_manager.broadcast(session.session_id, payload)
