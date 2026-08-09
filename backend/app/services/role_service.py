import secrets
from typing import Dict, List

from app.models.enums import RoleName

# Cryptographically secure RNG (os.urandom backed) - spec §2.3. Never use `random`
# for role assignment: its Mersenne Twister state is predictable from prior outputs.
_rng = secrets.SystemRandom()


def build_role_pool(player_count: int, active_roles: Dict[str, int]) -> List[str]:
    """Expands the host's requested role counts into a flat pool sized to player_count.

    Vampire and Villager are mandatory (spec §7). Requested special roles are honored as long
    as they fit; remaining slots are filled with Villager.
    """
    pool: List[str] = []

    vampire_count = max(1, active_roles.get(RoleName.VAMPIRE.value, 1))
    pool.extend([RoleName.VAMPIRE.value] * vampire_count)

    for role, count in active_roles.items():
        if role in (RoleName.VAMPIRE.value, RoleName.VILLAGER.value):
            continue
        if role not in (r.value for r in RoleName):
            continue
        remaining_slots = player_count - len(pool)
        take = max(0, min(count, remaining_slots))
        pool.extend([role] * take)

    remaining = player_count - len(pool)
    pool.extend([RoleName.VILLAGER.value] * max(0, remaining))

    # Safety: never exceed player_count (host asked for more roles than seats).
    pool = pool[:player_count]
    # Villager is patched first so that with a degenerate player_count of 1 the
    # vampire patch wins: a pool without a vampire could never end the game.
    # (game_engine.start_game enforces >= 2 players, so this only guards misuse.)
    if RoleName.VILLAGER.value not in pool:
        pool[-1] = RoleName.VILLAGER.value
    if RoleName.VAMPIRE.value not in pool:
        pool[0] = RoleName.VAMPIRE.value
    return pool


def assign_roles(player_ids: List[str], active_roles: Dict[str, int]) -> Dict[str, str]:
    """Server-side only. The pool is built from host-selected roles (never trusted as-is),
    shuffled with a secure RNG, then zipped onto the player list (spec §2)."""
    pool = build_role_pool(len(player_ids), active_roles)
    _rng.shuffle(pool)
    return dict(zip(player_ids, pool))
