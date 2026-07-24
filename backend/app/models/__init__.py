"""Пакет моделей SQLAlchemy."""
from app.models.base import Base, BaseModel, UUIDMixin, TimestampMixin
from app.models.enums import (
    InspectionSource,
    InspectionStatus,
    PlanStatus,
    NotificationType,
    NotificationChannel,
)
from app.models.references import PE, Department, Contractor, WorkType, ZPBRule
from app.models.users import Role, User, user_roles
from app.models.inspections import Inspection, ViolationRecord, ViolationPhoto
from app.models.planning import InspectionPlan, UserPEAssignment, Notification  # <-- ДОБАВЛЕНО

__all__ = [
    "Base", "BaseModel", "UUIDMixin", "TimestampMixin",
    "InspectionSource", "InspectionStatus", "PlanStatus", "NotificationType", "NotificationChannel",
    "PE", "Department", "Contractor", "WorkType", "ZPBRule",
    "Role", "User", "user_roles",
    "Inspection", "ViolationRecord", "ViolationPhoto",
    "InspectionPlan", "UserPEAssignment", "Notification",  # <-- ДОБАВЛЕНО
]