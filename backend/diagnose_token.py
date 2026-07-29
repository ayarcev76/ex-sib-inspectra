"""Диагностика: проверка, что роли попадают в токен."""
import sys
import inspect

# 1. Проверяем, что security.py обновлён
from app.core.security import create_access_token
sig = inspect.signature(create_access_token)
params = list(sig.parameters.keys())
print(f"🔍 Параметры create_access_token: {params}")

if 'extra_data' not in params:
    print("❌ ФАЙЛ security.py НЕ ОБНОВЛЁН! Параметр extra_data отсутствует.")
    print("   Текущая сигнатура:", sig)
    sys.exit(1)
else:
    print("✅ security.py обновлён (extra_data присутствует)")

# 2. Проверяем, что у User есть relationship roles
from app.models.users import User
if hasattr(User, 'roles'):
    print("✅ User.roles relationship существует")
else:
    print("❌ User.roles relationship НЕ найден!")
    sys.exit(1)

# 3. Проверяем роли админа в БД
from sqlalchemy import create_engine, text
from app.core.config import settings

engine = create_engine(settings.DATABASE_URL_SYNC)
with engine.connect() as conn:
    result = conn.execute(text('''
        SELECT r.name FROM "user" u 
        JOIN user_roles ur ON u.id = ur.user_id 
        JOIN role r ON ur.role_id = r.id 
        WHERE u.email = 'admin@exsib.ru'
    '''))
    roles = [row[0] for row in result.fetchall()]
    print(f"✅ Роли админа в БД: {roles}")

# 4. Тестируем создание токена с extra_data
from datetime import timedelta
token = create_access_token(
    subject="test-user-id",
    expires_delta=timedelta(minutes=15),
    extra_data={"roles": roles, "email": "admin@exsib.ru", "full_name": "Test"}
)

# 5. Декодируем и проверяем
from app.core.security import decode_token
payload = decode_token(token)
print(f"✅ Роли в тестовом токене: {payload.get('roles', [])}")
print(f"✅ Email в тестовом токене: {payload.get('email')}")

if payload.get('roles') == roles:
    print("\n🎉 ВСЁ РАБОТАЕТ! Проблема в том, что auth.py не обновлён или uvicorn не перезагрузился.")
else:
    print("\n❌ Ошибка в create_access_token")