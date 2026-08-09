# EX-Sib Inspectra: Инструкции для ИИ-агента

Это монорепозиторий, содержащий Backend (Python), Frontend (React) и Mobile (Flutter).

## Архитектура и Стек
- Backend: Python 3.12, FastAPI, SQLAlchemy 2.0, Alembic, Celery.
- Инфраструктура: PostgreSQL 15, Redis 7, MinIO. Управляется через `docker-compose.yml`.

## Правила работы
1. **Фокус на Backend:** По умолчанию работай только в папке `backend/`. Не трогай `frontend/` и `mobile/`, если я не попрошу.
2. **Виртуальное окружение:** Всегда используй `.venv` внутри папки `backend/`.
3. **Тестирование:** Перед коммитом всегда запускай `pytest` в папке `backend/`.
4. **База данных:** Если Docker недоступен в среде, используй SQLite для миграций и тестов.

## Полезные команды
- Запустить сервер: `uvicorn app.main:app --reload`
- Создать миграцию: `alembic revision --autogenerate -m "description"`
- Применить миграции: `alembic upgrade head`