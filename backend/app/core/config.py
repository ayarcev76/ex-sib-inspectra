"""Конфигурация приложения через переменные окружения."""
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Настройки приложения (читаются из backend/.env)."""

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,  # Позволяет читать POSTGRES_PASSWORD как postgres_password
        extra="ignore",
    )

    # --- Application ---
    ENVIRONMENT: str = "development"
    SECRET_KEY: str = "CHANGE_ME_generate_with_openssl_rand_hex_32"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # --- Database (строго как в .env) ---
    POSTGRES_USER: str = "exsib"
    POSTGRES_PASSWORD: str = "exsib_strong_password_123"
    POSTGRES_DB: str = "exsib"
    POSTGRES_PORT: int = 5432
    DB_HOST: str = "localhost"

    # --- Redis ---
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"

    # --- MinIO ---
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin_password_123"
    MINIO_BUCKET: str = "inspections"
    MINIO_USE_SSL: bool = False

    @property
    def DATABASE_URL_SYNC(self) -> str:
        """URL для Alembic и sync-операций (использует psycopg)"""
        return f"postgresql+psycopg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.DB_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    @property
    def DATABASE_URL_ASYNC(self) -> str:
        """URL для асинхронного движка FastAPI (использует asyncpg)"""
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.DB_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"


settings = Settings()