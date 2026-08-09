"""Схемы для работы с фотографиями нарушений."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class MobilePhotoUploadResponse(BaseModel):
    """Ответ на загрузку фото с мобильного устройства."""
    id: UUID
    violation_id: UUID
    file_path: str
    thumbnail_path: str
    original_filename: str
    file_size: int
    mime_type: str
    gps_latitude: Optional[float] = None
    gps_longitude: Optional[float] = None
    uploaded_at: datetime

    class Config:
        from_attributes = True