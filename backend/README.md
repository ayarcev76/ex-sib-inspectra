# Backend — ЕХ:СИБ Inspectra

FastAPI + SQLAlchemy 2.0 + PostgreSQL + Redis + MinIO.

## Запуск локально

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # или .venv\Scripts\activate на Windows
pip install -r requirements.txt
uvicorn app.main:app --reload