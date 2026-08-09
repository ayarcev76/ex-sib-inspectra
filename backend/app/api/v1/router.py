"""Корневой роутер API v1.

Агрегирует все роутеры модулей и регистрирует системные эндпоинты.
Точка входа: /api/v1/*
"""
from fastapi import APIRouter

from app.api.v1 import auth, inspections, photos, references, users, export

router = APIRouter()

# ══════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ РОУТЕРОВ
# ══════════════════════════════════════════════════════════════

# ─── Аутентификация и пользователи ────────────────────────────
router.include_router(auth.router)
router.include_router(users.router)

# ─── Справочники (ПЕ, подразделения, подрядчики, виды работ, ЗПБ) ─
router.include_router(references.router)

# ─── Карты наблюдений (инспекции + нарушения) ─────────────────
router.include_router(inspections.router)

# ─── Фотографии нарушений (веб-интерфейс) ─────────────────────
# Пути: /api/v1/violations/{violation_id}/photos/*
router.include_router(photos.router)

# ─── Фотографии нарушений (мобильное приложение Inspectra) ────
# Путь: /api/v1/photos/mobile
# Использует offline-first поиск по inspection_client_id + violation_order
router.include_router(photos.mobile_router)

# ─── Экспорт в PDF/DOCX ───────────────────────────────────────
router.include_router(export.router)


# ══════════════════════════════════════════════════════════════
# СИСТЕМНЫЕ ЭНДПОИНТЫ
# ══════════════════════════════════════════════════════════════

@router.get("/health", tags=["system"])
def health_check():
    """Проверка работоспособности сервиса."""
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.6.0",
    }