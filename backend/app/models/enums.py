from enum import Enum


class SessionStatus(str, Enum):
    WAITING = "WAITING"
    STARTING = "STARTING"
    NIGHT = "NIGHT"
    DAY = "DAY"
    FINISHED = "FINISHED"
    CLOSED = "CLOSED"


class RoleName(str, Enum):
    VAMPIRE = "VAMPIRE"
    VILLAGER = "VILLAGER"
    DOCTOR = "DOCTOR"
    MEDIUM = "MEDIUM"


# MVP special roles that require a night action.
NIGHT_ACTION_ROLES = {RoleName.VAMPIRE, RoleName.DOCTOR, RoleName.MEDIUM}
