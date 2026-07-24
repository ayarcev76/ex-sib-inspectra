"""Модели планирования и уведомлений."""
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel
from app.models.enums import PlanStatus, NotificationType, NotificationChannel


class InspectionPlan(BaseModel):
    """План инспекций на неделю. П. 4 ТЗ."""

    __tablename__ = "inspection_plan"
    __table_args__ = ({"comment": "План инспекций на неделю"},)

    week_start_date: Mapped[date] = mapped_column(
        Date, nullable=False, unique=True, index=True, comment="Дата начала недели (понедельник)"
    )
    status: Mapped[PlanStatus] = mapped_column(
        default=PlanStatus.DRAFT,
        nullable=False,
        index=True,
        comment="Статус: draft / approved / assigned / completed / cancelled",
    )
    created_by_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Кто создал/утвердил план",
    )

    # Связи
    creator: Mapped["User"] = relationship("User", lazy="joined")
    inspections: Mapped[list["Inspection"]] = relationship(
        "Inspection", back_populates="plan", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<InspectionPlan week={self.week_start_date} status={self.status.value}>"


class UserPEAssignment(BaseModel):
    """Назначение пользователя на Производственную Единицу. П. 3.3 ТЗ."""

    __tablename__ = "user_pe_assignment"
    __table_args__ = ({"comment": "Назначение пользователя на ПЕ"},)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Пользователь",
    )
    pe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pe.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Производственная единица",
    )
    valid_from: Mapped[date] = mapped_column(Date, nullable=False, comment="Действует с")
    valid_to: Mapped[date | None] = mapped_column(Date, nullable=True, comment="Действует по (null = бессрочно)")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    user: Mapped["User"] = relationship("User", back_populates="pe_assignments", lazy="joined")
    pe: Mapped["PE"] = relationship("PE", back_populates="user_assignments", lazy="joined")

    def __repr__(self) -> str:
        return f"<UserPEAssignment user={self.user_id} pe={self.pe_id}>"


class Notification(BaseModel):
    """Журнал уведомлений. П. 6 ТЗ."""

    __tablename__ = "notification"
    __table_args__ = ({"comment": "Журнал уведомлений пользователей"},)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Получатель",
    )
    type: Mapped[NotificationType] = mapped_column(
        nullable=False, index=True, comment="Тип уведомления (top_violation, gross_violation и т.д.)"
    )
    channel: Mapped[NotificationChannel] = mapped_column(
        nullable=False, comment="Канал доставки: email, push, internal"
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False, comment="Заголовок")
    message: Mapped[str] = mapped_column(Text, nullable=False, comment="Текст уведомления")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True, comment="Прочитано")
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, comment="Время фактической отправки"
    )

    # Связи
    user: Mapped["User"] = relationship("User", lazy="joined")

    def __repr__(self) -> str:
        return f"<Notification {self.type.value} for user {self.user_id} (read={self.is_read})>"