from fastapi import APIRouter, HTTPException

from app.api.schemas import (
    ActionRequest,
    ChatRequest,
    CreateSessionRequest,
    CreateSessionResponse,
    JoinSessionRequest,
    JoinSessionResponse,
    LeaveRequest,
    SettingsRequest,
    StartRequest,
    VoteRequest,
)
from app.game import game_engine
from app.repositories.session_repository import session_repository
from app.services import session_service
from app.services.chat_service import send_chat
from app.services.session_service import ServiceError, authenticate

router = APIRouter(prefix="/api/v1/sessions", tags=["sessions"])


def _get_session_or_404(session_id: str):
    session = session_repository.get(session_id)
    if session is None:
        raise HTTPException(404, "Session not found")
    return session


def _as_http_error(exc: Exception) -> HTTPException:
    if isinstance(exc, (ServiceError,)):
        return HTTPException(exc.status_code, exc.message)
    if isinstance(exc, game_engine.GameError):
        return HTTPException(400, exc.message)
    return HTTPException(400, str(exc))


@router.post("", response_model=CreateSessionResponse)
async def create_session(body: CreateSessionRequest):
    try:
        session, host, plain_password = await session_service.create_session(
            body.nickname, body.maxPlayers, body.password, body.activeRoles
        )
    except ServiceError as e:
        raise _as_http_error(e)
    return CreateSessionResponse(
        sessionId=session.session_id, password=plain_password, hostPlayerId=host.player_id, token=host.token
    )


@router.post("/join", response_model=JoinSessionResponse)
async def join_session(body: JoinSessionRequest):
    try:
        session, player = await session_service.join_session(body.sessionId, body.password, body.nickname)
    except ServiceError as e:
        raise _as_http_error(e)
    return JoinSessionResponse(sessionId=session.session_id, playerId=player.player_id, token=player.token)


@router.get("/{session_id}")
async def get_session(session_id: str):
    session = _get_session_or_404(session_id)
    return {
        "sessionId": session.session_id,
        "status": session.status.value,
        "maxPlayers": session.max_players,
        "currentPlayers": len(session.players),
        "hostPlayerId": session.host_player_id,
    }


@router.get("/{session_id}/state")
async def get_state(session_id: str, playerId: str, token: str):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, playerId, token)
    except ServiceError as e:
        raise _as_http_error(e)
    return session.state_snapshot(playerId)


@router.post("/{session_id}/start")
async def start_session(session_id: str, body: StartRequest):
    session = _get_session_or_404(session_id)
    try:
        player = authenticate(session, body.playerId, body.token)
        if not player.is_host:
            raise ServiceError("Only the host can start the game", 403)
        await game_engine.start_game(session)
    except (ServiceError, game_engine.GameError) as e:
        raise _as_http_error(e)
    return {"ok": True}


@router.post("/{session_id}/settings")
async def update_settings(session_id: str, body: SettingsRequest):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, body.playerId, body.token)
        settings_out = await session_service.update_settings(
            session, body.playerId, body.detailedNightResults
        )
    except ServiceError as e:
        raise _as_http_error(e)
    return {"ok": True, "settings": settings_out}


@router.post("/{session_id}/leave")
async def leave_session(session_id: str, body: LeaveRequest):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, body.playerId, body.token)
    except ServiceError as e:
        raise _as_http_error(e)
    await session_service.leave_session(session, body.playerId)
    return {"ok": True}


@router.post("/{session_id}/vote")
async def vote(session_id: str, body: VoteRequest):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, body.playerId, body.token)
        await game_engine.submit_vote(session, body.playerId, body.targetId)
    except (ServiceError, game_engine.GameError) as e:
        raise _as_http_error(e)
    return {"ok": True}


@router.post("/{session_id}/action")
async def action(session_id: str, body: ActionRequest):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, body.playerId, body.token)
        result = await game_engine.submit_night_action(session, body.playerId, body.action, body.targetId)
    except (ServiceError, game_engine.GameError) as e:
        raise _as_http_error(e)
    return {"ok": True, **result}


@router.post("/{session_id}/chat")
async def chat(session_id: str, body: ChatRequest):
    session = _get_session_or_404(session_id)
    try:
        authenticate(session, body.playerId, body.token)
        await send_chat(session, body.playerId, body.message)
    except ServiceError as e:
        raise _as_http_error(e)
    return {"ok": True}
