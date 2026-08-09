"""Rate limiting для защиты от брутфорса."""

from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request
from fastapi.responses import JSONResponse


def get_real_ip(request: Request) -> str:
    """Получаем реальный IP клиента."""
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    return get_remote_address(request)


# In-memory storage (не требует Redis)
limiter = Limiter(key_func=get_real_ip)


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded):
    """Обработчик превышения лимитов."""
    return JSONResponse(
        status_code=429,
        content={
            "detail": f"Превышен лимит запросов. Повторите попытку через {exc.retry_after} секунд.",
        },
    )