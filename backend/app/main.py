"""Точка входа FastAPI приложения."""
# ============================================================================
# КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Перенаправление TEMP-папки
# Должно быть в САМОМ НАЧАЛЕ файла, ДО всех остальных импортов!
# Это решает баг Windows с короткими именами папок (8.3 формат, например 8523~1)
# в библиотеке xhtml2pdf, которая копирует шрифты во временную папку.
# ============================================================================
import os
import tempfile

# Создаём простую TEMP-папку без кириллицы и пробелов в пути
TEMP_DIR = "C:\\Temp"
os.makedirs(TEMP_DIR, exist_ok=True)

# Перенаправляем все переменные окружения, отвечающие за временные файлы
os.environ['TEMP'] = TEMP_DIR
os.environ['TMP'] = TEMP_DIR

# Перенаправляем модуль tempfile (используется xhtml2pdf и reportlab)
tempfile.tempdir = TEMP_DIR
# ============================================================================

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from slowapi.errors import RateLimitExceeded
from app.core.rate_limit import limiter, rate_limit_exceeded_handler

# Загружаем переменные окружения из .env файла
load_dotenv()

# Настраиваем логирование
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения."""
    logger.info("🚀 Запуск приложения ЕХ:Инспектра-ИПБ...")
    logger.info(f"📁 TEMP-папка: {tempfile.gettempdir()}")
    yield
    logger.info("🛑 Остановка приложения...")


# Создание экземпляра FastAPI
app = FastAPI(
    title="ЕХ:Инспектра-ИПБ API",
    description="Система инспекций производственной безопасности ГК «ЕВРОХИМ»",
    version="0.5.0",
    lifespan=lifespan,
)

# Подключаем rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)

# Настройка CORS (для доступа с фронтенда)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Подключение API-роутеров
from app.api.v1.router import router as v1_router

app.include_router(v1_router, prefix="/api/v1")


# Health-check эндпоинт
@app.get("/health", tags=["system"])
def health_check():
    """Проверка работоспособности сервиса."""
    return {
        "status": "ok",
        "service": "exsib-backend",
        "version": "0.5.0",
    }


# Корневой эндпоинт
@app.get("/", tags=["system"])
def root():
    """Корневой эндпоинт API."""
    return {
        "message": "ЕХ:Инспектра-ИПБ API",
        "docs": "/docs",
        "health": "/health",
    }