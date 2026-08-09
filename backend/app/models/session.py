import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from app.models.enums import SessionStatus
from app.models.night_action import NightAction
from app.models.player import Player


@dataclass
class ChatMessage:
    player_id: str
    nickname: str
    message: str
    timestamp: float
    channel: str = "PUBLIC"  # PUBLIC | VAMPIRE


@dataclass
class GameSession:
    session_id: str
    password_hash: str
    host_player_id: str
    max_players: int
    active_roles: Dict[str, int]
    status: SessionStatus = SessionStatus.WAITING
    current_phase: Optional[str] = None
    phase_started_at: Optional[float] = None
    phase_ends_at: Optional[float] = None
    round: int = 0
    players: Dict[str, Player] = field(default_factory=dict)
    votes: Dict[str, str] = field(default_factory=dict)  # voterId -> targetId
    night_actions: Dict[str, dict] = field(default_factory=dict)  # playerId -> {action, target}
    # Full server-side history of every night action ever submitted (spec §1.1).
    # Never sent to clients as-is; filtered per player in the night resolution.
    night_action_log: List[NightAction] = field(default_factory=list)
    # Host-controlled game setting (spec §1.5). Server-held: clients can only ask
    # the host-only settings endpoint to change it, never set it themselves.
    detailed_night_results: bool = False
    chat: List[ChatMessage] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)
    winner: Optional[str] = None
    doctor_last_target: Optional[str] = None

    def actions_for_round(self, round_no: int) -> List[NightAction]:
        return [a for a in self.night_action_log if a.round == round_no]

    def alive_players(self) -> List[Player]:
        return [p for p in self.players.values() if p.alive]

    def connected_count(self) -> int:
        return len([p for p in self.players.values() if p.connected])

    def find_by_role(self, role: str, alive_only: bool = True) -> List[Player]:
        return [
            p for p in self.players.values()
            if p.role == role and (p.alive if alive_only else True)
        ]

    def state_snapshot(self, viewer_id: str) -> dict:
        return {
            "sessionId": self.session_id,
            "status": self.status.value,
            "hostPlayerId": self.host_player_id,
            "maxPlayers": self.max_players,
            "activeRoles": self.active_roles,
            "phase": self.current_phase,
            "phaseStartedAt": self.phase_started_at,
            "phaseEndsAt": self.phase_ends_at,
            "round": self.round,
            "players": [p.public_view(viewer_id) for p in self.players.values()],
            "winner": self.winner,
            "settings": {"detailedNightResults": self.detailed_night_results},
        }
