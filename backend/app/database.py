from collections.abc import Generator
from time import sleep

from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    pass


connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


def wait_for_db(attempts: int = 30) -> None:
    last_error: Exception | None = None
    for _ in range(attempts):
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))
            return
        except Exception as exc:  # noqa: BLE001 - retry any driver/network failure
            last_error = exc
            sleep(1)
    raise RuntimeError(f"Nie można połączyć z bazą danych: {last_error}") from last_error


def ensure_schema() -> None:
    from sqlalchemy import inspect

    inspector = inspect(engine)
    tables = inspector.get_table_names()

    def add_column(table: str, column: str, ddl: str) -> None:
        if table not in tables:
            return
        existing = {col["name"] for col in inspector.get_columns(table)}
        if column in existing:
            return
        with engine.begin() as connection:
            connection.execute(text(ddl))

    add_column("vehicles", "tank_capacity_liters", "ALTER TABLE vehicles ADD COLUMN tank_capacity_liters NUMERIC(10, 2)")
    add_column("fuel_entries", "price_per_liter", "ALTER TABLE fuel_entries ADD COLUMN price_per_liter NUMERIC(10, 3)")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
