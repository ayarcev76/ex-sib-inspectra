"""Эндпоинты для работы с фотографиями нарушений."""
import uuid
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user, CurrentUser
from app.models.inspections import ViolationPhoto, ViolationRecord
from app.schemas.inspections import ViolationPhotoResponse
from app.services.photo_service import photo_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/violations/{violation_id}/photos", tags=["Фотографии"])


@router.post(
    "/",
    response_model=ViolationPhotoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Загрузка фотографии к нарушению",
)
async def upload_photo(
    violation_id: uuid.UUID,
    file: UploadFile = File(...),
    db: Annotated[Session, Depends(get_db)] = None,
    current_user: CurrentUser = None,
):
    """
    Загрузка фотографии к нарушению с автоматической обработкой.
    """
    logger.info(f"📥 POST /violations/{violation_id}/photos: filename={file.filename}, content_type={file.content_type}")
    
    # Проверка существования нарушения
    violation = db.query(ViolationRecord).filter(ViolationRecord.id == violation_id).first()
    if not violation:
        logger.warning(f"⚠️ Нарушение не найдено: {violation_id}")
        raise HTTPException(status_code=404, detail="Нарушение не найдено")
    
    # Проверка, что нарушение не "всё безопасно"
    if violation.is_safe:
        logger.warning(f"⚠️ Попытка добавить фото к 'всё безопасно': {violation_id}")
        raise HTTPException(
            status_code=400,
            detail="Нельзя добавить фото к наблюдению 'Всё безопасно'"
        )
    
    # Чтение содержимого файла
    file_content = await file.read()
    logger.info(f"📄 Прочитано {len(file_content)} байт из файла {file.filename}")
    
    try:
        # Обработка и загрузка фотографии
        photo_data = photo_service.upload_photo(
            violation_id=violation_id,
            file_content=file_content,
            original_filename=file.filename or "unknown.jpg",
            mime_type=file.content_type or "image/jpeg",
            uploaded_by=current_user.id,
        )
        
        # Создание записи в БД
        photo = ViolationPhoto(
            violation_id=violation_id,
            file_path=photo_data["file_path"],
            thumbnail_path=photo_data["thumbnail_path"],
            original_filename=photo_data["original_filename"],
            file_size=photo_data["file_size"],
            mime_type=photo_data["mime_type"],
            gps_latitude=photo_data["gps_latitude"],
            gps_longitude=photo_data["gps_longitude"],
            uploaded_by=photo_data["uploaded_by"],
        )
        
        db.add(photo)
        db.commit()
        db.refresh(photo)
        
        logger.info(f"✅ Фотография успешно сохранена в БД: id={photo.id}")
        return photo
    
    except ValueError as e:
        logger.error(f"❌ Ошибка валидации: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"❌ Ошибка загрузки фотографии: {type(e).__name__}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка загрузки фотографии: {str(e)}")


@router.get(
    "/",
    response_model=list[ViolationPhotoResponse],
    summary="Список фотографий нарушения",
)
def list_photos(
    violation_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)] = None,
):
    """Получение списка всех фотографий, прикрепленных к нарушению."""
    violation = db.query(ViolationRecord).filter(ViolationRecord.id == violation_id).first()
    if not violation:
        raise HTTPException(status_code=404, detail="Нарушение не найдено")
    
    return violation.photos


@router.get(
    "/{photo_id}/original",
    summary="Получение presigned URL для оригинала фотографии",
)
def get_original_photo_url(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)] = None,
):
    """Генерация presigned URL для временного доступа к оригиналу фотографии."""
    photo = db.query(ViolationPhoto).filter(
        ViolationPhoto.id == photo_id,
        ViolationPhoto.violation_id == violation_id,
    ).first()
    
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")
    
    url = photo_service.get_presigned_url(photo.file_path)
    return {"url": url, "expires_in": 900}


@router.get(
    "/{photo_id}/thumbnail",
    summary="Получение presigned URL для миниатюры фотографии",
)
def get_thumbnail_photo_url(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)] = None,
):
    """Генерация presigned URL для временного доступа к миниатюре фотографии."""
    photo = db.query(ViolationPhoto).filter(
        ViolationPhoto.id == photo_id,
        ViolationPhoto.violation_id == violation_id,
    ).first()
    
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")
    
    if not photo.thumbnail_path:
        raise HTTPException(status_code=404, detail="Миниатюра не найдена")
    
    url = photo_service.get_presigned_url(photo.thumbnail_path)
    return {"url": url, "expires_in": 900}


@router.delete(
    "/{photo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удаление фотографии",
)
def delete_photo(
    violation_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)] = None,
    _: CurrentUser = None,
):
    """Удаление фотографии из MinIO и базы данных."""
    photo = db.query(ViolationPhoto).filter(
        ViolationPhoto.id == photo_id,
        ViolationPhoto.violation_id == violation_id,
    ).first()
    
    if not photo:
        raise HTTPException(status_code=404, detail="Фотография не найдена")
    
    try:
        photo_service.delete_photo(photo.file_path, photo.thumbnail_path)
        db.delete(photo)
        db.commit()
    except Exception as e:
        logger.error(f"❌ Ошибка удаления фотографии: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка удаления фотографии: {str(e)}")