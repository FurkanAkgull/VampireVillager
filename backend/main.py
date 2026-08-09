from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.sessions import router as sessions_router
from app.websocket.routes import router as ws_router

app = FastAPI(title="Vampir Koylu Game Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sessions_router)
app.include_router(ws_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
