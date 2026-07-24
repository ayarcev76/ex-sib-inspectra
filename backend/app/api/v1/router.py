"""Корневой роутер API v1."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/health", tags=["system"])
def health_check():
    """Health-check эндпоинт для Docker и мониторинга."""
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.1.0",
    }