from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Player:
    player_id: str
    nickname: str
    session_id: str
    token: str
    is_host: bool = False
    role: Optional[str] = None
    alive: bool = True
    connected: bool = True
    disconnected_at: Optional[float] = None

    def public_view(self, viewer_id: str) -> dict:
        """Role is only revealed to the player themselves, or to everyone once dead (spec §6, §20)."""
        if viewer_id == self.player_id:
            role_out = self.role
        elif not self.alive:
            role_out = self.role
        else:
            role_out = "UNKNOWN"
        return {
            "playerId": self.player_id,
            "nickname": self.nickname,
            "alive": self.alive,
            "connected": self.connected,
            "isHost": self.is_host,
            "role": role_out,
        }
