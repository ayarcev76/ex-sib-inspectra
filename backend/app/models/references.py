"""Справочные модели: PE, Department, Contractor, WorkType, ZPBRule."""
import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel


class PE(BaseModel):
    """Производственная единица (предприятие) — Уровень 1 иерархии."""

    __tablename__ = "pe"

    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, comment="Название ПЕ")
    code: Mapped[str | None] = mapped_column(String(50), nullable=True, unique=True, comment="Код ПЕ")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    departments: Mapped[list["Department"]] = relationship(
        "Department", back_populates="pe", cascade="all, delete-orphan", lazy="selectin"
    )
    inspections: Mapped[list["Inspection"]] = relationship("Inspection", back_populates="pe", lazy="noload")
    user_assignments: Mapped[list["UserPEAssignment"]] = relationship(
        "UserPEAssignment", back_populates="pe", cascade="all, delete-orphan", lazy="noload"
    )

    def __repr__(self) -> str:
        return f"<PE {self.name}>"


class Department(BaseModel):
    """Подразделение — Уровень 2 иерархии. Привязано к ПЕ."""

    __tablename__ = "department"
    __table_args__ = (
        UniqueConstraint("name", "pe_id", name="uq_department_name_pe"),
        {"comment": "Подразделения (привязаны к ПЕ)"},
    )

    name: Mapped[str] = mapped_column(String(255), nullable=False, comment="Название подразделения")
    pe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pe.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="ПЕ",
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    pe: Mapped["PE"] = relationship("PE", back_populates="departments", lazy="joined")
    inspections: Mapped[list["Inspection"]] = relationship("Inspection", back_populates="department", lazy="noload")

    def __repr__(self) -> str:
        return f"<Department {self.name} (PE={self.pe_id})>"


class Contractor(BaseModel):
    """Подрядная организация (внешняя или внутренняя)."""

    __tablename__ = "contractor"

    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, comment="Название подрядчика")
    inn: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True, comment="ИНН")
    contact_person: Mapped[str | None] = mapped_column(String(255), nullable=True, comment="Контактное лицо")
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True, comment="Телефон")
    email: Mapped[str | None] = mapped_column(String(255), nullable=True, comment="Email")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    inspections: Mapped[list["Inspection"]] = relationship("Inspection", back_populates="contractor", lazy="noload")

    def __repr__(self) -> str:
        return f"<Contractor {self.name}>"


class WorkType(BaseModel):
    """Вид работ (Ремонтные, Огневые, Газоопасные, Высота, ГПМ и т.д.)."""

    __tablename__ = "work_type"

    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, comment="Название вида работ")
    code: Mapped[str | None] = mapped_column(String(50), nullable=True, unique=True, comment="Код")
    description: Mapped[str | None] = mapped_column(Text, nullable=True, comment="Описание")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    violations: Mapped[list["ViolationRecord"]] = relationship(
        "ViolationRecord", back_populates="work_type", lazy="noload"
    )

    def __repr__(self) -> str:
        return f"<WorkType {self.name}>"


class ZPBRule(BaseModel):
    """Золотое Правило Безопасности (всего 7 правил)."""

    __tablename__ = "zpb_rule"

    number: Mapped[int] = mapped_column(Integer, nullable=False, unique=True, comment="Номер правила (1-7)")
    name: Mapped[str] = mapped_column(String(500), nullable=False, comment="Краткое название")
    description: Mapped[str | None] = mapped_column(Text, nullable=True, comment="Полное описание")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True, comment="Активно")

    # Связи
    violations: Mapped[list["ViolationRecord"]] = relationship(
        "ViolationRecord", back_populates="zpb_rule", lazy="noload"
    )

    def __repr__(self) -> str:
        return f"<ZPBRule #{self.number}: {self.name}>"