import time
from dataclasses import dataclass, field
from typing import Optional

# Action types match the strings clients already submit via PLAYER_ACTION / POST /action.
ACTION_KILL = "KILL"
ACTION_PROTECT = "PROTECT"
ACTION_INSPECT = "INSPECT"

# result values (spec §1.1). Set at submit time, refined during night resolution.
RESULT_TARGETED = "TARGETED"
RESULT_PROTECTED = "PROTECTED"
RESULT_KILLED = "KILLED"
RESULT_SAVED = "SAVED"


@dataclass
class NightAction:
    """Server-side record of a single night action (spec §1.1).

    The full log lives on the session and is never sent to clients wholesale;
    game_engine builds a per-player filtered view out of it.
    """

    round: int
    actor_player_id: str
    action_type: str
    target_player_id: Optional[str]
    created_at: float = field(default_factory=time.time)
    result: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "round": self.round,
            "actorPlayerId": self.actor_player_id,
            "actionType": self.action_type,
            "targetPlayerId": self.target_player_id,
            "createdAt": self.created_at,
            "result": self.result,
        }
