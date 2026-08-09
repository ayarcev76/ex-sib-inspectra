# 🚀 Быстрый старт: Внедрение улучшений

## 1️⃣ Настройка окружения разработчика (5 минут)

```bash
# Клонирование и переход в директорию
cd /workspace

# Установка pre-commit хуков
pip install pre-commit
pre-commit install

# Установка dev-зависимостей для backend
cd backend
pip install -r requirements-dev.txt
cd ..
```

## 2️⃣ Проверка работы репозиториев (2 минуты)

```bash
cd backend

# Запуск тестов репозиториев
pytest tests/test_repositories.py -v

# Запуск с покрытием
pytest tests/test_repositories.py --cov=app/repositories --cov-report=term-missing
```

## 3️⃣ Использование репозиториев в коде

### Пример эндпоинта с репозиторием:

```python
from fastapi import APIRouter, Depends
from app.repositories.users import UserRepository
from app.api.deps import get_db

router = APIRouter()

def get_user_repo(db = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

@router.get("/users/{user_id}")
async def get_user(
    user_id: UUID,
    repo: UserRepository = Depends(get_user_repo)
):
    user = await repo.get_by_id(user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return user
```

## 4️⃣ Настройка логирования

### В main.py добавьте:

```python
from app.core.logging_config import setup_logging

# Перед созданием приложения
setup_logging(
    log_level="INFO",
    log_format="json"  # Используйте "console" для локальной разработки
)
```

### Использование в коде:

```python
from app.core.logging_config import get_logger

logger = get_logger(__name__)

# Простое логирование
logger.info("Processing started")

# С контекстом
logger.info(
    "User action completed",
    user_id=user.id,
    action="create_inspection",
    duration_ms=150
)

# С исключением
try:
    risky_operation()
except Exception as e:
    logger.exception("Operation failed", error=str(e))
```

## 5️⃣ CI/CD пайплайны

Пайплайны уже настроены в `.github/workflows/`:

- **backend-ci.yml** - запускается при изменении файлов backend
- **frontend-ci.yml** - запускается при изменении файлов frontend
- **mobile-ci.yml** - запускается при изменении файлов mobile

### Для активации:

1. Перейдите в Settings вашего GitHub репозитория
2. Откройте Secrets and variables → Actions
3. Добавьте необходимые секреты:
   - `DOCKER_USERNAME`
   - `DOCKER_PASSWORD`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## 6️⃣ Pre-commit хуки

Хуки автоматически проверяют код перед коммитом:

```bash
# Ручной запуск всех хуков
pre-commit run --all-files

# Запуск конкретного хука
pre-commit run ruff --all-files
```

## 7️⃣ Расширение на другие сущности

### Шаблон для создания нового репозитория:

```python
# backend/app/repositories/pe.py
from typing import Optional, List
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.references import PE

class PERepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    
    async def get_by_id(self, pe_id: UUID) -> Optional[PE]:
        return await self.session.get(PE, pe_id)
    
    async def get_all(self, skip: int = 0, limit: int = 100) -> List[PE]:
        result = await self.session.execute(
            select(PE).offset(skip).limit(limit)
        )
        return list(result.scalars().all())
    
    async def create(self, pe_data: dict) -> PE:
        pe = PE(**pe_data)
        self.session.add(pe)
        await self.session.flush()
        await self.session.refresh(pe)
        return pe
```

## 8️⃣ Миграция существующего кода

### До:
```python
@router.get("/users/{user_id}")
def get_user(user_id: UUID, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "Not found")
    return user
```

### После:
```python
@router.get("/users/{user_id}")
async def get_user(
    user_id: UUID,
    repo: UserRepository = Depends(get_user_repo)
):
    user = await repo.get_by_id(user_id)
    if not user:
        raise HTTPException(404, "Not found")
    return user
```

## 📊 Чеклист внедрения

- [ ] Установлены dev-зависимости
- [ ] Настроены pre-commit хуки
- [ ] Тесты репозиториев проходят
- [ ] Логирование настроено в main.py
- [ ] CI/CD пайплайны активированы
- [ ] Создан первый репозиторий для новой сущности
- [ ] Обновлена документация проекта

## 🆘 Troubleshooting

### Ошибка импорта репозиториев
```bash
# Убедитесь, что установлен текущий пакет
cd backend
pip install -e .
```

### Pre-commit не работает
```bash
# Переустановите хуки
pre-commit uninstall
pre-commit install
```

### Тесты не находят фикстуры
```bash
# Проверьте conftest.py
cat tests/conftest.py
```

---

**Время внедрения:** ~15 минут  
**Сложность:** Низкая  
**Отдача:** Высокая
