"""Pydantic-схемы для проверок, нарушений и фотографий."""
import uuid
from datetime import date as dt_date, datetime
from enum import Enum
from typing import Optional, List

from pydantic import BaseModel, Field, field_validator, model_validator


# ================= Enums =================
class InspectionSource(str, Enum):
    """Источник создания проверки."""
    mobile = "mobile"
    web = "web"


class InspectionStatus(str, Enum):
    """Статус проверки."""
    draft = "draft"
    submitted = "submitted"
    approved = "approved"


# ================= ViolationPhoto =================
class ViolationPhotoCreate(BaseModel):
    """Схема создания фотографии."""
    file_path: str = Field(..., max_length=500)
    original_filename: str = Field(..., max_length=255)
    file_size: int = Field(..., gt=0)
    mime_type: str = Field(..., max_length=50)
    caption: Optional[str] = Field(None, max_length=500)
    gps_latitude: Optional[float] = None
    gps_longitude: Optional[float] = None


class ViolationPhotoResponse(BaseModel):
    """Схема ответа с данными фотографии."""
    id: uuid.UUID
    violation_id: uuid.UUID
    file_path: str
    thumbnail_path: Optional[str] = None
    original_filename: str
    file_size: int
    mime_type: str
    caption: Optional[str] = None
    gps_latitude: Optional[float] = None
    gps_longitude: Optional[float] = None
    uploaded_at: datetime
    uploaded_by: uuid.UUID

    class Config:
        from_attributes = True


# ================= ViolationRecord =================
class ViolationRecordCreate(BaseModel):
    """Схема создания строки наблюдения."""
    work_type_id: uuid.UUID
    is_safe: bool = False
    violation_description: Optional[str] = None
    is_gross_violation: bool = False
    is_work_stopped: bool = False
    zpb_rule_id: Optional[uuid.UUID] = None
    order: int = Field(..., ge=0)
    photos: List[ViolationPhotoCreate] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_violation_fields(self) -> "ViolationRecordCreate":
        """Валидация взаимоисключающих полей (ТЗ п. 5.2.2)."""
        if self.is_safe:
            if self.violation_description:
                raise ValueError("violation_description должно быть пустым, если is_safe=True")
            if self.is_gross_violation:
                raise ValueError("is_gross_violation должен быть False, если is_safe=True")
            if self.is_work_stopped:
                raise ValueError("is_work_stopped должен быть False, если is_safe=True")
            if self.zpb_rule_id:
                raise ValueError("zpb_rule_id должно быть пустым, если is_safe=True")
        else:
            if not self.violation_description or not self.violation_description.strip():
                raise ValueError("violation_description обязательно, если is_safe=False")
        return self


class ViolationRecordUpdate(BaseModel):
    """Схема обновления строки наблюдения."""
    work_type_id: Optional[uuid.UUID] = None
    is_safe: Optional[bool] = None
    violation_description: Optional[str] = None
    is_gross_violation: Optional[bool] = None
    is_work_stopped: Optional[bool] = None
    zpb_rule_id: Optional[uuid.UUID] = None
    order: Optional[int] = Field(None, ge=0)

    @model_validator(mode="after")
    def validate_violation_fields(self) -> "ViolationRecordUpdate":
        if self.is_safe is True:
            if self.violation_description:
                raise ValueError("violation_description должно быть пустым, если is_safe=True")
            if self.is_gross_violation is True:
                raise ValueError("is_gross_violation должен быть False, если is_safe=True")
            if self.is_work_stopped is True:
                raise ValueError("is_work_stopped должен быть False, если is_safe=True")
            if self.zpb_rule_id:
                raise ValueError("zpb_rule_id должно быть пустым, если is_safe=True")
        elif self.is_safe is False:
            if self.violation_description is not None and not self.violation_description.strip():
                raise ValueError("violation_description обязательно, если is_safe=False")
        return self


class ViolationRecordResponse(BaseModel):
    """Схема ответа с данными строки наблюдения (с названиями)."""
    id: uuid.UUID
    inspection_id: uuid.UUID
    work_type_id: uuid.UUID
    work_type_name: Optional[str] = None
    is_safe: bool
    violation_description: Optional[str] = None
    is_gross_violation: bool
    is_work_stopped: bool
    zpb_rule_id: Optional[uuid.UUID] = None
    zpb_rule_name: Optional[str] = None
    is_top_violation: bool
    order: int
    photos: List[ViolationPhotoResponse] = []

    class Config:
        from_attributes = True


# ================= Inspection =================
class InspectionCreate(BaseModel):
    """Схема создания проверки."""
    date: dt_date
    pe_id: uuid.UUID
    inspector_id: uuid.UUID
    department_id: uuid.UUID
    contractor_id: Optional[uuid.UUID] = None
    work_location: str = Field(..., max_length=255)
    plan_id: Optional[uuid.UUID] = None
    source: InspectionSource = InspectionSource.web
    status: InspectionStatus = InspectionStatus.draft
    violations: List[ViolationRecordCreate] = Field(default_factory=list)

    @field_validator("work_location")
    @classmethod
    def validate_work_location(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Поле work_location не может быть пустым")
        return v.strip()


class InspectionUpdate(BaseModel):
    """Схема обновления проверки."""
    date: Optional[dt_date] = None
    pe_id: Optional[uuid.UUID] = None
    inspector_id: Optional[uuid.UUID] = None
    department_id: Optional[uuid.UUID] = None
    contractor_id: Optional[uuid.UUID] = None
    work_location: Optional[str] = Field(default=None, max_length=255)
    plan_id: Optional[uuid.UUID] = None
    status: Optional[InspectionStatus] = None
    violations: Optional[List[ViolationRecordCreate]] = None

    @field_validator("work_location")
    @classmethod
    def validate_work_location(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not v.strip():
            raise ValueError("Поле work_location не может быть пустым")
        return v.strip() if v else v


class InspectionResponse(BaseModel):
    """Схема ответа с данными проверки."""
    id: uuid.UUID
    inspection_number: str
    date: dt_date
    pe_id: uuid.UUID
    inspector_id: uuid.UUID
    department_id: uuid.UUID
    contractor_id: Optional[uuid.UUID] = None
    work_location: str
    plan_id: Optional[uuid.UUID] = None
    source: InspectionSource
    status: InspectionStatus
    created_at: datetime

    class Config:
        from_attributes = True


class InspectionDetailResponse(InspectionResponse):
    """Расширенная схема ответа с нарушениями и вложенными данными."""
    pe_name: Optional[str] = None
    department_name: Optional[str] = None
    inspector_name: Optional[str] = None
    contractor_name: Optional[str] = None
    violations: List[ViolationRecordResponse] = []


class InspectionListFilters(BaseModel):
    """Фильтры для списка проверок."""
    pe_id: Optional[uuid.UUID] = None
    department_id: Optional[uuid.UUID] = None
    inspector_id: Optional[uuid.UUID] = None
    status: Optional[InspectionStatus] = None
    source: Optional[InspectionSource] = None
    date_from: Optional[dt_date] = None
    date_to: Optional[dt_date] = None
    skip: int = Field(0, ge=0)
    limit: int = Field(100, ge=1, le=1000)