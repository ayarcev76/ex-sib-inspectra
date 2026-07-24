"""Основные модели бизнес-логики: Inspection, ViolationRecord, ViolationPhoto."""
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel
from app.models.enums import InspectionSource, InspectionStatus


class Inspection(BaseModel):
    """Шапка проверки (карта наблюдения). П. 5.1.1 ТЗ."""

    __tablename__ = "inspection"
    __table_args__ = (
        UniqueConstraint("inspection_number", name="uq_inspection_number"),
        {"comment": "Шапка проверки (карта наблюдения)"},
    )

    # Идентификатор
    inspection_number: Mapped[str] = mapped_column(
        String(20), nullable=False, index=True, comment="Уникальный номер (INSP-560995)"
    )

    # Дата и место
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True, comment="Дата проведения")
    work_location: Mapped[str] = mapped_column(String(255), nullable=False, comment="Место производства работ")

    # Источник и статус (Enum)
    source: Mapped[InspectionSource] = mapped_column(
        nullable=False,
        index=True,
        comment="Источник: mobile (Inspectra) / web (ЕХ:СИБ)",
    )
    status: Mapped[InspectionStatus] = mapped_column(
        default=InspectionStatus.DRAFT,
        nullable=False,
        index=True,
        comment="Статус: draft / submitted / approved",
    )

    # Foreign Keys
    pe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pe.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Производственная единица",
    )
    department_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("department.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Подразделение",
    )
    inspector_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Инспектор",
    )
    contractor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("contractor.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Подрядная организация",
    )
    plan_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("inspection_plan.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
      comment="Связь с планом (опционально)",
    )

    # Связи
    pe: Mapped["PE"] = relationship("PE", back_populates="inspections", lazy="joined")
    department: Mapped["Department"] = relationship("Department", back_populates="inspections", lazy="joined")
    inspector: Mapped["User"] = relationship(
        "User", back_populates="inspections_as_inspector", lazy="joined"
    )
    contractor: Mapped["Contractor"] = relationship("Contractor", back_populates="inspections", lazy="joined")
    plan: Mapped["InspectionPlan | None"] = relationship("InspectionPlan", back_populates="inspections", lazy="noload")

    violations: Mapped[list["ViolationRecord"]] = relationship(
        "ViolationRecord",
        back_populates="inspection",
        cascade="all, delete-orphan",
        order_by="ViolationRecord.order",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<Inspection {self.inspection_number} ({self.status.value})>"


class ViolationRecord(BaseModel):
    """Строка наблюдения (нарушение). П. 5.1.2 ТЗ."""

    __tablename__ = "violation_record"
    __table_args__ = ({"comment": "Строка наблюдения (нарушение)"},)

    # Флаги состояния
    is_safe: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, comment="Флаг «Все безопасно»"
    )
    is_gross_violation: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, comment="Грубейшее нарушение"
    )
    is_work_stopped: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, comment="Остановка работ"
    )
    is_top_violation: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
        comment="Топ-нарушение (вычисляется автоматически)",
    )

    # Описание
    violation_description: Mapped[str | None] = mapped_column(
        Text, nullable=True, comment="Описание нарушения (обязательно, если is_safe=False)"
    )

    # Порядок строки в проверке
    order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, comment="Порядок строки")

    # Foreign Keys
    inspection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("inspection.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Ссылка на проверку",
    )
    work_type_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("work_type.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Вид работ",
    )
    zpb_rule_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("zpb_rule.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Нарушенное ЗПБ (опционально)",
    )

    # Связи
    inspection: Mapped["Inspection"] = relationship("Inspection", back_populates="violations", lazy="joined")
    work_type: Mapped["WorkType"] = relationship("WorkType", back_populates="violations", lazy="joined")
    zpb_rule: Mapped["ZPBRule | None"] = relationship("ZPBRule", back_populates="violations", lazy="joined")

    photos: Mapped[list["ViolationPhoto"]] = relationship(
        "ViolationPhoto",
        back_populates="violation",
        cascade="all, delete-orphan",
        order_by="ViolationPhoto.uploaded_at",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<ViolationRecord #{self.order} (safe={self.is_safe})>"


class ViolationPhoto(BaseModel):
    """Фотография нарушения. П. 5.1.3 ТЗ."""

    __tablename__ = "violation_photo"
    __table_args__ = ({"comment": "Фотография нарушения (хранится в MinIO)"},)

    # Пути в MinIO
    file_path: Mapped[str] = mapped_column(String(500), nullable=False, comment="Путь к оригиналу в MinIO")
    thumbnail_path: Mapped[str] = mapped_column(String(500), nullable=False, comment="Путь к миниатюре в MinIO")

    # Метаданные файла
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False, comment="Исходное имя файла")
    file_size: Mapped[int] = mapped_column(Integer, nullable=False, comment="Размер в байтах")
    mime_type: Mapped[str] = mapped_column(String(50), nullable=False, comment="MIME-тип (image/jpeg, image/png)")

    # Подпись
    caption: Mapped[str | None] = mapped_column(String(500), nullable=True, comment="Подпись к фото")

    # GPS-координаты (из EXIF)
    gps_latitude: Mapped[Decimal | None] = mapped_column(
        Numeric(precision=10, scale=7), nullable=True, comment="Широта"
    )
    gps_longitude: Mapped[Decimal | None] = mapped_column(
        Numeric(precision=10, scale=7), nullable=True, comment="Долгота"
    )

    # Дата загрузки
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, comment="Дата загрузки"
    )

    # Foreign Keys
    violation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("violation_record.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Ссылка на нарушение",
    )
    uploaded_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Кто загрузил",
    )

    # Связи
    violation: Mapped["ViolationRecord"] = relationship("ViolationRecord", back_populates="photos", lazy="joined")
    uploader: Mapped["User"] = relationship("User", lazy="joined")

    def __repr__(self) -> str:
        return f"<ViolationPhoto {self.original_filename}>"