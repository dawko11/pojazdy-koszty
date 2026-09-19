from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_BACKEND_DIR / ".env", extra="ignore")

    database_url: str = "postgresql+psycopg://pojazdy:pojazdy@127.0.0.1:5432/pojazdy_koszty"
    secret_key: str = "dev-secret-zmien-w-produkcji"
    access_token_expire_minutes: int = 60 * 24 * 7
    algorithm: str = "HS256"


settings = Settings()
