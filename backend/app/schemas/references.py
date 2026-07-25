"""Pydantic-схемы для справочников."""
import uuid
from pydantic import BaseModel, Field


# --- PE (Производственные единицы) ---
class PECreate(BaseModel):
    name: str = Field(..., max_length=255)
    code: str | None = Field(None, max_length=50)

class PEUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    code: str | None = Field(None, max_length=50)
    is_active: bool | None = None

class PEResponse(BaseModel):
    id: uuid.UUID
    name: str
    code: str | None
    is_active: bool
    class Config:
        from_attributes = True


# --- Department (Подразделения) ---
class DepartmentCreate(BaseModel):
    name: str = Field(..., max_length=255)
    pe_id: uuid.UUID

class DepartmentUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    pe_id: uuid.UUID | None = None
    is_active: bool | None = None

class DepartmentResponse(BaseModel):
    id: uuid.UUID
    name: str
    pe_id: uuid.UUID
    pe: PEResponse | None = None  # Вложенный объект ПЕ
    is_active: bool
    class Config:
        from_attributes = True


# --- Contractor (Подрядчики) ---
class ContractorCreate(BaseModel):
    name: str = Field(..., max_length=255)
    inn: str | None = Field(None, max_length=20)
    contact_person: str | None = Field(None, max_length=255)
    phone: str | None = Field(None, max_length=50)
    email: str | None = Field(None, max_length=255)

class ContractorUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    inn: str | None = Field(None, max_length=20)
    contact_person: str | None = Field(None, max_length=255)
    phone: str | None = Field(None, max_length=50)
    email: str | None = Field(None, max_length=255)
    is_active: bool | None = None

class ContractorResponse(BaseModel):
    id: uuid.UUID
    name: str
    inn: str | None
    contact_person: str | None
    phone: str | None
    email: str | None
    is_active: bool
    class Config:
        from_attributes = True


# --- WorkType (Виды работ) ---
class WorkTypeCreate(BaseModel):
    name: str = Field(..., max_length=255)
    code: str | None = Field(None, max_length=50)
    description: str | None = None

class WorkTypeUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    code: str | None = Field(None, max_length=50)
    description: str | None = None
    is_active: bool | None = None

class WorkTypeResponse(BaseModel):
    id: uuid.UUID
    name: str
    code: str | None
    description: str | None
    is_active: bool
    class Config:
        from_attributes = True


# --- ZPBRule (Золотые Правила Безопасности) ---
class ZPBRuleCreate(BaseModel):
    number: int = Field(..., ge=1, le=7)
    name: str = Field(..., max_length=500)
    description: str | None = None

class ZPBRuleUpdate(BaseModel):
    number: int | None = Field(None, ge=1, le=7)
    name: str | None = Field(None, max_length=500)
    description: str | None = None
    is_active: bool | None = None

class ZPBRuleResponse(BaseModel):
    id: uuid.UUID
    number: int
    name: str
    description: str | None
    is_active: bool
    class Config:
        from_attributes = True