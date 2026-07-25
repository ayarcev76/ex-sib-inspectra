"""Корневой роутер API v1."""
from fastapi import APIRouter

from app.api.v1 import auth, references, users

router = APIRouter()

# Подключаем роутеры
router.include_router(auth.router)
router.include_router(references.router)
router.include_router(users.router)

@router.get("/health", tags=["system"])
def health_check():
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.2.0",
    }