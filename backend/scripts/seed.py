"""Скрипт наполнения БД начальными данными (Seed)."""
import sys
from pathlib import Path

# Добавляем корень проекта в sys.path для корректных импортов
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text
from sqlalchemy.orm import Session
from passlib.context import CryptContext

from app.core.database import SessionLocal, engine
from app.models.users import Role, User
from app.models.references import PE, WorkType, ZPBRule

# Настройка хеширования паролей (bcrypt)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def get_or_create_role(db: Session, name: str, display_name: str, description: str) -> Role:
    """Создает роль, если её ещё нет."""
    role = db.query(Role).filter(Role.name == name).first()
    if not role:
        role = Role(name=name, display_name=display_name, description=description)
        db.add(role)
        db.commit()
        db.refresh(role)
    return role


def seed_roles(db: Session):
    """Наполнение справочника ролей (п. 3.1 ТЗ)."""
    roles_data = [
        ("admin", "Администратор", "Полный доступ ко всем функциям системы"),
        ("coordinator", "Координатор", "Планирование, назначение, контроль качества"),
        ("manager", "Руководитель", "Возможности координатора + дашборды, аналитика"),
        ("inspector", "Инспектор", "Проведение проверок, заполнение карт, фотофиксация"),
        ("observer", "Наблюдатель", "Аудит, внешние проверяющие (только просмотр)"),
        ("contractor", "Подрядчик", "Просмотр своих нарушений, отметка об устранении"),
    ]
    for name, display_name, description in roles_data:
        get_or_create_role(db, name, display_name, description)
    print("✅ Роли добавлены/проверены.")


def seed_zpb_rules(db: Session):
    """Наполнение справочника Золотых Правил Безопасности (п. 8.2 ТЗ)."""
    zpb_data = [
        (1, "Оценка рисков", "Я всегда думаю, прежде чем делаю — оцениваю риски перед началом работы"),
        (2, "СИЗ", "Я всегда работаю в СИЗ"),
        (3, "Наряд-допуск", "Я всегда соблюдаю требования наряда-допуска"),
        (4, "Право на остановку", "Я всегда могу отказаться от опасной работы"),
        (5, "Нештатные ситуации", "Я всегда знаю, как действовать в нештатных ситуациях"),
        (6, "Трезвость", "Я никогда не позволяю себе и другим работать в нетрезвом состоянии"),
        (7, "Сокрытие инцидентов", "Я никогда не скрываю информацию о происшествиях на производстве"),
    ]
    for number, name, description in zpb_data:
        if not db.query(ZPBRule).filter(ZPBRule.number == number).first():
            db.add(ZPBRule(number=number, name=name, description=description))
    db.commit()
    print("✅ Золотые Правила Безопасности (7 шт.) добавлены/проверены.")


def seed_work_types(db: Session):
    """Наполнение справочника видов работ (п. 8.1 ТЗ)."""
    work_types_data = [
        ("Ремонтные работы", "REPAIR", "Плановые и аварийные ремонтные работы"),
        ("Огневые работы", "HOT_WORK", "Сварка, резка, пайка и другие работы с открытым огнем"),
        ("Газоопасные работы", "GAS_HAZARD", "Работы в замкнутых пространствах, с загазованностью"),
        ("Работы на высоте", "HEIGHT", "Работы на высоте более 1.8 м без ограждений"),
        ("Работы с ГПМ", "LIFTING", "Работы с применением грузоподъемных механизмов"),
        ("Текущая эксплуатация", "OPERATION", "Повседневные эксплуатационные операции"),
        ("Земляные работы", "EARTH", "Рытье траншей, котлованов, планировка грунта"),
        ("Электромонтажные работы", "ELECTRICAL", "Работы с электроустановками до и выше 1000В"),
    ]
    for name, code, description in work_types_data:
        if not db.query(WorkType).filter(WorkType.code == code).first():
            db.add(WorkType(name=name, code=code, description=description))
    db.commit()
    print("✅ Виды работ (8 шт.) добавлены/проверены.")


def seed_pes(db: Session):
    """Наполнение справочника Производственных Единиц (п. 2.1 ТЗ)."""
    pe_data = [
        ("ООО «ЕВРОХИМ-БМУ»", "BMU"),
        ("ООО «ПГ Фосфорит»", "PHOSPHORIT"),
        ("АО «НАК Азот»", "NAK_AZOT"),
        ("АО «Невинномысский Азот»", "NEV_AZOT"),
        ("АО «ЕВРОХИМ-Северо-Запад»", "SEVERO_ZAPAD"),
    ]
    for name, code in pe_data:
        if not db.query(PE).filter(PE.code == code).first():
            db.add(PE(name=name, code=code))
    db.commit()
    print("✅ Производственные единицы (5 шт.) добавлены/проверены.")


def seed_admin_user(db: Session):
    """Создание тестового пользователя-администратора."""
    admin_email = "admin@exsib.ru"
    user = db.query(User).filter(User.email == admin_email).first()
    if not user:
        admin_role = db.query(Role).filter(Role.name == "admin").first()
        hashed_pwd = pwd_context.hash("Admin123!")
        
        user = User(
            email=admin_email,
            full_name="Администратор Системы",
            hashed_password=hashed_pwd,
            is_active=True,
        )
        if admin_role:
            user.roles.append(admin_role)
            
        db.add(user)
        db.commit()
        print("✅ Тестовый администратор создан (login: admin@exsib.ru, password: Admin123!)")
    else:
        print("ℹ️ Администратор уже существует.")


def main():
    """Главная функция запуска seed-скрипта."""
    print("🚀 Запуск наполнения БД начальными данными...")
    
    # Проверка подключения к БД
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as e:
        print(f"❌ Ошибка подключения к БД: {e}")
        sys.exit(1)

    db = SessionLocal()
    try:
        seed_roles(db)
        seed_zpb_rules(db)
        seed_work_types(db)
        seed_pes(db)
        seed_admin_user(db)
        print("\n🎉 Seed-скрипт успешно завершен! База данных готова к работе.")
    except Exception as e:
        print(f"\n❌ Ошибка при выполнении seed-скрипта: {e}")
        db.rollback()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()