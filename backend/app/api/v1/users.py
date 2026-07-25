"""Эндпоинты CRUD для пользователей и назначений."""
import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_db, get_current_user, CurrentUser
from app.core.security import get_password_hash
from app.models.references import PE
from app.models.users import Role, User
from app.models.planning import UserPEAssignment  # <-- ИМПОРТИРУЕМ ИЗ ПРАВИЛЬНОГО МЕСТА
from app.schemas.users import (
    UserCreate,
    UserUpdate,
    UserResponse,
    UserPEAssignmentCreate,
    UserPEAssignmentResponse,
)

router = APIRouter(prefix="/users", tags=["Пользователи"])

# ================= Пользователи =================
@router.get("/", response_model=list[UserResponse])
def get_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Annotated[Session, Depends(get_db)] = None,
):
    """Список пользователей с пагинацией."""
    return (
        db.query(User)
        .options(joinedload(User.roles))
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    data: UserCreate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Создание нового пользователя с назначением ролей."""
    # Проверка уникальности email
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Пользователь с таким email уже существует",
        )

    # Хеширование пароля
    hashed_password = get_password_hash(data.password)

    # Создание пользователя
    user = User(
        email=data.email,
        full_name=data.full_name,
        hashed_password=hashed_password,
        is_active=True,
    )

    # Назначение ролей
    if data.role_ids:
        roles = db.query(Role).filter(Role.id.in_(data.role_ids)).all()
        if len(roles) != len(data.role_ids):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Одна или несколько ролей не найдены",
            )
        user.roles = roles

    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserResponse)
def get_user(user_id: uuid.UUID, db: Annotated[Session, Depends(get_db)]):
    """Получение данных пользователя по ID."""
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    return user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: uuid.UUID,
    data: UserUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Обновление данных пользователя."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    # Проверка уникальности email (если меняется)
    if data.email and data.email != user.email:
        if db.query(User).filter(User.email == data.email).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Пользователь с таким email уже существует",
            )
        user.email = data.email

    if data.full_name:
        user.full_name = data.full_name

    if data.password:
        user.hashed_password = get_password_hash(data.password)

    if data.is_active is not None:
        user.is_active = data.is_active

    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    """Удаление пользователя."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    db.delete(user)
    db.commit()


@router.put("/{user_id}/roles", response_model=UserResponse)
def assign_roles(
    user_id: uuid.UUID,
    role_ids: list[uuid.UUID],
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Назначение ролей пользователю (полная замена)."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    roles = db.query(Role).filter(Role.id.in_(role_ids)).all()
    if len(roles) != len(role_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Одна или несколько ролей не найдены",
        )

    user.roles = roles
    db.commit()
    db.refresh(user)
    return user


# ================= Назначения на ПЕ =================
@router.get("/{user_id}/assignments", response_model=list[UserPEAssignmentResponse])
def get_user_assignments(
    user_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
):
    """Получение назначений пользователя на ПЕ."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    assignments = (
        db.query(UserPEAssignment)
        .filter(UserPEAssignment.user_id == user_id, UserPEAssignment.is_active == True)
        .all()
    )

    result = []
    for assignment in assignments:
        pe = db.query(PE).filter(PE.id == assignment.pe_id).first()
        result.append(
            UserPEAssignmentResponse(
                id=assignment.id,
                user_id=assignment.user_id,
                pe_id=assignment.pe_id,
                pe_name=pe.name if pe else None,
                valid_from=assignment.valid_from,
                valid_to=assignment.valid_to,
                is_active=assignment.is_active,
            )
        )
    return result


@router.post(
    "/{user_id}/assignments",
    response_model=UserPEAssignmentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_assignment(
    user_id: uuid.UUID,
    data: UserPEAssignmentCreate,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Создание назначения пользователя на ПЕ."""
    # Проверка существования пользователя и ПЕ
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    pe = db.query(PE).filter(PE.id == data.pe_id).first()
    if not pe:
        raise HTTPException(status_code=400, detail="ПЕ не найдено")

    # Проверка, что пользователь является инспектором (или имеет роль inspector)
    inspector_role = db.query(Role).filter(Role.name == "inspector").first()
    if inspector_role not in user.roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Назначать на ПЕ можно только пользователей с ролью инспектора",
        )

    assignment = UserPEAssignment(
        user_id=user_id,
        pe_id=data.pe_id,
        valid_from=data.valid_from,
        valid_to=data.valid_to,
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


@router.post("/assignments/{assignment_id}/terminate", response_model=UserPEAssignmentResponse)
def terminate_assignment(
    assignment_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Завершение назначения (deactivate)."""
    assignment = db.query(UserPEAssignment).filter(UserPEAssignment.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Назначение не найдено")

    assignment.is_active = False
    db.commit()
    db.refresh(assignment)

    pe = db.query(PE).filter(PE.id == assignment.pe_id).first()
    return UserPEAssignmentResponse(
        id=assignment.id,
        user_id=assignment.user_id,
        pe_id=assignment.pe_id,
        pe_name=pe.name if pe else None,
        valid_from=assignment.valid_from,
        valid_to=assignment.valid_to,
        is_active=assignment.is_active,
    )