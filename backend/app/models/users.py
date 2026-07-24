"""Модели пользователей и ролей."""
import uuid

from sqlalchemy import Boolean, ForeignKey, String, Table, Column
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel


# Ассоциативная таблица для связи User и Role (многие-ко-многим)
user_roles = Table(
    "user_roles",
    BaseModel.metadata,
    Column("user_id", UUID(as_uuid=True), ForeignKey("user.id", ondelete="CASCADE"), primary_key=True),
    Column("role_id", UUID(as_uuid=True), ForeignKey("role.id", ondelete="CASCADE"), primary_key=True),
    comment="Связь пользователей и ролей (многие-ко-многим)",
)


class Role(BaseModel):
    """Роль пользователя в системе."""

    __tablename__ = "role"

    name: Mapped[str] = mapped_column(
        String(50), nullable=False, unique=True, index=True, comment="Системное имя роли (напр. 'inspector')"
    )
    display_name: Mapped[str] = mapped_column(String(100), nullable=False, comment="Отображаемое имя (напр. 'Инспектор')")
    description: Mapped[str | None] = mapped_column(String(500), nullable=True, comment="Описание прав роли")

    # Связи
    users: Mapped[list["User"]] = relationship(
        "User", secondary=user_roles, back_populates="roles", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<Role {self.name}>"


class User(BaseModel):
    """Пользователь системы."""

    __tablename__ = "user"

    email: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True, index=True, comment="Email (используется для логина)"
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False, comment="ФИО пользователя")
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False, comment="Хеш пароля (bcrypt)")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активен")

    # Связи
    roles: Mapped[list["Role"]] = relationship(
        "Role", secondary=user_roles, back_populates="users", lazy="selectin"
    )
    
    # Forward references для связей, которые будут определены в других файлах
    inspections_as_inspector: Mapped[list["Inspection"]] = relationship(
        "Inspection", back_populates="inspector", foreign_keys="Inspection.inspector_id", lazy="noload"
    )
    pe_assignments: Mapped[list["UserPEAssignment"]] = relationship(
        "UserPEAssignment", back_populates="user", cascade="all, delete-orphan", lazy="noload"
    )

    def __repr__(self) -> str:
        return f"<User {self.email} ({self.full_name})>"