"""Утилиты безопасности: хеширование паролей и JWT."""
from datetime import datetime, timedelta, timezone
from typing import Any, Optional, Dict

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

# Настройка контекста для bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверяет соответствие пароля его хешу."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Возвращает хеш пароля."""
    return pwd_context.hash(password)


def create_access_token(
    subject: str | Any,
    expires_delta: timedelta | None = None,
    extra_data: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Создает JWT access token.

    Args:
        subject: ID пользователя (sub claim)
        expires_delta: Время жизни токена
        extra_data: Дополнительные данные для payload (например, roles, email)
    """
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode: Dict[str, Any] = {
        "exp": expire,
        "sub": str(subject),
        "type": "access",
    }

    # Добавляем дополнительные данные в payload
    if extra_data:
        to_encode.update(extra_data)

    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def create_refresh_token(
    subject: str | Any,
    expires_delta: timedelta | None = None,
    extra_data: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Создает JWT refresh token.

    Args:
        subject: ID пользователя (sub claim)
        expires_delta: Время жизни токена
        extra_data: Дополнительные данные для payload
    """
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    to_encode: Dict[str, Any] = {
        "exp": expire,
        "sub": str(subject),
        "type": "refresh",
    }

    if extra_data:
        to_encode.update(extra_data)

    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> dict | None:
    """Декодирует и валидирует JWT token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except Exception:
        return None