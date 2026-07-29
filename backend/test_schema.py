"""Тестовый скрипт для проверки схемы InspectionUpdate."""
from app.schemas.inspections import InspectionUpdate

# Проверяем, что Python видит в аннотации типа
print(f"🔍 Аннотация типа для 'date': {InspectionUpdate.model_fields['date'].annotation}")

test_data = {
    "date": "2026-07-27",
    "pe_id": "aad057bc-e004-408d-9254-1e3dc09de99a",
    "department_id": "0257eb4a-b0a7-4a4c-8449-529c5a19849c",
    "work_location": "Тест",
    "violations": []
}

try:
    update = InspectionUpdate(**test_data)
    print(f"✅ Успешно! date={update.date}, type={type(update.date)}")
except Exception as e:
    print(f"❌ Ошибка: {e}")