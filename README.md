# ЕХ:Инспектра-СИПБ

> **Система инспекций производственной безопасности**
> Серверная часть + веб-интерфейс + мобильное приложение Inspectra

**Версия ТЗ:** 3.4 | **Дата:** 25.07.2026 | **Заказчик:** ГК «ЕВРОХИМ»

---

## 📋 О проекте

**ЕХ:Инспектра-СИПБ** — корпоративная система автоматизации инспекций производственной безопасности для группы компаний «ЕВРОХИМ».

Состоит из трёх компонентов:
- 📱 **Inspectra** (mobile/) — мобильное приложение для инспекторов на производственных объектах
- 🌐 **ЕХ:Инспектра-СИПБ** (frontend/) — веб-интерфейс для координаторов, руководителей, администраторов
- ⚙️ **Backend** (backend/) — единый REST API для обоих клиентов

### Ключевые возможности

- Автоматизация карт наблюдений с фотофиксацией (MinIO/S3)
- Автоматический расчёт «Топ-нарушений» по Золотым Правилам Безопасности
- Централизованное планирование инспекций (автогенерация + утверждение)
- Дашборд с drill-down (3 уровня) и экспортом в PDF
- Трёхканальные уведомления: Email + Push (FCM) + Внутренняя лента
- Ролевая модель с множественными ролями (6 ролей)
- Иерархия: ПЕ → Подразделение → Место работ
- Полный оффлайн-режим в мобильном приложении
- Сканирование QR-кодов объектов

---

## 🏗 Архитектура

```
┌─────────────────────────────────────────────────────┐
│              ЕХ:Инспектра-СИПБ                      │
├─────────────────────────────────────────────────────┤
│  mobile/ (Flutter)      frontend/ (React+TS+AntD)   │
│       │                          │                  │
│       └──────────┬───────────────┘                  │
│                  ▼                                  │
│            backend/ (FastAPI)                       │
│                  │                                  │
│   ┌──────────────┼──────────────┬──────────┐        │
│   ▼              ▼              ▼          ▼        │
│ PostgreSQL     Redis         MinIO     Celery       │
└─────────────────────────────────────────────────────┘
```

---

## 🛠 Технологический стек

| Компонент | Технология |
|-----------|------------|
| Backend | Python 3.12 + FastAPI + SQLAlchemy 2.0 + Alembic + Celery |
| Database | PostgreSQL 15+ |
| Cache / Broker | Redis 7+ |
| File Storage | MinIO (S3-совместимое) |
| Frontend (Web) | React 18 + TypeScript + Vite + Ant Design |
| Mobile | Flutter 3.44 + Dart + Firebase (FCM) |
| Контейнеризация | Docker + Docker Compose |
| CI/CD | GitHub Actions |
| Экспорт документов | jsPDF / pdfmake (frontend) + WeasyPrint (backend) |

---

## 🚀 Быстрый старт

### Предварительные требования

- Docker Desktop 29.6+ (Compose v5+)
- Python 3.12+ (рекомендуется; 3.14 требует компиляции пакетов)
- Node.js 18+ LTS
- Flutter 3.44+ (для мобильного приложения)
- Git 2.40+

### 1. Клонирование репозитория

```bash
git clone https://github.com/your-org/ex-sib-inspectra.git
cd ex-sib-inspectra
```

> 💡 **Примечание:** Внутреннее техническое имя репозитория (`ex-sib-inspectra`) сохранено для стабильности и обратной совместимости. Публичное название проекта — **ЕХ:Инспектра-СИПБ**.

### 2. Настройка переменных окружения

```bash
cp .env.example .env
# Отредактируйте .env: пароли PostgreSQL, MinIO, JWT-секреты, ключи Firebase
```

### 3. Запуск инфраструктуры

```bash
docker-compose up -d
```

Поднимутся сервисы:

