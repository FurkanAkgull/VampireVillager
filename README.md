# Vampir Köylü

A real-time multiplayer "Werewolf/Mafia"-style social deduction game — Flutter client + a
server-authoritative Python (FastAPI) backend over REST + WebSocket. Players join a session,
get a secret role assigned by the server, and alternate between Night (secret role actions)
and Day (discussion + voting) phases until one side wins.

Dark-fantasy themed UI, Turkish-language game text.

## Architecture

The server is the single source of truth for everything that matters: role assignment, timers,
phase transitions, and night-action resolution. The Flutter client is UI/interaction only — it
never decides game state on its own and every action a player takes is re-validated server-side.

```
lib/                     Flutter client
├── core/
│   ├── constants/        theme tokens (AppColors/AppSpacing/AppRadius/...), role visuals (name/color/emoji per role)
│   ├── network/           REST API client (http)
│   ├── storage/           local session persistence (shared_preferences)
│   └── websocket/         ws_client.dart — WebSocket connection, event stream, reconnect handling
├── models/                DTOs parsed from server payloads (session state, roles, night resolution, chat)
├── state/                 game_controller.dart — single ChangeNotifier holding all client-visible game state
├── features/
│   ├── splash/            startup/resume flow
│   ├── onboarding/        "how to play"
│   ├── lobby/              home, create/join session, waiting room
│   ├── game/                game board, phase timer, action panel, role reveal, night resolution, elimination, game over
│   ├── chat/                in-game chat panel (public + vampire-only channel)
│   ├── errors/              connection-lost / generic error screens
│   └── settings/            app-level settings (sound, server address)
└── widgets/                shared reusable components (barrel: widgets.dart)

backend/                 Python backend (FastAPI)
├── main.py                 app entrypoint, CORS, router wiring, /health
├── app/
│   ├── api/                 REST endpoints (sessions.py) + request/response schemas (schemas.py)
│   ├── websocket/            WebSocket route, connection manager, event name constants (events.py)
│   ├── game/                 game_engine.py — phase state machine, night-action resolution order, win conditions
│   ├── services/              role_service.py (secure random role assignment), session_service.py, chat_service.py
│   ├── models/                 session.py, player.py, night_action.py, enums.py (roles/status)
│   └── core/                    config.py (env-configurable timers), security.py (tokens)
└── tests/                    pytest suite (unit + WebSocket integration)
```

## Core game flow

```
WAITING → STARTING → NIGHT → DAY → NIGHT → DAY → ... → FINISHED
```

