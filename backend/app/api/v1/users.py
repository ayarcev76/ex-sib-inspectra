"""Эндпоинты для управления пользователями и назначениями."""
import uuid
from datetime import date
from typing import Annotated, List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_db, get_current_user, CurrentUser
from app.core.security import get_password_hash
from app.models.users import User, Role
# ИСПРАВЛЕНО: UserPEAssignment находится в моделях планирования (согласно Отчету Этап 1)
from app.models.planning import UserPEAssignment  
from app.models.references import PE
from app.schemas.users import (
    UserCreate,
    UserUpdate,
    UserResponse,
    UserPEAssignmentCreate,
    UserPEAssignmentResponse,
)
from app.repositories.users import UserRepository, RoleRepository

router = APIRouter(prefix="/users", tags=["Пользователи"])


def get_user_repo(db: Session) -> UserRepository:
    """Фабрика для создания репозитория пользователей."""
    return UserRepository(db)


def get_role_repo(db: Session) -> RoleRepository:
    """Фабрика для создания репозитория ролей."""
    return RoleRepository(db)


# ================= Схемы для ролей =================

class UserRolesUpdate(BaseModel):
    """Схема обновления ролей пользователя (принимает массив имён ролей)."""
    roles: List[str]


# ================= CRUD пользователей =================

@router.get(
    "/",
    response_model=list[UserResponse],
    summary="Список пользователей",
)
def list_users(
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
    user_repo: Annotated[UserRepository, Depends(get_user_repo)],
):
    """Получение списка всех пользователей с их ролями."""
    return user_repo.get_all(skip=0, limit=1000)


@router.post(
    "/",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Создание пользователя",
)
def create_user(
    data: UserCreate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
    user_repo: Annotated[UserRepository, Depends(get_user_repo)],
    role_repo: Annotated[RoleRepository, Depends(get_role_repo)],
):
    """Создание нового пользователя с ролями."""
    existing = user_repo.get_by_email(data.email)
    if existing:
        raise HTTPException(status_code=400, detail="Пользователь с таким email уже существует")
    
    hashed_password = get_password_hash(data.password)
    
    user_data = {
        "email": data.email,
        "full_name": data.full_name,
        "hashed_password": hashed_password,
        "is_active": getattr(data, 'is_active', True),
    }
    user = user_repo.create(user_data)
    
    if hasattr(data, 'roles') and data.roles:
        for role_name in data.roles:
            role = role_repo.get_by_name(role_name)
            if not role:
                # Откатываем создание пользователя при ошибке
                user_repo.delete(user.id)
                raise HTTPException(status_code=404, detail=f"Роль '{role_name}' не найдена")
            user_repo.add_role(user.id, role.id)
    
    db.commit()
    return user


@router.get(
    "/{user_id}",
    response_model=UserResponse,
    summary="Детали пользователя",
)
def get_user(
    user_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Получение данных пользователя с ролями."""
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    return user


@router.put(
    "/{user_id}",
    response_model=UserResponse,
    summary="Обновление пользователя",
)
def update_user(
    user_id: uuid.UUID,
    data: UserUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Обновление основных данных пользователя (без ролей)."""
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    update_data = data.model_dump(exclude_unset=True)
    
    if 'password' in update_data and update_data['password']:
        update_data['hashed_password'] = get_password_hash(update_data.pop('password'))
    else:
        update_data.pop('password', None)
    
    for field, value in update_data.items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    return user


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удаление пользователя",
)
def delete_user(
    user_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Удаление пользователя."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    db.delete(user)
    db.commit()


# ================= Роли пользователя =================

@router.put(
    "/{user_id}/roles",
    response_model=UserResponse,
    summary="Обновление ролей пользователя",
)
def update_user_roles(
    user_id: uuid.UUID,
    data: UserRolesUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """
    Обновление ролей пользователя.
    Принимает массив имён ролей, например: ["admin", "manager"].
    Полностью заменяет текущие роли.
    """
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    # Очищаем текущие роли
    user.roles = []
    
    # Добавляем новые роли по имени
    for role_name in data.roles:
        role = db.query(Role).filter(Role.name == role_name).first()
        if not role:
            raise HTTPException(status_code=404, detail=f"Роль '{role_name}' не найдена в справочнике")
        user.roles.append(role)
    
    db.commit()
    db.refresh(user)
    return user


# ================= Назначения инспекторов на ПЕ =================

@router.get(
    "/{user_id}/assignments",
    response_model=list[UserPEAssignmentResponse],
    summary="Назначения пользователя на ПЕ",
)
def get_user_assignments(
    user_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Получение всех назначений пользователя на производственные единицы."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    assignments = (
        db.query(UserPEAssignment)
        .options(joinedload(UserPEAssignment.pe))
        .filter(UserPEAssignment.user_id == user_id)
        .order_by(UserPEAssignment.valid_from.desc())
        .all()
    )
    
    result = []
    for a in assignments:
        result.append(UserPEAssignmentResponse(
            id=a.id,
            user_id=a.user_id,
            pe_id=a.pe_id,
            pe_name=a.pe.name if a.pe else None,
            valid_from=a.valid_from,
            valid_to=a.valid_to,
            is_active=a.is_active,
        ))
    return result


@router.post(
    "/{user_id}/assignments",
    response_model=UserPEAssignmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Создание назначения",
)
def create_assignment(
    user_id: uuid.UUID,
    data: UserPEAssignmentCreate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Создание нового назначения инспектора на ПЕ."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    pe = db.query(PE).filter(PE.id == data.pe_id).first()
    if not pe:
        raise HTTPException(status_code=404, detail="Производственная единица не найдена")
    
    assignment = UserPEAssignment(
        user_id=user_id,
        pe_id=data.pe_id,
        valid_from=data.valid_from,
        valid_to=getattr(data, 'valid_to', None),
        is_active=True,
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    
    return UserPEAssignmentResponse(
        id=assignment.id,
        user_id=assignment.user_id,
        pe_id=assignment.pe_id,
        pe_name=pe.name,
        valid_from=assignment.valid_from,
        valid_to=assignment.valid_to,
        is_active=assignment.is_active,
    )


@router.post(
    "/assignments/{assignment_id}/terminate",
    response_model=UserPEAssignmentResponse,
    summary="Завершение назначения",
)
def terminate_assignment(
    assignment_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Завершение активного назначения (устанавливает valid_to = сегодня)."""
    assignment = (
        db.query(UserPEAssignment)
        .options(joinedload(UserPEAssignment.pe))
        .filter(UserPEAssignment.id == assignment_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Назначение не найдено")
    
    if not assignment.is_active:
        raise HTTPException(status_code=400, detail="Назначение уже завершено")
    
    assignment.valid_to = date.today()
    assignment.is_active = False
    db.commit()
    db.refresh(assignment)
    
    return UserPEAssignmentResponse(
        id=assignment.id,
        user_id=assignment.user_id,
        pe_id=assignment.pe_id,
        pe_name=assignment.pe.name if assignment.pe else None,
        valid_from=assignment.valid_from,
        valid_to=assignment.valid_to,
        is_active=assignment.is_active,
    )