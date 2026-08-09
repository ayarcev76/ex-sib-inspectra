"""Модели для карт наблюдений и нарушений."""
import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.references import Contractor, Department, PE, WorkType, ZPBRule
    from app.models.users import User
    from app.models.planning import InspectionPlan  # <-- ДОБАВЛЕНО для типизации


class Inspection(Base):
    """Шапка карты наблюдения (Inspection)."""
    __tablename__ = "inspection"

    # 🔑 ПЕРВИЧНЫЙ КЛЮЧ
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4,
        comment="Уникальный идентификатор проверки"
    )

    # 🔑 НОВОЕ ПОЛЕ: UUID клиента для offline-first архитектуры
    client_id: Mapped[str] = mapped_column(
        String(36),
        unique=True,
        nullable=False,
        index=True,
        comment="UUID клиента (web/mobile) для offline-идентификации и идемпотентности"
    )

    inspection_number: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        nullable=False,
        comment="Уникальный номер проверки в формате INSP-YYMMDD-XXXX"
    )

    date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Дата проведения проверки"
    )

    pe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pe.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Производственная единица"
    )

    department_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("department.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Подразделение"
    )

    inspector_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Инспектор, проводивший проверку"
    )

    contractor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("contractor.id", ondelete="SET NULL"),
        nullable=True,
        comment="Подрядная организация"
    )

    work_location: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Место производства работ"
    )

    plan_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("inspection_plan.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Связь с планом инспекций"
    )

    source: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Источник: mobile или web"
    )

    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="draft",
        index=True,
        comment="Статус: draft, submitted, approved"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="Дата и время создания"
    )

    # ==================== Relationships ====================
    pe: Mapped["PE"] = relationship("PE", lazy="joined")
    department: Mapped["Department"] = relationship("Department", lazy="joined")
    inspector: Mapped["User"] = relationship("User", foreign_keys=[inspector_id], lazy="joined")
    contractor: Mapped[Optional["Contractor"]] = relationship("Contractor", lazy="joined")
    
    # 🔑 ИСПРАВЛЕНИЕ: Добавлена связь с планом, которую требовал InspectionPlan
    plan: Mapped[Optional["InspectionPlan"]] = relationship(
        "InspectionPlan", 
        back_populates="inspections", 
        lazy="joined"
    )
    
    violations: Mapped[List["ViolationRecord"]] = relationship(
        "ViolationRecord",
        back_populates="inspection",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ViolationRecord.order"
    )


class ViolationRecord(Base):
    """Строка наблюдения (ViolationRecord)."""
    __tablename__ = "violation_record"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4
    )

    inspection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("inspection.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Ссылка на проверку"
    )

    work_type_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("work_type.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Вид работ"
    )

    is_safe: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Флаг 'Все безопасно'"
    )

    violation_description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Описание нарушения"
    )

    is_gross_violation: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Флаг 'Грубейшее нарушение'"
    )

    is_work_stopped: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Флаг 'Остановка работ'"
    )

    zpb_rule_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("zpb_rule.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Нарушенное ЗПБ"
    )

    is_top_violation: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
        comment="Вычисляемое поле: ТОП-нарушение"
    )

    order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Порядок строки"
    )

    # Relationships
    inspection: Mapped["Inspection"] = relationship("Inspection", back_populates="violations")
    work_type: Mapped["WorkType"] = relationship("WorkType", lazy="joined")
    zpb_rule: Mapped[Optional["ZPBRule"]] = relationship("ZPBRule", lazy="joined")
    
    photos: Mapped[List["ViolationPhoto"]] = relationship(
        "ViolationPhoto",
        back_populates="violation",
        cascade="all, delete-orphan",
        lazy="selectin"
    )


class ViolationPhoto(Base):
    """Фотография нарушения (ViolationPhoto)."""
    __tablename__ = "violation_photo"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4
    )

    violation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("violation_record.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Ссылка на нарушение"
    )

    file_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Путь к оригиналу в MinIO"
    )

    thumbnail_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Путь к миниатюре в MinIO"
    )

    original_filename: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Исходное имя файла"
    )

    file_size: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Размер файла в байтах"
    )

    mime_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="MIME-тип"
    )

    caption: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Подпись к фото"
    )

    gps_latitude: Mapped[Optional[float]] = mapped_column(
        nullable=True,
        comment="Широта"
    )

    gps_longitude: Mapped[Optional[float]] = mapped_column(
        nullable=True,
        comment="Долгота"
    )

    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="Дата загрузки"
    )

    uploaded_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Кто загрузил"
    )

    # Relationships
    violation: Mapped["ViolationRecord"] = relationship("ViolationRecord", back_populates="photos")