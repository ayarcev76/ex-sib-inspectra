"""Эндпоинты аутентификации (JWT)."""
import uuid
from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_db, get_current_user, CurrentUser
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from app.models.users import User
from app.schemas.users import Token, UserResponse

router = APIRouter(prefix="/auth", tags=["Аутентификация"])


@router.post("/login", response_model=Token, summary="Вход в систему и получение токенов")
def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Annotated[Session, Depends(get_db)]
):
    """
    Аутентифицирует пользователя по email и паролю.
    Возвращает access_token (15 мин) и refresh_token (7 дней).
    В access_token добавляются роли пользователя для RBAC на фронтенде.
    """
    # Ищем пользователя по email с подгрузкой ролей
    user = db.query(User).options(joinedload(User.roles)).filter(User.email == form_data.username).first()

    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Пользователь деактивирован",
        )

    # Получаем список ролей пользователя (имена ролей для фронтенда)
    user_roles = [role.name for role in user.roles]

    # Явно преобразуем UUID в строку для JWT payload
    user_id_str = str(user.id)

    # Дополнительные данные для токена (используются фронтендом для RBAC)
    extra_data = {
        "roles": user_roles,
        "email": user.email,
        "full_name": user.full_name,
    }

    access_token = create_access_token(
        subject=user_id_str,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra_data=extra_data,
    )
    refresh_token = create_refresh_token(
        subject=user_id_str,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        extra_data=extra_data,
    )

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer"
    )


@router.post("/refresh", response_model=Token, summary="Обновление access токена")
def refresh_token_endpoint(refresh_token: str, db: Annotated[Session, Depends(get_db)]):
    """
    Принимает валидный refresh_token и возвращает новую пару токенов.
    Роли также включаются в новый access_token.
    """
    payload = decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Недействительный refresh токен",
        )

    try:
        user_id = uuid.UUID(str(payload.get("sub")))
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Недействительный refresh токен",
        )

    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Пользователь не найден или деактивирован",
        )

    user_id_str = str(user.id)

    # Получаем актуальные роли пользователя
    user_roles = [role.name for role in user.roles]
    extra_data = {
        "roles": user_roles,
        "email": user.email,
        "full_name": user.full_name,
    }

    return Token(
        access_token=create_access_token(
            subject=user_id_str,
            expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
            extra_data=extra_data,
        ),
        refresh_token=create_refresh_token(
            subject=user_id_str,
            expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
            extra_data=extra_data,
        ),
        token_type="bearer"
    )


@router.get("/me", response_model=UserResponse, summary="Данные текущего пользователя")
def get_me(current_user: CurrentUser):
    """
    Возвращает данные аутентифицированного пользователя.
    Защищено зависимостью CurrentUser.
    """
    return current_user