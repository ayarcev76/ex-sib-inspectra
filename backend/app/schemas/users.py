"""Pydantic-схемы для пользователей и аутентификации."""
import uuid
from datetime import date
from pydantic import BaseModel, EmailStr, Field


class UserLogin(BaseModel):
    """Схема для входа в систему."""
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=50)


class Token(BaseModel):
    """Схема ответа с токенами."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Данные из декодированного токена."""
    user_id: str | None = None
    type: str | None = None


class RoleResponse(BaseModel):
    """Схема ответа для роли."""
    id: uuid.UUID
    name: str
    display_name: str

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    """Схема создания пользователя."""
    email: EmailStr
    full_name: str = Field(..., max_length=255)
    password: str = Field(..., min_length=6, max_length=50)
    role_ids: list[uuid.UUID] = Field(default=[], description="ID ролей для назначения")


class UserUpdate(BaseModel):
    """Схема обновления пользователя."""
    email: EmailStr | None = None
    full_name: str | None = Field(None, max_length=255)
    password: str | None = Field(None, min_length=6, max_length=50)
    is_active: bool | None = None


class UserResponse(BaseModel):
    """Схема ответа с данными пользователя (без пароля)."""
    id: uuid.UUID
    email: str
    full_name: str
    is_active: bool
    roles: list[RoleResponse] = []

    class Config:
        from_attributes = True


# --- Назначения на ПЕ ---
class UserPEAssignmentCreate(BaseModel):
    """Схема создания назначения пользователя на ПЕ."""
    pe_id: uuid.UUID
    valid_from: date
    valid_to: date | None = None


class UserPEAssignmentResponse(BaseModel):
    """Схема ответа с данными назначения."""
    id: uuid.UUID
    user_id: uuid.UUID
    pe_id: uuid.UUID
    pe_name: str | None = None
    valid_from: date
    valid_to: date | None = None
    is_active: bool

    class Config:
        from_attributes = True