- **Role assignment** — fully server-side. The host picks which special roles are active; the
  server builds a role pool (always ≥1 VAMPIRE and ≥1 VILLAGER, remaining slots filled from the
  host's selection, truncated/padded to the player count), shuffles it with `secrets.SystemRandom`
  (cryptographically secure, not `random`), and sends each player **only their own role** via a
  `ROLE_ASSIGNED` event. The client can never see or influence another player's role.

- **Night phase** — players with a night action (Vampire, Doctor, Medium) submit a target. The
  server logs every action as a `NightAction` (round, actor, type, target, result) and, once the
  night ends, resolves them in a fixed order: collect → validate → Vampire → Doctor → Medium →
  other roles → calculate deaths → build the resolution.

- **Night Resolution** — the server sends a `NIGHT_RESOLUTION` event, built **per player** so
  privacy rules are enforced server-side, never trusted to the client:
  - By default, non-involved players see only a generic public summary (e.g. "an attack
    happened" / who died or survived).
  - The host can toggle a per-session **"Detaylı Gece Sonuçları"** (detailed night results)
    setting; when on, everyone sees role-labelled public action lines (still without exposing
    which player is which vampire, etc.).
  - Regardless of that setting, each role always privately sees the outcome of *their own*
    action (the Medium always learns who they inspected and the result; the Doctor always sees
    who they protected).
  - The Flutter client shows a dedicated animated **Night Resolution screen** (sequential reveal
    of action cards, then the result) before the board transitions to Day — never an instant cut.
  - The transition itself is server-timed (`night_resolution_delay_seconds`, default 4s); the
    client cannot skip or trigger it early.

- **Day phase** — discussion + voting to eliminate a suspected vampire; win conditions are
  evaluated by the server after resolution.

- **Chat** — public channel visible to everyone, plus a vampire-only channel used during the
  night that is filtered server-side (non-vampire clients never receive those events at all).
  The client shows a toast + unread badge for messages that arrive while the chat screen isn't
  open, batching bursts into a single "N yeni mesaj" notification instead of spamming.

## Running the backend

```bash
cd backend
python -m venv venv
venv/Scripts/activate        # Windows; use `source venv/bin/activate` on macOS/Linux
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Health check: `GET http://localhost:8000/health`

### REST endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/sessions` | Create a session (returns session id + host token) |
| POST | `/api/v1/sessions/join` | Join an existing session |
| GET | `/api/v1/sessions/{id}` | Session metadata |
| GET | `/api/v1/sessions/{id}/state` | Full current game state snapshot |
| POST | `/api/v1/sessions/{id}/start` | Host starts the game (triggers server-side role assignment) |
| POST | `/api/v1/sessions/{id}/settings` | Host-only: toggle settings (e.g. detailed night results) |
| POST | `/api/v1/sessions/{id}/leave` | Leave a session |
| POST | `/api/v1/sessions/{id}/vote` | Cast a Day-phase elimination vote |
| POST | `/api/v1/sessions/{id}/action` | Submit a night action (Vampire/Doctor/Medium target) |
| POST | `/api/v1/sessions/{id}/chat` | Send a chat message |

### WebSocket events (server → client)

`SESSION_CREATED`, `PLAYER_JOINED`, `PLAYER_LEFT`, `HOST_CHANGED`, `GAME_STARTED`,
`ROLE_ASSIGNED`, `PHASE_CHANGED`, `CHAT_MESSAGE`, `PLAYER_ACTION`, `VOTE_STARTED`, `VOTE_CAST`,
`PLAYER_ELIMINATED`, `PLAYER_DIED`, `PLAYER_SAVED`, `PLAYER_REVEALED`, `NIGHT_RESOLUTION`,
`SETTINGS_UPDATED`, `GAME_STATE_UPDATED`, `GAME_FINISHED`, `ERROR`.

Every event is delivered per-connection through the connection manager, which filters payload
contents according to what that specific player is allowed to see (own role, own night-action
result, vampire-channel membership, etc.) — the filtering lives entirely in the backend.

### Backend config (env vars)

| Variable | Default | Meaning |
|---|---|---|
| `VK_NIGHT_SECONDS` | 60 | Night phase duration |
| `VK_DAY_SECONDS` | 300 | Day phase duration |
| `VK_RECONNECT_SECONDS` | 60 | Grace period to reconnect before a player is dropped |
| `VK_NIGHT_RESOLUTION_DELAY_SECONDS` | 4 | Server-owned pause between `NIGHT_RESOLUTION` and Day |

### Backend tests

```bash
cd backend
venv/Scripts/python -m pytest
```

## Running the Flutter client

```bash
flutter pub get
flutter run                 # pick a target device/emulator, or use -d chrome / -d windows
```

Point the client at your backend from the in-app Settings screen (server address), or via the
default configured in `lib/core/network/api_client.dart` / `lib/core/websocket/ws_client.dart`.

### Flutter tests

```bash
flutter analyze
flutter test
```

## Tech stack

- **Client**: Flutter/Dart, `provider` for state management, `web_socket_channel` for realtime
  transport, `http` for REST calls, `shared_preferences` for local session resume.
- **Backend**: Python, FastAPI, `uvicorn`, in-memory session/game state, `pytest` +
  `pytest-asyncio` + `httpx` for testing.

## Status

See [PROGRESS.md](PROGRESS.md) for a detailed, dated log of completed work (UI/UX redesign
phases, and the night-resolution/random-roles/chat-notifications feature set).
