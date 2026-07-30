"""Клиент MinIO для работы с S3-совместимым хранилищем."""
import logging
import boto3
from botocore.client import Config
from botocore.exceptions import ClientError

from app.core.config import settings

logger = logging.getLogger(__name__)

class MinIOClient:
    """Клиент для работы с MinIO (S3-совместимое хранилище)."""

    def __init__(self):
        """Инициализация клиента S3."""
        logger.info(
            f"🔧 Инициализация MinIO: internal={settings.MINIO_ENDPOINT}, "
            f"public={settings.MINIO_PUBLIC_ENDPOINT}, bucket={settings.MINIO_BUCKET}"
        )
        
        # 1. ВНУТРЕННИЙ КЛИЕНТ: для реальной передачи данных (upload, download, delete)
        self.s3_client = boto3.client(
            "s3",
            endpoint_url=settings.MINIO_ENDPOINT,
            aws_access_key_id=settings.MINIO_ACCESS_KEY,
            aws_secret_access_key=settings.MINIO_SECRET_KEY,
            region_name=settings.MINIO_REGION,
            config=Config(signature_version="s3v4"),
        )
        self.bucket = settings.MINIO_BUCKET

    def upload_file(self, file_content: bytes, object_key: str, content_type: str = "image/jpeg") -> str:
        try:
            logger.info(f"📤 Загрузка файла в MinIO: bucket={self.bucket}, key={object_key}")
            self.s3_client.put_object(
                Bucket=self.bucket,
                Key=object_key,
                Body=file_content,
                ContentType=content_type,
            )
            return object_key
        except ClientError as e:
            logger.error(f"❌ Ошибка загрузки файла в MinIO: {e}", exc_info=True)
            raise Exception(f"Ошибка загрузки файла в MinIO: {e}")

    def delete_file(self, object_key: str) -> bool:
        try:
            logger.info(f"🗑️ Удаление файла из MinIO: bucket={self.bucket}, key={object_key}")
            self.s3_client.delete_object(Bucket=self.bucket, Key=object_key)
            return True
        except ClientError as e:
            logger.error(f"❌ Ошибка удаления файла из MinIO: {e}", exc_info=True)
            raise Exception(f"Ошибка удаления файла из MinIO: {e}")

    def generate_presigned_url(self, object_key: str, expiration: int = 900) -> str:
        """
        Генерация presigned URL.
        ВАЖНО: Создаем временный клиент с ПУБЛИЧНЫМ эндпоинтом, 
        чтобы криптографическая подпись рассчитывалась для http://localhost:9000, 
        который понимает браузер пользователя.
        """
        try:
            public_s3_client = boto3.client(
                "s3",
                endpoint_url=settings.MINIO_PUBLIC_ENDPOINT,
                aws_access_key_id=settings.MINIO_ACCESS_KEY,
                aws_secret_access_key=settings.MINIO_SECRET_KEY,
                region_name=settings.MINIO_REGION,
                config=Config(signature_version="s3v4"),
            )
            
            url = public_s3_client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": object_key},
                ExpiresIn=expiration,
            )
            return url
        except ClientError as e:
            logger.error(f"❌ Ошибка генерации presigned URL: {e}", exc_info=True)
            raise Exception(f"Ошибка генерации presigned URL: {e}")

    def file_exists(self, object_key: str) -> bool:
        try:
            self.s3_client.head_object(Bucket=self.bucket, Key=object_key)
            return True
        except ClientError:
            return False

    def get_file_bytes(self, object_key: str) -> bytes:
        try:
            response = self.s3_client.get_object(Bucket=self.bucket, Key=object_key)
            return response["Body"].read()
        except ClientError as e:
            logger.error(f"❌ Ошибка получения файла {object_key} из MinIO: {e}", exc_info=True)
            raise RuntimeError(f"Ошибка получения файла {object_key} из MinIO: {e}")

# Глобальный экземпляр
minio_client = MinIOClient()

# Модульные обёртки
def get_file_bytes(object_key: str) -> bytes:
    return minio_client.get_file_bytes(object_key)

def upload_file(file_content: bytes, object_key: str, content_type: str = "image/jpeg") -> str:
    return minio_client.upload_file(file_content, object_key, content_type)

def delete_file(object_key: str) -> bool:
    return minio_client.delete_file(object_key)

def generate_presigned_url(object_key: str, expiration: int = 900) -> str:
    return minio_client.generate_presigned_url(object_key, expiration)