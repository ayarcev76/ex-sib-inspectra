"""Alembic env.py — читает URL из app.core.config."""
import sys
from pathlib import Path
from logging.config import fileConfig

# Добавляем корень проекта (backend/) в sys.path, чтобы импорты app.* работали
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import settings
from app.core.database import Base

# Импортируем все модели, чтобы Alembic их видел
from app.models import base  # noqa: F401
from app.models import references  # noqa: F401
# На следующих шагах добавим:
# from app.models import users, inspections, planning

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Переопределяем URL из settings (используем SYNC для Alembic)
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL_SYNC)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()