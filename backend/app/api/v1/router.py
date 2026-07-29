"""Корневой роутер API v1."""
from fastapi import APIRouter
from app.api.v1 import auth, inspections, photos, references, users, export

router = APIRouter()

# Подключаем роутеры
router.include_router(auth.router)
router.include_router(references.router)
router.include_router(users.router)
router.include_router(inspections.router)
router.include_router(photos.router)
router.include_router(export.router)  # <-- Экспорт в PDF/DOCX


@router.get("/health", tags=["system"])
def health_check():
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.5.0",
    }