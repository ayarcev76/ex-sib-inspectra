"""Базовая модель + общие миксины для всех сущностей."""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UUIDMixin:
    """Добавляет UUID первичный ключ (PostgreSQL-native).
    
    Примечание: index=True удален, так как primary_key=True 
    автоматически создает индекс в PostgreSQL, что предотвращает 
    коллизии имен индексов при автосгенерированных названиях.
    """
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        # index=True,  <-- УДАЛИТЬ ЭТУ СТРОКУ
    )


class TimestampMixin:
    """Добавляет created_at и updated_at."""
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class BaseModel(UUIDMixin, TimestampMixin, Base):
    """Абстрактная базовая модель — наследуется всеми сущностями."""
    __abstract__ = True