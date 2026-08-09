from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.game import game_engine
from app.repositories.session_repository import session_repository
from app.services import session_service
from app.services.chat_service import send_chat
from app.services.session_service import ServiceError
from app.websocket.connection_manager import connection_manager
from app.websocket.events import Ev

router = APIRouter()


@router.websocket("/ws/{session_id}")
async def websocket_endpoint(ws: WebSocket, session_id: str, playerId: str, token: str):
    session = session_repository.get(session_id)
    if session is None:
        await ws.close(code=4404)
        return
    player = session.players.get(playerId)
    if player is None or player.token != token:
        await ws.close(code=4401)
        return

    await connection_manager.connect(session_id, playerId, ws)
    await session_service.mark_connected(session, playerId)

    try:
        while True:
            msg = await ws.receive_json()
            msg_type = msg.get("type")
            data = msg.get("data", {})
            try:
                if msg_type == "CHAT_MESSAGE":
                    await send_chat(session, playerId, data.get("message", ""))
                elif msg_type == "VOTE_CAST":
                    await game_engine.submit_vote(session, playerId, data.get("targetId"))
                elif msg_type == "PLAYER_ACTION":
                    await game_engine.submit_night_action(session, playerId, data.get("action"), data.get("targetId"))
                elif msg_type == "UPDATE_SETTINGS":
                    # Host-only; ownership re-validated server-side (spec §1.5).
                    await session_service.update_settings(
                        session, playerId, data.get("detailedNightResults")
                    )
                else:
                    await ws.send_json({"event": Ev.ERROR, "data": {"message": "Unknown message type"}})
            except (ServiceError, game_engine.GameError) as e:
                await ws.send_json({"event": Ev.ERROR, "data": {"message": e.message}})
    except WebSocketDisconnect:
        await session_service.mark_disconnected(session, playerId)
