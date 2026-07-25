"""Зависимости (Dependencies) для FastAPI."""
import uuid
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.security import decode_token
from app.models.users import User
from app.schemas.users import TokenData

# Схема аутентификации OAuth2 (будет искать токен в заголовке Authorization: Bearer <token>)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    db: Annotated[Session, Depends(get_db)],
    token: Annotated[str, Depends(oauth2_scheme)]
) -> User:
    """
    Зависимость для получения текущего аутентифицированного пользователя.
    Проверяет валидность токена и извлекает пользователя из БД.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось проверить учетные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_token(token)
    if payload is None:
        raise credentials_exception
    
    token_data = TokenData(user_id=payload.get("sub"), type=payload.get("type"))
    
    if token_data.user_id is None or token_data.type != "access":
        raise credentials_exception
    
    try:
        user_id = uuid.UUID(token_data.user_id)
    except ValueError:
        raise credentials_exception
    
    # Извлекаем пользователя вместе с его ролями (eager loading)
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    
    if user is None or not user.is_active:
        raise credentials_exception
        
    return user


# Типизированный алиас для удобства использования в эндпоинтах
CurrentUser = Annotated[User, Depends(get_current_user)]