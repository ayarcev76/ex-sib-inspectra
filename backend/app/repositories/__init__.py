"""Репозитории для доступа к данным."""

from app.repositories.users import UserRepository, RoleRepository
from app.repositories.inspections import (
    InspectionRepository,
    InspectionStageRepository,
    InspectionAttachmentRepository,
)

__all__ = [
    "UserRepository",
    "RoleRepository",
    "InspectionRepository",
    "InspectionStageRepository",
    "InspectionAttachmentRepository",
]