| Сервис | Контейнер | Порт | Доступ |
|--------|-----------|------|--------|
| PostgreSQL 15 | `exsib-postgres` | 5432 | БД: `exsib`, user: `exsib` |
| Redis 7 | `exsib-redis` | 6379 | `localhost:6379` |
| MinIO | `exsib-minio` | 9000 / 9001 | Console: http://localhost:9001 |
| MinIO Init | `exsib-minio-init` | — | Авто-создание бакета `inspections` |

Проверка: `docker-compose ps`

### 4. Запуск Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Linux / macOS
# .venv\Scripts\activate         # Windows

pip install -r requirements.txt
pip install -e .                 # editable mode для Alembic

alembic upgrade head             # Применение миграций
python scripts/seed.py           # Наполнение справочников

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Backend: http://localhost:8000
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### 5. Запуск Frontend (ЕХ:Инспектра-СИПБ)

```bash
cd frontend
npm install
npm run dev
```

Веб-интерфейс: http://localhost:5173

### 6. Запуск мобильного приложения (Inspectra)

```bash
cd mobile
flutter pub get
flutter run
```

---

## 📁 Структура проекта

```
ex-sib-inspectra/
├── backend/                    # Python + FastAPI + SQLAlchemy + Alembic
│   ├── app/
│   │   ├── api/                # REST-эндпоинты (v1)
│   │   ├── core/               # Конфигурация, security, deps
│   │   ├── db/                 # Сессии, base
│   │   ├── models/             # SQLAlchemy-модели
│   │   ├── schemas/            # Pydantic-схемы
│   │   ├── services/           # Бизнес-логика
│   │   └── main.py
│   ├── alembic/                # Миграции БД
│   ├── scripts/                # Seed-скрипты
│   ├── tests/                  # pytest
│   ├── requirements.txt
│   └── pyproject.toml
│
├── frontend/                   # React + TypeScript + Vite + Ant Design
│   ├── src/
│   │   ├── api/                # Axios-клиент
│   │   ├── components/         # Переиспользуемые компоненты
│   │   ├── pages/              # Inspections, Dashboard, ...
│   │   ├── layouts/            # MainLayout, AuthLayout
│   │   ├── store/              # Zustand
│   │   ├── hooks/
│   │   ├── utils/
│   │   └── App.tsx
│   ├── public/
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
│
├── mobile/                     # Flutter (Inspectra)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/           # API, FCM, offline
│   │   ├── models/
│   │   └── providers/          # Riverpod
│   ├── test/
│   └── pubspec.yaml
│
├── docker/                     # Nginx, скрипты
├── docs/                       # Документация (ТЗ, отчёты)
├── .github/workflows/          # CI/CD
├── .vscode/                    # Настройки VS Code
├── docker-compose.yml
├── .env.example
├── .env                        # (в .gitignore)
├── .gitignore
├── CHANGELOG.md
└── README.md
```

---

## 🔐 Переменные окружения

Полный список — в `.env.example`. Ключевые:

```bash
# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=exsib
POSTGRES_USER=exsib
POSTGRES_PASSWORD=***

# Redis
REDIS_URL=redis://localhost:6379/0

# MinIO
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=***
MINIO_BUCKET=inspections

# JWT
JWT_SECRET_KEY=***
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# Firebase (FCM) — для push-уведомлений в Inspectra
FIREBASE_PROJECT_ID=***
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json

# App
APP_ENV=development
APP_DEBUG=true
```

---

## 📡 Основные API-эндпоинты

Полная документация — http://localhost:8000/docs

