from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import Base, engine, ensure_schema, wait_for_db
from app.routers import auth, fuel, stations, vehicles


@asynccontextmanager
async def lifespan(_app: FastAPI):
    wait_for_db()
    Base.metadata.create_all(bind=engine)
    ensure_schema()
    yield


app = FastAPI(
    title="Pojazdy i koszty",
    version="0.1.0",
    lifespan=lifespan,
    redirect_slashes=False,
)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://.*",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
    allow_private_network=True,
)
app.include_router(auth.router)
app.include_router(vehicles.router)
app.include_router(fuel.router)
app.include_router(stations.router)


@app.get("/health")
def health() -> dict[str, str]:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=f"Baza niedostępna: {exc}") from exc
    return {"status": "ok", "database": "up"}
