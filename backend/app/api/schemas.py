from typing import Dict, Optional

from pydantic import BaseModel, Field


class CreateSessionRequest(BaseModel):
    nickname: str = Field(min_length=1, max_length=24)
    maxPlayers: int = Field(ge=2, le=20)
    password: Optional[str] = None
    activeRoles: Dict[str, int] = Field(default_factory=dict)


class CreateSessionResponse(BaseModel):
    sessionId: str
    password: str
    hostPlayerId: str
    token: str


class JoinSessionRequest(BaseModel):
    sessionId: str
    password: str
    nickname: str = Field(min_length=1, max_length=24)


class JoinSessionResponse(BaseModel):
    sessionId: str
    playerId: str
    token: str


class VoteRequest(BaseModel):
    playerId: str
    token: str
    targetId: str


class ActionRequest(BaseModel):
    playerId: str
    token: str
    action: str
    targetId: Optional[str] = None


class LeaveRequest(BaseModel):
    playerId: str
    token: str


class StartRequest(BaseModel):
    playerId: str
    token: str


class SettingsRequest(BaseModel):
    playerId: str
    token: str
    detailedNightResults: Optional[bool] = None


class ChatRequest(BaseModel):
    playerId: str
    token: str
    message: str
