"""Точка входа FastAPI-приложения."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.api.v1.router import router as v1_router

app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    description="Система инспекций безопасности ЕХ:СИБ",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключаем роутеры
app.include_router(v1_router, prefix="/api/v1")


@app.get("/", tags=["system"])
def root():
    return {"message": "ЕХ:СИБ Inspectra API is running"}