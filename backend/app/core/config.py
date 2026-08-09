import os


class Settings:
    night_seconds: int = int(os.getenv("VK_NIGHT_SECONDS", "60"))
    day_seconds: int = int(os.getenv("VK_DAY_SECONDS", "300"))
    reconnect_grace_seconds: int = int(os.getenv("VK_RECONNECT_SECONDS", "60"))
    # Server-owned pause between NIGHT_RESOLUTION and the DAY phase (spec §1.8: 2-5s).
    # Clients cannot skip or trigger this early.
    night_resolution_delay_seconds: int = int(os.getenv("VK_NIGHT_RESOLUTION_DELAY_SECONDS", "4"))
    session_id_length: int = 5
    session_password_length: int = 4


settings = Settings()
