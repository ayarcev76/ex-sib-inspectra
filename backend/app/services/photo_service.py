"""Сервис для работы с фотографиями нарушений."""
import io
import uuid
import logging
from datetime import datetime
from typing import Optional

from PIL import Image, ExifTags

from app.core.minio_client import minio_client

logger = logging.getLogger(__name__)

# Константы (согласно ТЗ п. 5.2.4)
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 МБ
ALLOWED_MIME_TYPES = ["image/jpeg", "image/jpg", "image/png"]
THUMBNAIL_SIZE = (320, 240)
OPTIMIZED_SIZE = (1920, 1080)
OPTIMIZED_QUALITY = 85


class PhotoService:
    """Сервис для обработки и хранения фотографий."""
    
    @staticmethod
    def validate_photo(file_size: int, mime_type: str) -> None:
        """
        Валидация фотографии перед загрузкой.
        
        Args:
            file_size: Размер файла в байтах
            mime_type: MIME-тип файла
        
        Raises:
            ValueError: Если файл не соответствует требованиям
        """
        logger.info(f"🔍 Валидация фото: size={file_size} байт, mime_type={mime_type}")
        
        if file_size > MAX_FILE_SIZE:
            raise ValueError(f"Размер файла превышает {MAX_FILE_SIZE // (1024 * 1024)} МБ")
        
        if mime_type not in ALLOWED_MIME_TYPES:
            raise ValueError(f"Недопустимый формат файла. Разрешены: {', '.join(ALLOWED_MIME_TYPES)}")
        
        logger.info("✅ Валидация пройдена")
    
    @staticmethod
    def extract_exif_data(image_bytes: bytes) -> dict:
        """
        Извлечение EXIF-данных из изображения.
        
        Args:
            image_bytes: Содержимое изображения в байтах
        
        Returns:
            Словарь с GPS-координатами и временем съемки
        """
        try:
            logger.info("📍 Извлечение EXIF-данных...")
            image = Image.open(io.BytesIO(image_bytes))
            exif_data = image._getexif()
            
            if not exif_data:
                logger.info("ℹ️ EXIF-данные отсутствуют")
                return {}
            
            result = {}
            
            # Извлечение GPS-координат
            gps_info = {}
            for tag, value in exif_data.items():
                decoded = ExifTags.TAGS.get(tag, tag)
                if decoded == "GPSInfo":
                    gps_info = value
                    break
            
            if gps_info:
                lat = gps_info.get(2)
                lon = gps_info.get(4)
                
                if lat and lon:
                    lat_decimal = lat[0] + lat[1] / 60 + lat[2] / 3600
                    lon_decimal = lon[0] + lon[1] / 60 + lon[2] / 3600
                    
                    lat_ref = gps_info.get(1, "N")
                    lon_ref = gps_info.get(3, "E")
                    
                    if lat_ref == "S":
                        lat_decimal = -lat_decimal
                    if lon_ref == "W":
                        lon_decimal = -lon_decimal
                    
                    result["gps_latitude"] = lat_decimal
                    result["gps_longitude"] = lon_decimal
                    logger.info(f"✅ GPS координаты: lat={lat_decimal}, lon={lon_decimal}")
            
            datetime_original = exif_data.get(36867)
            if datetime_original:
                result["captured_at"] = datetime_original
            
            return result
        except Exception as e:
            logger.warning(f"⚠️ Ошибка извлечения EXIF: {e}")
            return {}
    
    @staticmethod
    def create_thumbnail(image_bytes: bytes, mime_type: str) -> bytes:
        """
        Создание миниатюры изображения (320×240 px).
        
        Args:
            image_bytes: Содержимое оригинального изображения
            mime_type: MIME-тип файла
        
        Returns:
            Содержимое миниатюры в байтах
        """
        try:
            logger.info(f"🔲 Создание миниатюры {THUMBNAIL_SIZE}...")
            image = Image.open(io.BytesIO(image_bytes))
            image.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
            
            if image.mode in ("RGBA", "P"):
                image = image.convert("RGB")
            
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG", quality=OPTIMIZED_QUALITY)
            result = buffer.getvalue()
            logger.info(f"✅ Миниатюра создана: {len(result)} байт")
            return result
        except Exception as e:
            logger.error(f"❌ Ошибка создания миниатюры: {e}", exc_info=True)
            raise Exception(f"Ошибка создания миниатюры: {e}")
    
    @staticmethod
    def optimize_image(image_bytes: bytes, mime_type: str) -> bytes:
        """
        Оптимизация оригинального изображения (макс. 1920×1080, качество 85%).
        
        Args:
            image_bytes: Содержимое оригинального изображения
            mime_type: MIME-тип файла
        
        Returns:
            Содержимое оптимизированного изображения в байтах
        """
        try:
            logger.info(f"🖼️ Оптимизация изображения (макс. {OPTIMIZED_SIZE}, качество {OPTIMIZED_QUALITY}%)...")
            image = Image.open(io.BytesIO(image_bytes))
            
            if image.width > OPTIMIZED_SIZE[0] or image.height > OPTIMIZED_SIZE[1]:
                logger.info(f"📏 Изменение размера с {image.width}x{image.height} до {OPTIMIZED_SIZE}")
                image.thumbnail(OPTIMIZED_SIZE, Image.Resampling.LANCZOS)
            
            if image.mode in ("RGBA", "P"):
                image = image.convert("RGB")
            
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG", quality=OPTIMIZED_QUALITY, optimize=True)
            result = buffer.getvalue()
            logger.info(f"✅ Изображение оптимизировано: {len(result)} байт")
            return result
        except Exception as e:
            logger.error(f"❌ Ошибка оптимизации изображения: {e}", exc_info=True)
            raise Exception(f"Ошибка оптимизации изображения: {e}")
    
    @staticmethod
    def upload_photo(
        violation_id: uuid.UUID,
        file_content: bytes,
        original_filename: str,
        mime_type: str,
        uploaded_by: uuid.UUID,
    ) -> dict:
        """
        Полная обработка и загрузка фотографии.
        
        Args:
            violation_id: ID нарушения
            file_content: Содержимое файла
            original_filename: Исходное имя файла
            mime_type: MIME-тип файла
            uploaded_by: ID пользователя, загрузившего фото
        
        Returns:
            Словарь с путями к файлам и метаданными
        """
        logger.info(f"📸 Начало загрузки фото: {original_filename}, размер: {len(file_content)} байт, violation_id: {violation_id}")
        
        try:
            # Валидация
            PhotoService.validate_photo(len(file_content), mime_type)
            
            # Извлечение EXIF-данных
            exif_data = PhotoService.extract_exif_data(file_content)
            
            # Генерация уникального имени файла
            timestamp = datetime.utcnow().strftime("%Y/%m/%d")
            file_extension = "jpg" if mime_type in ["image/jpeg", "image/jpg"] else "png"
            unique_id = str(uuid.uuid4())
            
            original_key = f"photos/{timestamp}/{violation_id}/{unique_id}_original.{file_extension}"
            thumbnail_key = f"photos/{timestamp}/{violation_id}/{unique_id}_thumb.jpg"
            
            logger.info(f"📁 Пути: original={original_key}, thumbnail={thumbnail_key}")
            
            # Оптимизация оригинала
            optimized_content = PhotoService.optimize_image(file_content, mime_type)
            
            # Создание миниатюры
            thumbnail_content = PhotoService.create_thumbnail(file_content, mime_type)
            
            # Загрузка в MinIO
            logger.info(f"☁️ Загрузка в MinIO (bucket: {minio_client.bucket})...")
            minio_client.upload_file(optimized_content, original_key, "image/jpeg")
            minio_client.upload_file(thumbnail_content, thumbnail_key, "image/jpeg")
            
            result = {
                "file_path": original_key,
                "thumbnail_path": thumbnail_key,
                "original_filename": original_filename,
                "file_size": len(optimized_content),
                "mime_type": "image/jpeg",
                "gps_latitude": exif_data.get("gps_latitude"),
                "gps_longitude": exif_data.get("gps_longitude"),
                "uploaded_by": uploaded_by,
            }
            
            logger.info("🎉 Загрузка завершена успешно")
            return result
            
        except Exception as e:
            logger.error(f"❌ Ошибка загрузки фото: {type(e).__name__}: {e}", exc_info=True)
            raise
    
    @staticmethod
    def delete_photo(file_path: str, thumbnail_path: Optional[str] = None) -> None:
        """
        Удаление фотографии и миниатюры из MinIO.
        
        Args:
            file_path: Путь к оригиналу
            thumbnail_path: Путь к миниатюре (опционально)
        """
        try:
            logger.info(f"🗑️ Удаление фото: {file_path}")
            minio_client.delete_file(file_path)
            if thumbnail_path:
                minio_client.delete_file(thumbnail_path)
            logger.info("✅ Фото успешно удалено")
        except Exception as e:
            logger.error(f"❌ Ошибка удаления фотографии: {e}", exc_info=True)
            raise Exception(f"Ошибка удаления фотографии: {e}")
    
    @staticmethod
    def get_presigned_url(file_path: str, expiration: int = 900) -> str:
        """
        Получение presigned URL для доступа к фотографии.
        
        Args:
            file_path: Путь к файлу в MinIO
            expiration: Время жизни URL в секундах
        
        Returns:
            Presigned URL
        """
        return minio_client.generate_presigned_url(file_path, expiration)


# Глобальный экземпляр сервиса
photo_service = PhotoService()