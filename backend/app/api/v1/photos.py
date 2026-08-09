"""Эндпоинты для работы с фотографиями нарушений."""
import uuid
import logging
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user, CurrentUser
from app.models.inspections import Inspection, ViolationPhoto, ViolationRecord
from app.schemas.inspections import ViolationPhotoResponse
from app.services.photo_service import photo_service

logger = logging.getLogger(__name__)

# ─── Основной роутер: /violations/{violation_id}/photos ───────────
router = APIRouter(
    prefix="/violations/{violation_id}/photos",
    tags=["Фотографии"],
)

# ─── Мобильный роутер: /photos ────────────────────────────────────
# Отдельный роутер, т.к. мобильное приложение не знает server_id нарушений.
# Поиск нарушения идёт по inspection_client_id + violation_order.
mobile_router = APIRouter(
    prefix="/photos",
    tags=["Фотографии (мобильные)"],
)


# ══════════════════════════════════════════════════════════════════
# ОСНОВНЫЕ ЭНДПОИНТЫ (веб-интерфейс)
# ══════════════════════════════════════════════════════════════════

@router.post(
    "/",
    response_model=ViolationPhotoResponse,
    status_code=201,
    summary="Загрузка фотографии к нарушению",
)
@router.post(
    "",
    response_model=ViolationPhotoResponse,
    status_code=201,
    include_in_schema=False,
)
async def upload_photo(
    violation_id: uuid.UUID,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    gps_latitude: float | None = Form(None),
    gps_longitude: float | None = Form(None),
    db: Annotated[Session, Depends(get_db)] = None,
    current_user: Annotated[CurrentUser, Depends(get_current_user)] = None,
):
    """Загрузка фотографии к нарушению с автоматической обработкой
    (сжатие, миниатюра, MinIO)."""

    # 1. Проверка существования нарушения
    violation = (
        db.query(ViolationRecord)
        .filter(ViolationRecord.id == violation_id)
        .first()
    )
    if not violation:
        raise HTTPException(status_code=404, detail="Нарушение не найдено")

    # 2. Проверка, что нарушение не "всё безопасно"
    if violation.is_safe:
        raise HTTPException(
            status_code=400,
            detail="Нельзя добавить фото к наблюдению 'Всё безопасно'",
        )

    # 3. Чтение содержимого файла
    file_content = await file.read()

    # 4. Обработка и загрузка фотографии через сервис
    photo_data = photo_service.upload_photo(
        violation_id=str(violation_id),
        file_content=file_content,
        original_filename=file.filename or "unknown.jpg",
        mime_type=file.content_type or "image/jpeg",
        uploaded_by=str(current_user.id),
    )

    # 5. Создание записи в БД
    photo = ViolationPhoto(
        id=uuid.uuid4(),
        violation_id=violation_id,
        file_path=photo_data["file_path"],
        thumbnail_path=photo_data["thumbnail_path"],
        original_filename=file.filename or "unknown.jpg",
        file_size=photo_data["file_size"],
        mime_type=file.content_type or "image/jpeg",
        caption=caption,
        gps_latitude=gps_latitude,
        gps_longitude=gps_longitude,
        uploaded_at=datetime.now(timezone.utc),
        uploaded_by=current_user.id,
    )
    db.add(photo)
    db.commit()
    db.refresh(photo)

    logger.info(f"✅ Фотография сохранена: id={photo.id}")
    return photo


@router.get(
    "/",
    response_model=list[ViolationPhotoResponse],
    summary="Список фотографий нарушения",
)
@router.get(
    "",
    response_model=list[ViolationPhotoResponse],
    include_in_schema=False,
)
def list_photos(
    violation_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
):
    """Получение списка всех фотографий, прикреплённых к нарушению."""
    violation = (
        db.query(ViolationRecord)
        .filter(ViolationRecord.id == violation_id)
        .first()
    )
    if not violation:
        raise HTTPException(status_code=404, detail="Нарушение не найдена")
    return violation.photos


@router.get(
    "/{photo_id}/original",
    summary="Presigned URL для оригинала фотографии",
)
def get_original_photo_url(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
):
    """Генерация presigned URL для временного доступа к оригиналу."""
    photo = (
        db.query(ViolationPhoto)
        .filter(
            ViolationPhoto.id == photo_id,
            ViolationPhoto.violation_id == violation_id,
        )
        .first()
    )
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")

    url = photo_service.get_presigned_url(photo.file_path)
    return {"url": url, "expires_in": 900}


@router.get(
    "/{photo_id}/thumbnail",
    summary="Presigned URL для миниатюры фотографии",
)
def get_thumbnail_photo_url(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
):
    """Генерация presigned URL для временного доступа к миниатюре."""
    photo = (
        db.query(ViolationPhoto)
        .filter(
            ViolationPhoto.id == photo_id,
            ViolationPhoto.violation_id == violation_id,
        )
        .first()
    )
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")

    if not photo.thumbnail_path:
        raise HTTPException(status_code=404, detail="Миниатюра не найдена")

    url = photo_service.get_presigned_url(photo.thumbnail_path)
    return {"url": url, "expires_in": 900}


