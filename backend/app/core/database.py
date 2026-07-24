"""Подключение к PostgreSQL через SQLAlchemy 2.0."""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.core.config import settings

# Sync engine (для Alembic и синхронных операций)
engine = create_engine(
    settings.DATABASE_URL_SYNC,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=settings.ENVIRONMENT == "development",
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Базовый класс для всех SQLAlchemy-моделей."""
    pass


def get_db():
    """Dependency для FastAPI: выдаёт сессию БД на запрос."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()