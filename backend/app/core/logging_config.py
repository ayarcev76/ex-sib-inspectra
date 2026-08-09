"""Конфигурация структурированного логирования."""

import logging
import sys
from typing import Any

try:
    import structlog
    STRUCTLOG_AVAILABLE = True
except ImportError:
    STRUCTLOG_AVAILABLE = False


def setup_logging(log_level: str = "INFO", log_format: str = "json") -> None:
    """
    Настройка логирования для приложения.
    
    Args:
        log_level: Уровень логирования (DEBUG, INFO, WARNING, ERROR)
        log_format: Формат логов ("json" или "console")
    """
    
    if STRUCTLOG_AVAILABLE and log_format == "json":
        _setup_structlog_logging(log_level)
    else:
        _setup_console_logging(log_level)


def _setup_structlog_logging(log_level: str) -> None:
    """Настройка structlog для JSON-логирования."""
    
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.dev.set_exc_info,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, log_level.upper())
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Настройка стандартного логирования для библиотек
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level.upper()),
    )


def _setup_console_logging(log_level: str) -> None:
    """Настройка консольного логирования."""
    
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)]
    )
    
    # Уменьшение шума от некоторых библиотек
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING)


class StructuredLogger:
    """Класс для структурированного логирования с дополнительным контекстом."""
    
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
        
        if STRUCTLOG_AVAILABLE:
            self.struct_logger = structlog.get_logger(name)
        else:
            self.struct_logger = None
    
    def _log(self, level: str, message: str, **kwargs: Any) -> None:
        """Базовый метод логирования."""
        if self.struct_logger and kwargs:
            getattr(self.struct_logger, level)(message, **kwargs)
        else:
            extra_msg = " ".join(f"{k}={v}" for k, v in kwargs.items())
            full_msg = f"{message} {extra_msg}" if extra_msg else message
            getattr(self.logger, level)(full_msg)
    
    def info(self, message: str, **kwargs: Any) -> None:
        """Логирование информационного сообщения."""
        self._log("info", message, **kwargs)
    
    def warning(self, message: str, **kwargs: Any) -> None:
        """Логирование предупреждения."""
        self._log("warning", message, **kwargs)
    
    def error(self, message: str, **kwargs: Any) -> None:
        """Логирование ошибки."""
        self._log("error", message, **kwargs)
    
    def debug(self, message: str, **kwargs: Any) -> None:
        """Логирование отладочной информации."""
        self._log("debug", message, **kwargs)
    
    def exception(self, message: str, **kwargs: Any) -> None:
        """Логирование исключения."""
        if self.struct_logger:
            self.struct_logger.exception(message, **kwargs)
        else:
            self.logger.exception(f"{message} {' '.join(f'{k}={v}' for k, v in kwargs.items())}")


def get_logger(name: str) -> StructuredLogger:
    """Получить логгер с именем."""
    return StructuredLogger(name)
