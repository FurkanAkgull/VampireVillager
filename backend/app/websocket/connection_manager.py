from typing import Dict

from fastapi import WebSocket


class ConnectionManager:
    """Tracks live WebSocket connections per session/player and broadcasts events."""

    def __init__(self) -> None:
        # sessionId -> playerId -> WebSocket
        self._connections: Dict[str, Dict[str, WebSocket]] = {}

    async def connect(self, session_id: str, player_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.setdefault(session_id, {})[player_id] = ws

    def disconnect(self, session_id: str, player_id: str) -> None:
        conns = self._connections.get(session_id)
        if conns and conns.get(player_id):
            conns.pop(player_id, None)
        if conns is not None and not conns:
            self._connections.pop(session_id, None)

    async def send_to(self, session_id: str, player_id: str, event: dict) -> None:
        conns = self._connections.get(session_id, {})
        ws = conns.get(player_id)
        if ws is not None:
            try:
                await ws.send_json(event)
            except Exception:
                pass

    async def broadcast(self, session_id: str, event: dict, exclude: set[str] | None = None) -> None:
        exclude = exclude or set()
        conns = dict(self._connections.get(session_id, {}))
        for player_id, ws in conns.items():
            if player_id in exclude:
                continue
            try:
                await ws.send_json(event)
            except Exception:
                pass

    async def broadcast_state(self, session_id: str, session, event_name: str = "GAME_STATE_UPDATED") -> None:
        """Each player gets their own view (role hidden from others), so this can't be one shared payload."""
        conns = dict(self._connections.get(session_id, {}))
        for player_id, ws in conns.items():
            try:
                await ws.send_json({"event": event_name, "data": session.state_snapshot(player_id)})
            except Exception:
                pass

    def is_connected(self, session_id: str, player_id: str) -> bool:
        return player_id in self._connections.get(session_id, {})


connection_manager = ConnectionManager()
