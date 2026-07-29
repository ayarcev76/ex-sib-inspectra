"""SQLAlchemy модели для проверок, нарушений и фотографий."""
import uuid
from datetime import date, datetime
from enum import Enum

from sqlalchemy import Boolean, CheckConstraint, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


# Оставляем Enum для использования в Pydantic-схемах и бизнес-логике
class InspectionSource(str, Enum):
    mobile = "mobile"
    web = "web"


class InspectionStatus(str, Enum):
    draft = "draft"
    submitted = "submitted"
    approved = "approved"


class Inspection(Base):
    __tablename__ = "inspection"
    
    # CheckConstraint гарантирует, что в БД попадут только допустимые значения
    __table_args__ = (
        CheckConstraint("source IN ('mobile', 'web')", name="check_inspection_source"),
        CheckConstraint("status IN ('draft', 'submitted', 'approved')", name="check_inspection_status"),
        {"comment": "Шапка проверки"}
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    inspection_number = Column(String(20), unique=True, nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    
    pe_id = Column(UUID(as_uuid=True), ForeignKey("pe.id", ondelete="RESTRICT"), nullable=False, index=True)
    department_id = Column(UUID(as_uuid=True), ForeignKey("department.id", ondelete="RESTRICT"), nullable=False, index=True)
    inspector_id = Column(UUID(as_uuid=True), ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)
    contractor_id = Column(UUID(as_uuid=True), ForeignKey("contractor.id", ondelete="SET NULL"), nullable=True, index=True)
    plan_id = Column(UUID(as_uuid=True), ForeignKey("inspection_plan.id", ondelete="SET NULL"), nullable=True, index=True)
    
    work_location = Column(String(255), nullable=False)
    
    # Используем String вместо SQLEnum для избежания проблем с приведением типов в PostgreSQL
    source = Column(String(20), nullable=False, index=True)
    status = Column(String(20), nullable=False, index=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    pe = relationship("PE")
    department = relationship("Department")
    inspector = relationship("User", foreign_keys=[inspector_id])
    contractor = relationship("Contractor")
    plan = relationship("InspectionPlan", back_populates="inspections")
    violations = relationship("ViolationRecord", back_populates="inspection", cascade="all, delete-orphan", lazy="selectin")


class ViolationRecord(Base):
    __tablename__ = "violation_record"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    inspection_id = Column(UUID(as_uuid=True), ForeignKey("inspection.id", ondelete="CASCADE"), nullable=False, index=True)
    work_type_id = Column(UUID(as_uuid=True), ForeignKey("work_type.id", ondelete="RESTRICT"), nullable=False, index=True)
    zpb_rule_id = Column(UUID(as_uuid=True), ForeignKey("zpb_rule.id", ondelete="SET NULL"), nullable=True, index=True)
    
    is_safe = Column(Boolean, nullable=False, default=False)
    violation_description = Column(Text, nullable=True)
    is_gross_violation = Column(Boolean, nullable=False, default=False)
    is_work_stopped = Column(Boolean, nullable=False, default=False)
    is_top_violation = Column(Boolean, nullable=False, default=False, index=True)
    order = Column(Integer, nullable=False)

    # Relationships
    inspection = relationship("Inspection", back_populates="violations")
    work_type = relationship("WorkType")
    zpb_rule = relationship("ZPBRule")
    photos = relationship("ViolationPhoto", back_populates="violation", cascade="all, delete-orphan", lazy="selectin")


class ViolationPhoto(Base):
    __tablename__ = "violation_photo"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    violation_id = Column(UUID(as_uuid=True), ForeignKey("violation_record.id", ondelete="CASCADE"), nullable=False, index=True)
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("user.id", ondelete="SET NULL"), nullable=False, index=True)
    
    file_path = Column(String(500), nullable=False)
    thumbnail_path = Column(String(500), nullable=True)
    original_filename = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    mime_type = Column(String(50), nullable=False)
    
    caption = Column(String(500), nullable=True)
    gps_latitude = Column(Float, nullable=True)
    gps_longitude = Column(Float, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    violation = relationship("ViolationRecord", back_populates="photos")
    uploader = relationship("User", foreign_keys=[uploaded_by])