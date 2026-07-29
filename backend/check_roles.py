"""Проверка ролей администратора в БД."""
from sqlalchemy import create_engine, text
from app.core.config import settings

# Используем правильное имя атрибута из Settings
engine = create_engine(settings.DATABASE_URL_SYNC)

with engine.connect() as conn:
    # Проверяем роли админа
    result = conn.execute(text('''
        SELECT u.email, r.name as role_name 
        FROM "user" u 
        LEFT JOIN user_roles ur ON u.id = ur.user_id 
        LEFT JOIN role r ON ur.role_id = r.id 
        WHERE u.email = 'admin@exsib.ru'
    '''))
    rows = result.fetchall()
    
    if not rows:
        print('❌ Админ не найден')
    else:
        print('✅ Роли админа:')
        for row in rows:
            role_display = row[1] if row[1] else '(нет ролей!)'
            print(f'   - {row[0]}: {role_display}')