@router.delete(
    "/{photo_id}",
    status_code=204,
    summary="Удаление фотографии",
)
def delete_photo(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[CurrentUser, Depends(get_current_user)],  # ✅ Исправлено
):
    """Удаление фотографии из MinIO и базы данных."""
    photo = (
        db.query(ViolationPhoto)
        .filter(
            ViolationPhoto.id == photo_id,
            ViolationPhoto.violation_id == violation_id,
        )
        .first()
    )
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")

    try:
        photo_service.delete_photo(photo.file_path, photo.thumbnail_path)
        db.delete(photo)
        db.commit()
        logger.info(f"✅ Фотография удалена: id={photo_id}")
    except Exception as e:
        logger.error(f"Ошибка удаления фотографии: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка удаления фотографии: {str(e)}",
        )


# ══════════════════════════════════════════════════════════════════
# МОБИЛЬНЫЙ ЭНДПОИНТ (Inspectra)
# ══════════════════════════════════════════════════════════════════

@mobile_router.post(
    "/mobile",
    response_model=ViolationPhotoResponse,
    status_code=201,
    summary="Загрузка фото с мобильного приложения Inspectra",
    description="""
    Специальный эндпоинт для мобильного приложения, которое загружает фото
    до получения серверных ID нарушений. Поиск нарушения происходит по:
    
    - `inspection_client_id` — уникальный UUID инспекции (offline-first)
    - `violation_order` — порядковый номер нарушения внутри инспекции
    
    **Формат:** multipart/form-data
    """,
)
async def upload_photo_mobile(
    inspection_client_id: str = Form(
        ...,
        description="UUID инспекции из локальной БД мобильного приложения",
    ),
    violation_order: int = Form(
        ...,
        ge=1,
        description="Порядковый номер нарушения (1, 2, 3...)",
    ),
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    gps_latitude: float | None = Form(None),
    gps_longitude: float | None = Form(None),
    db: Annotated[Session, Depends(get_db)] = None,
    current_user: Annotated[CurrentUser, Depends(get_current_user)] = None,
):
    """Загрузка фотографии нарушения с мобильного устройства.
    
    Использует offline-first архитектуру: мобильное приложение знает только
    `client_id` инспекции и `order` нарушения, но не знает серверные UUID.
    """

    # ─── 1. Поиск инспекции по client_id ──────────────────────────
    inspection = (
        db.query(Inspection)
        .filter(Inspection.client_id == inspection_client_id)
        .first()
    )

    if not inspection:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Инспекция с client_id '{inspection_client_id}' не найдена. "
                "Убедитесь, что инспекция была синхронизирована с сервером."
            ),
        )

    # ─── 2. Поиск нарушения по order внутри инспекции ─────────────
    violation = (
        db.query(ViolationRecord)
        .filter(
            ViolationRecord.inspection_id == inspection.id,
            ViolationRecord.order == violation_order,
        )
        .first()
    )

    if not violation:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Нарушение с order={violation_order} не найдено "
                f"в инспекции '{inspection.inspection_number}'."
            ),
        )

    # ─── 3. Проверка: фото только для нарушений ───────────────────
    if violation.is_safe:
        raise HTTPException(
            status_code=400,
            detail="Нельзя добавить фото к наблюдению 'Всё безопасно'",
        )

    # ─── 4. Чтение содержимого файла ──────────────────────────────
    try:
        file_content = await file.read()
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Ошибка чтения файла: {e}",
        )

    # ─── 5. Полный пайплайн обработки фото ────────────────────────
    # Валидация → EXIF → оптимизация → миниатюра → MinIO
    try:
        photo_data = photo_service.upload_photo(
            violation_id=str(violation.id),
            file_content=file_content,
            original_filename=file.filename or "unknown.jpg",
            mime_type=file.content_type or "image/jpeg",
            uploaded_by=str(current_user.id),
        )
    except ValueError as e:
        # Ошибки валидации (формат, размер)
        raise HTTPException(status_code=415, detail=str(e))
    except Exception as e:
        logger.error(f"Ошибка обработки фото: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка обработки фото: {e}",
        )

    # ─── 6. Создание записи в БД ──────────────────────────────────
    photo = ViolationPhoto(
        id=uuid.uuid4(),
        violation_id=violation.id,
        file_path=photo_data["file_path"],
        thumbnail_path=photo_data["thumbnail_path"],
        original_filename=file.filename or "unknown.jpg",
        file_size=photo_data["file_size"],
        mime_type=file.content_type or "image/jpeg",
        caption=caption,
        gps_latitude=gps_latitude,
        gps_longitude=gps_longitude,
        uploaded_at=datetime.now(timezone.utc),
        uploaded_by=current_user.id,
    )
    db.add(photo)
    db.commit()
    db.refresh(photo)

    logger.info(
        f"📱 Мобильное фото сохранено: id={photo.id}, "
        f"inspection={inspection.inspection_number}, "
        f"violation_order={violation_order}"
    )
    return photo