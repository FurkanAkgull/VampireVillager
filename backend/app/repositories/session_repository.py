import asyncio
from typing import Dict, Optional

from app.models.session import GameSession


class SessionRepository:
    """In-memory store of all active sessions. MVP only (spec §23) — no persistence."""

    def __init__(self) -> None:
        self._sessions: Dict[str, GameSession] = {}
        self._lock = asyncio.Lock()

    async def add(self, session: GameSession) -> None:
        async with self._lock:
            self.add_unlocked(session)

    def add_unlocked(self, session: GameSession) -> None:
        """For callers that already hold `self.lock()` (asyncio.Lock isn't reentrant)."""
        self._sessions[session.session_id] = session

    def get(self, session_id: str) -> Optional[GameSession]:
        return self._sessions.get(session_id)

    def exists(self, session_id: str) -> bool:
        return session_id in self._sessions

    async def remove(self, session_id: str) -> None:
        async with self._lock:
            self._sessions.pop(session_id, None)

    def lock(self) -> asyncio.Lock:
        return self._lock


session_repository = SessionRepository()