| Группа | Эндпоинты |
|--------|-----------|
| **Inspections** | `POST/GET /api/v1/inspections`, `GET/PUT/DELETE /api/v1/inspections/{id}` |
| **Violations** | `POST /api/v1/inspections/{id}/violations`, `PUT/DELETE /api/v1/violations/{id}` |
| **Photos** | `POST /api/v1/violations/{id}/photos`, `GET /api/v1/photos/{id}/original\|thumbnail` |
| **Plans** | `POST/GET /api/v1/plans`, `POST /api/v1/plans/{id}/approve`, `POST /api/v1/plans/generate` |
| **Assignments** | `GET/POST /api/v1/users/{id}/assignments`, `POST /api/v1/assignments/{id}/terminate` |
| **References** | `/api/v1/references/pe\|departments\|contractors\|work-types\|zpb-rules` |
| **Dashboard** | `/api/v1/dashboard/kpi`, `/charts/*`, `/export/pdf` |
| **Reports** | `/api/v1/reports/plan-execution`, `/api/v1/reports/schedule` |
| **Notifications** | `GET /api/v1/notifications`, `POST /api/v1/notifications/{id}/read` |
| **Auth** | `POST /api/v1/auth/login`, `/refresh`, `/logout` |

---

## 📅 Этапы разработки

| Этап | Описание | Срок |
|------|----------|------|
| 0 | Подготовка окружения | ✅ Завершён |
| 1 | Проектирование БД | ✅ Завершён |
| 2 | Backend: базовый CRUD + роли | 2 недели |
| 3 | Backend: планирование + уведомления | 1 неделя |
| 4 | Backend: фото + бизнес-логика | 1 неделя |
| 5 | Frontend: админка + формы | 3 недели |
| 6 | Frontend: дашборд + экспорт PDF | 1 неделя |
| 7 | Тестирование | 1 неделя |
| 8 | Mobile app Inspectra (MVP + оффлайн + QR) | 4 недели |
| 9 | Интеграция, бэкапы, приёмка | 2 недели |
| **Итого** | | **~16 недель** |

---

## 📚 Документация

Все документы находятся в папке `docs/`:

- `ТЗ_ЕХ_Инспектра-СИПБ_v3.4.docx` — Техническое задание (актуальная версия)
- `Отчет_Этап_0_Подготовка.docx` — Отчёт о подготовке окружения
- `Отчет_Этап_1_Проектирование_БД.docx` — Отчёт о проектировании БД

---

## 🧪 Тестирование

```bash
# Backend
cd backend
pytest

# Frontend
cd frontend
npm test

# Mobile
cd mobile
flutter test
```

---

## 🔒 Безопасность

- JWT-аутентификация (access 15 мин + refresh 7 дней)
- Хеширование паролей: bcrypt
- Ролевая модель (RBAC) с множественными ролями
- HTTPS/TLS 1.3
- Валидация входных данных (Pydantic)
- Защита от SQL-инъекций (ORM) и XSS (React)
- CORS-политика, Rate limiting
- Приватные URL для файлов с временными подписями (presigned URLs, 15 мин)

---

## 📦 Резервное копирование

Автоматические бэкапы настраиваются на Этапе 9:
- **PostgreSQL:** `pg_dump` по расписанию
- **MinIO:** синхронизация бакета `inspections`

---

## 🤝 Вклад в проект

1. Создайте ветку от `develop`: `git checkout -b feature/my-feature`
2. Внесите изменения и закоммитьте
3. Откройте Pull Request в `develop`

Перед коммитом убедитесь, что:
- Пройдены все тесты (`pytest`, `npm test`, `flutter test`)
- Код отформатирован (`black`, `prettier`, `dart format`)
- Обновлена документация (при необходимости)

---

## 📄 Лицензия

Проприетарная. Все права принадлежат ГК «ЕВРОХИМ».
Распространение и использование без письменного разрешения запрещено.

---

## 📞 Контакты

- **Заказчик:** ГК «ЕВРОХИМ», Департамент производственной безопасности
- **Технический руководитель:** [указать]
- **Команда разработки:** [указать]
- **Email:** [указать]

---

> **Примечание:** Внутренние технические имена (имена Docker-контейнеров, БД, переменных окружения) сохранены как `exsib` для обеспечения стабильности работы системы и обратной совместимости. Публичное название продукта — **ЕХ:Инспектра-СИПБ**.

---

*© 2026 ГК «ЕВРОХИМ». Все права защищены.*