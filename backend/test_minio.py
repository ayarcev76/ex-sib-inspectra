"""Тестовый скрипт для проверки подключения к MinIO."""
import os
from pathlib import Path
from dotenv import load_dotenv

# 1. Явно загружаем файл .env из папки backend
env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=env_path)

# 2. Выводим значения, которые видит скрипт (для отладки)
print("=" * 50)
print("🔍 ПРОВЕРКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ:")
print(f"MINIO_ENDPOINT:    {os.getenv('MINIO_ENDPOINT')}")
print(f"MINIO_ACCESS_KEY:  {os.getenv('MINIO_ACCESS_KEY')}")
print(f"MINIO_SECRET_KEY:  {os.getenv('MINIO_SECRET_KEY')}")
print(f"MINIO_BUCKET:      {os.getenv('MINIO_BUCKET')}")
print("=" * 50)

# 3. Импортируем клиент ПОСЛЕ загрузки .env
from app.core.minio_client import minio_client

try:
    print(f"\n📦 Проверка бакета: {minio_client.bucket}")
    
    # Пытаемся загрузить тестовый файл
    test_content = b"Hello, MinIO! This is a test."
    test_key = "test/hello.txt"
    
    print(f"📤 Загрузка тестового файла: {test_key}...")
    minio_client.upload_file(test_content, test_key, "text/plain")
    print(f"✅ Файл успешно загружен!")
    
    # Проверяем существование
    exists = minio_client.file_exists(test_key)
    print(f"✅ Файл существует: {exists}")
    
    # Генерируем presigned URL
    url = minio_client.generate_presigned_url(test_key)
    print(f"✅ Presigned URL сгенерирован: {url[:60]}...")
    
    # Удаляем тестовый файл
    minio_client.delete_file(test_key)
    print(f"✅ Тестовый файл удален")
    
    print("\n🎉 MinIO работает корректно! Интеграция настроена успешно.")
    
except Exception as e:
    print(f"\n❌ Ошибка подключения к MinIO: {type(e).__name__}: {e}")
    print("\n💡 Если пароль выше отображается как 'minioadmin' (без _123),")
    print("   значит файл .env всё ещё не читается или содержит опечатку.")