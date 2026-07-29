"""Клиент MinIO для работы с S3-совместимым хранилищем."""
import os
import logging
from typing import Optional

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

# ==================== Конфигурация MinIO ====================
# Из переменных окружения (.env)
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "inspections")
MINIO_REGION = os.getenv("MINIO_REGION", "us-east-1")


class MinIOClient:
    """Клиент для работы с MinIO (S3-совместимое хранилище)."""

    def __init__(self):
        """Инициализация клиента S3."""
        logger.info(
            f"🔧 Инициализация MinIO клиента: endpoint={MINIO_ENDPOINT}, "
            f"bucket={MINIO_BUCKET}"
        )
        self.s3_client = boto3.client(
            "s3",
            endpoint_url=MINIO_ENDPOINT,
            aws_access_key_id=MINIO_ACCESS_KEY,
            aws_secret_access_key=MINIO_SECRET_KEY,
            region_name=MINIO_REGION,
            config=Config(signature_version="s3v4"),
        )
        self.bucket = MINIO_BUCKET

    def upload_file(
        self,
        file_content: bytes,
        object_key: str,
        content_type: str = "image/jpeg",
    ) -> str:
        """
        Загрузка файла в MinIO.

        Args:
            file_content: Содержимое файла в байтах
            object_key: Путь к объекту в бакете
            content_type: MIME-тип файла

        Returns:
            Путь к загруженному объекту (object_key)
        """
        try:
            logger.info(
                f"📤 Загрузка файла в MinIO: bucket={self.bucket}, "
                f"key={object_key}, size={len(file_content)} байт"
            )
            self.s3_client.put_object(
                Bucket=self.bucket,
                Key=object_key,
                Body=file_content,
                ContentType=content_type,
            )
            logger.info(f"✅ Файл успешно загружен: {object_key}")
            return object_key
        except ClientError as e:
            logger.error(f"❌ Ошибка загрузки файла в MinIO: {e}", exc_info=True)
            raise Exception(f"Ошибка загрузки файла в MinIO: {e}")

    def delete_file(self, object_key: str) -> bool:
        """
        Удаление файла из MinIO.

        Args:
            object_key: Путь к объекту в бакете

        Returns:
            True если успешно
        """
        try:
            logger.info(
                f"🗑️ Удаление файла из MinIO: bucket={self.bucket}, key={object_key}"
            )
            self.s3_client.delete_object(
                Bucket=self.bucket,
                Key=object_key,
            )
            logger.info(f"✅ Файл успешно удален: {object_key}")
            return True
        except ClientError as e:
            logger.error(f"❌ Ошибка удаления файла из MinIO: {e}", exc_info=True)
            raise Exception(f"Ошибка удаления файла из MinIO: {e}")

    def generate_presigned_url(
        self,
        object_key: str,
        expiration: int = 900,  # 15 минут
    ) -> str:
        """
        Генерация presigned URL для временного доступа к файлу.

        Args:
            object_key: Путь к объекту в бакете
            expiration: Время жизни URL в секундах (по умолчанию 15 мин)

        Returns:
            Presigned URL
        """
        try:
            logger.info(
                f"🔗 Генерация presigned URL: bucket={self.bucket}, "
                f"key={object_key}, expiration={expiration}с"
            )
            url = self.s3_client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": object_key},
                ExpiresIn=expiration,
            )
            logger.info(f"✅ Presigned URL сгенерирован")
            return url
        except ClientError as e:
            logger.error(
                f"❌ Ошибка генерации presigned URL: {e}", exc_info=True
            )
            raise Exception(f"Ошибка генерации presigned URL: {e}")

    def file_exists(self, object_key: str) -> bool:
        """
        Проверка существования файла в MinIO.

        Args:
            object_key: Путь к объекту в бакете

        Returns:
            True если файл существует
        """
        try:
            self.s3_client.head_object(
                Bucket=self.bucket,
                Key=object_key,
            )
            return True
        except ClientError:
            return False

    def get_file_bytes(self, object_key: str) -> bytes:
        """
        Получить содержимое файла из MinIO как bytes.

        Используется, например, для экспорта в PDF/DOCX,
        где нужно вставить изображение в документ.

        Args:
            object_key: Путь к объекту в бакете

        Returns:
            Содержимое файла в виде bytes

        Raises:
            RuntimeError: если файл не найден или произошла ошибка чтения
        """
        try:
            logger.info(
                f"📥 Получение файла из MinIO: bucket={self.bucket}, key={object_key}"
            )
            response = self.s3_client.get_object(
                Bucket=self.bucket,
                Key=object_key,
            )
            # response['Body'] — это StreamingBody, у него есть метод read()
            data = response["Body"].read()
            logger.info(
                f"✅ Файл получен: {object_key}, размер {len(data)} байт"
            )
            return data
        except ClientError as e:
            logger.error(
                f"❌ Ошибка получения файла {object_key} из MinIO: {e}",
                exc_info=True,
            )
            raise RuntimeError(
                f"Ошибка получения файла {object_key} из MinIO: {e}"
            )


# ==================== Глобальный экземпляр клиента ====================
# Создаётся один раз при импорте модуля и переиспользуется во всём приложении.
minio_client = MinIOClient()


# ==================== Модульные функции-обёртки ====================
# Для удобства импорта в других модулях (например, export_service.py):
#   from app.core.minio_client import get_file_bytes

def get_file_bytes(object_key: str) -> bytes:
    """
    Модульная обёртка над методом MinIOClient.get_file_bytes().

    Позволяет вызывать функцию напрямую без обращения к глобальному
    экземпляру minio_client:
        from app.core.minio_client import get_file_bytes
        data = get_file_bytes("photos/abc123/original.jpg")
    """
    return minio_client.get_file_bytes(object_key)


def upload_file(file_content: bytes, object_key: str, content_type: str = "image/jpeg") -> str:
    """Модульная обёртка над MinIOClient.upload_file()."""
    return minio_client.upload_file(file_content, object_key, content_type)


def delete_file(object_key: str) -> bool:
    """Модульная обёртка над MinIOClient.delete_file()."""
    return minio_client.delete_file(object_key)


def generate_presigned_url(object_key: str, expiration: int = 900) -> str:
    """Модульная обёртка над MinIOClient.generate_presigned_url()."""
    return minio_client.generate_presigned_url(object_key, expiration)