"""Эндпоинты экспорта карт наблюдений в PDF и DOCX."""
import uuid
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user, CurrentUser
from app.services.export_service import generate_inspection_pdf, generate_inspection_docx

router = APIRouter(prefix="/inspections", tags=["Экспорт"])


@router.get(
    "/{inspection_id}/export/pdf",
    summary="Экспорт карты наблюдения в PDF",
)
def export_inspection_pdf(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Генерация и скачивание PDF-отчёта по карте наблюдения."""
    try:
        pdf_bytes = generate_inspection_pdf(inspection_id, db)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка генерации PDF: {e}")
    
    filename = f"inspection_{inspection_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(pdf_bytes)),
        },
    )


@router.get(
    "/{inspection_id}/export/docx",
    summary="Экспорт карты наблюдения в DOCX",
)
def export_inspection_docx(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    _: CurrentUser,
):
    """Генерация и скачивание DOCX-отчёта по карте наблюдения."""
    try:
        docx_bytes = generate_inspection_docx(inspection_id, db)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка генерации DOCX: {e}")
    
    filename = f"inspection_{inspection_id}.docx"
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(docx_bytes)),
        },
    )