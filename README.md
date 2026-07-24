# ЕХ:СИБ — Система инспекций безопасности

Автоматизация процесса проведения инспекций безопасности на производственных объектах ГК «ЕВРОХИМ».

## Быстрый старт (разработка)

1. Скопируйте окружение: `Copy-Item .env.example .env`
2. Поднимите инфраструктуру: `docker compose up -d`
3. Backend: создайте `.venv`, установите зависимости, запустите `uvicorn app.main:app --reload`
4. Frontend: `npm install`, затем `npm run dev`

## Доступы
- API (Swagger): http://localhost:8000/docs
- Frontend: http://localhost:5173
- MinIO Console: http://localhost:9001 (minioadmin / minioadmin_password_123)