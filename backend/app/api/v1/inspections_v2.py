"""Эндпоинты для работы с проверками (версия 2 с репозиториями)."""
import uuid
import logging
from datetime import datetime, date
from typing import Annotated, Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user, CurrentUser
from app.models.inspections import Inspection, ViolationRecord, ViolationPhoto
from app.models.references import PE
from app.schemas.inspections import (
    InspectionCreate,
    InspectionUpdate,
    InspectionResponse,
    InspectionDetailResponse,
    ViolationRecordCreate,
    ViolationRecordUpdate,
    ViolationRecordResponse,
)
from app.repositories.inspections import (
    InspectionRepository,
    InspectionStageRepository,
    InspectionAttachmentRepository,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/inspections-v2", tags=["Проверки v2"])


def get_inspection_repo(db: Session) -> InspectionRepository:
    """Фабрика для создания репозитория инспекций."""
    return InspectionRepository(db)


def get_stage_repo(db: Session) -> InspectionStageRepository:
    """Фабрика для создания репозитория стадий."""
    return InspectionStageRepository(db)


@router.get(
    "/",
    response_model=List[InspectionResponse],
    summary="Список проверок (v2)",
)
async def list_inspections(
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    inspection_repo: Annotated[InspectionRepository, Depends(get_inspection_repo)],
    pe_id: Optional[uuid.UUID] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
):
    """Получение списка проверок с фильтрацией и пагинацией."""
    inspections = await inspection_repo.get_all(
        skip=skip,
        limit=limit,
        pe_id=pe_id,
        status=status,
    )
    return inspections


@router.get(
    "/{inspection_id}",
    response_model=InspectionDetailResponse,
    summary="Детали проверки (v2)",
)
async def get_inspection(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    inspection_repo: Annotated[InspectionRepository, Depends(get_inspection_repo)],
):
    """Получение детальной информации о проверке."""
    inspection = await inspection_repo.get_by_id(inspection_id)
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    return inspection


@router.post(
    "/",
    response_model=InspectionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Создание проверки (v2)",
)
async def create_inspection(
    data: InspectionCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    inspection_repo: Annotated[InspectionRepository, Depends(get_inspection_repo)],
):
    """Создание новой проверки."""
    inspection_data = data.model_dump()
    inspection = await inspection_repo.create(inspection_data)
    db.commit()
    return inspection


@router.put(
    "/{inspection_id}",
    response_model=InspectionResponse,
    summary="Обновление проверки (v2)",
)
async def update_inspection(
    inspection_id: uuid.UUID,
    data: InspectionUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    inspection_repo: Annotated[InspectionRepository, Depends(get_inspection_repo)],
):
    """Обновление данных проверки."""
    update_data = data.model_dump(exclude_unset=True)
    inspection = await inspection_repo.update(inspection_id, update_data)
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    db.commit()
    return inspection


@router.delete(
    "/{inspection_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удаление проверки (v2)",
)
async def delete_inspection(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    inspection_repo: Annotated[InspectionRepository, Depends(get_inspection_repo)],
):
    """Удаление проверки."""
    success = await inspection_repo.delete(inspection_id)
    if not success:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    db.commit()
