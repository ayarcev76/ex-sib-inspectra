"""Pydantic-схемы для карт наблюдений."""
import uuid
from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field


# ==================== Photo Schemas ====================

class ViolationPhotoBase(BaseModel):
    """Базовая схема фотографии."""
    
    file_path: str
    thumbnail_path: str
    original_filename: str
    file_size: int
    mime_type: str
    caption: Optional[str] = None
    gps_latitude: Optional[float] = None
    gps_longitude: Optional[float] = None


class ViolationPhotoCreate(ViolationPhotoBase):
    """Схема для создания фотографии."""
    pass


class ViolationPhotoResponse(ViolationPhotoBase):
    """Схема ответа для фотографии."""
    
    id: uuid.UUID
    violation_id: uuid.UUID
    uploaded_at: datetime
    uploaded_by: uuid.UUID

    class Config:
        from_attributes = True


# ==================== Violation Schemas ====================

class ViolationRecordBase(BaseModel):
    """Базовая схема нарушения."""
    
    work_type_id: uuid.UUID
    is_safe: bool = False
    violation_description: Optional[str] = None
    is_gross_violation: bool = False
    is_work_stopped: bool = False
    zpb_rule_id: Optional[uuid.UUID] = None
    order: int


class ViolationRecordCreate(ViolationRecordBase):
    """Схема для создания нарушения."""
    pass


class ViolationRecordUpdate(BaseModel):
    """Схема для обновления нарушения."""
    
    work_type_id: Optional[uuid.UUID] = None
    is_safe: Optional[bool] = None
    violation_description: Optional[str] = None
    is_gross_violation: Optional[bool] = None
    is_work_stopped: Optional[bool] = None
    zpb_rule_id: Optional[uuid.UUID] = None
    order: Optional[int] = None


class ViolationRecordResponse(ViolationRecordBase):
    """Схема ответа для нарушения."""
    
    id: uuid.UUID
    inspection_id: uuid.UUID
    work_type_name: Optional[str] = None
    zpb_rule_name: Optional[str] = None
    is_top_violation: bool
    photos: List[ViolationPhotoResponse] = []

    class Config:
        from_attributes = True


# ==================== Inspection Schemas ====================

class InspectionBase(BaseModel):
    """Базовая схема проверки."""
    
    date: date
    pe_id: uuid.UUID
    department_id: uuid.UUID
    inspector_id: uuid.UUID
    contractor_id: Optional[uuid.UUID] = None
    work_location: str
    plan_id: Optional[uuid.UUID] = None
    source: str
    status: str = "draft"


class InspectionCreate(InspectionBase):
    """Схема для создания проверки."""
    
    # 🔑 НОВОЕ ПОЛЕ: client_id для идемпотентности
    client_id: str = Field(
        ...,
        description="UUID клиента (web/mobile) для offline-идентификации",
        min_length=36,
        max_length=36
    )
    
    violations: List[ViolationRecordCreate] = []


class InspectionUpdate(BaseModel):
    """Схема для обновления проверки."""
    date: Optional[str] = None  # Принимаем как строку, конвертируем в endpoint
    pe_id: Optional[str] = None  # Принимаем как строку, конвертируем в endpoint
    department_id: Optional[str] = None
    contractor_id: Optional[str] = None
    work_location: Optional[str] = None
    status: Optional[str] = None

class InspectionResponse(InspectionBase):
    """Схема ответа для проверки (список)."""
    
    id: uuid.UUID
    inspection_number: str
    client_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class InspectionDetailResponse(InspectionResponse):
    """Схема ответа для детального просмотра проверки."""
    
    pe_name: Optional[str] = None
    department_name: Optional[str] = None
    inspector_name: Optional[str] = None
    contractor_name: Optional[str] = None
    violations: List[ViolationRecordResponse] = []


# ==================== Sync Schemas (для мобильного приложения) ====================

class InspectionSyncItem(BaseModel):
    """Элемент для пакетной синхронизации."""
    
    client_id: str = Field(..., min_length=36, max_length=36)
    date: date
    pe_id: uuid.UUID
    department_id: uuid.UUID
    inspector_id: uuid.UUID
    contractor_id: Optional[uuid.UUID] = None
    work_location: str
    violations: List[ViolationRecordCreate] = []


class SyncResponse(BaseModel):
    """Ответ для элемента синхронизации."""
    
    client_id: str
    inspection_number: Optional[str] = None
    server_id: Optional[uuid.UUID] = None
    status: str = Field(..., description="created, already_synced, error")
    error_message: Optional[str] = None