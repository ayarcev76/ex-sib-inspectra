"""Эндпоинты для работы с проверками и нарушениями."""
import uuid
from datetime import datetime, date
from typing import Annotated, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_

from app.api.deps import get_db, get_current_user, CurrentUser
from app.models.inspections import Inspection, ViolationRecord, ViolationPhoto
from app.models.references import PE, Department, Contractor, WorkType, ZPBRule
from app.models.users import User
from app.schemas.inspections import (
    InspectionCreate,
    InspectionUpdate,
    InspectionResponse,
    InspectionDetailResponse,
    ViolationRecordCreate,
    ViolationRecordUpdate,
    ViolationRecordResponse,
    ViolationPhotoResponse,
)

router = APIRouter(prefix="/inspections", tags=["Проверки"])


# ================= Helper functions =================

def generate_inspection_number(db: Session) -> str:
    """Генерация уникального номера проверки вида INSP-YYMMDD-XX."""
    today = datetime.utcnow().strftime("%y%m%d")
    prefix = f"INSP-{today}"
    
    last_inspection = (
        db.query(Inspection)
        .filter(Inspection.inspection_number.like(f"{prefix}%"))
        .order_by(Inspection.inspection_number.desc())
        .first()
    )
    
    if last_inspection:
        last_number = int(last_inspection.inspection_number.split("-")[-1])
        new_number = last_number + 1
    else:
        new_number = 1
    
    return f"{prefix}-{new_number:02d}"


def calculate_top_violations(violations: list) -> None:
    """Авторасчет поля is_top_violation для всех нарушений."""
    for v in violations:
        v.is_top_violation = bool(v.zpb_rule_id and v.is_work_stopped)


def violation_to_response(violation: ViolationRecord, db: Session) -> ViolationRecordResponse:
    """Преобразование модели нарушения в схему ответа с названиями."""
    work_type = None
    zpb_rule = None
    
    if violation.work_type_id:
        work_type = db.query(WorkType).filter(WorkType.id == violation.work_type_id).first()
    if violation.zpb_rule_id:
        zpb_rule = db.query(ZPBRule).filter(ZPBRule.id == violation.zpb_rule_id).first()
    
    return ViolationRecordResponse(
        id=violation.id,
        inspection_id=violation.inspection_id,
        work_type_id=violation.work_type_id,
        work_type_name=work_type.name if work_type else None,
        is_safe=violation.is_safe,
        violation_description=violation.violation_description,
        is_gross_violation=violation.is_gross_violation,
        is_work_stopped=violation.is_work_stopped,
        zpb_rule_id=violation.zpb_rule_id,
        zpb_rule_name=f"{zpb_rule.number}. {zpb_rule.name}" if zpb_rule else None,
        is_top_violation=violation.is_top_violation,
        order=violation.order,
        photos=[
            ViolationPhotoResponse(
                id=p.id,
                violation_id=p.violation_id,
                file_path=p.file_path,
                thumbnail_path=p.thumbnail_path,
                original_filename=p.original_filename,
                file_size=p.file_size,
                mime_type=p.mime_type,
                caption=p.caption,
                gps_latitude=p.gps_latitude,
                gps_longitude=p.gps_longitude,
                uploaded_at=p.uploaded_at,
                uploaded_by=p.uploaded_by,
            )
            for p in violation.photos
        ],
    )


def inspection_to_detail_response(
    inspection: Inspection,
    db: Session,
    pe_name: Optional[str] = None,
    department_name: Optional[str] = None,
    inspector_name: Optional[str] = None,
    contractor_name: Optional[str] = None,
) -> InspectionDetailResponse:
    """Преобразование модели проверки в расширенную схему ответа."""
    return InspectionDetailResponse(
        id=inspection.id,
        inspection_number=inspection.inspection_number,
        date=inspection.date,
        pe_id=inspection.pe_id,
        inspector_id=inspection.inspector_id,
        department_id=inspection.department_id,
        contractor_id=inspection.contractor_id,
        work_location=inspection.work_location,
        plan_id=inspection.plan_id,
        source=inspection.source,
        status=inspection.status,
        created_at=inspection.created_at,
        pe_name=pe_name,
        department_name=department_name,
        inspector_name=inspector_name,
        contractor_name=contractor_name,
        violations=[
            violation_to_response(v, db) for v in sorted(inspection.violations, key=lambda x: x.order)
        ],
    )


# ================= Inspection CRUD =================

@router.post(
    "/",
    response_model=InspectionDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Создание новой проверки",
)
def create_inspection(
    # Зависимости идут ПЕРВЫМИ (без значений по умолчанию)
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    # Данные запроса (Body)
    data: InspectionCreate,
):
    """Создание проверки с вложенными нарушениями."""
    pe = db.query(PE).filter(PE.id == data.pe_id).first()
    if not pe:
        raise HTTPException(status_code=404, detail="Производственная единица не найдена")
    
    dept = db.query(Department).filter(Department.id == data.department_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Подразделение не найдено")
    
    inspector = db.query(User).filter(User.id == data.inspector_id).first()
    if not inspector:
        raise HTTPException(status_code=404, detail="Инспектор не найден")
    
    contractor = None
    if data.contractor_id:
        contractor = db.query(Contractor).filter(Contractor.id == data.contractor_id).first()
        if not contractor:
            raise HTTPException(status_code=404, detail="Подрядчик не найден")
    
    inspection = Inspection(
        inspection_number=generate_inspection_number(db),
        date=data.date,
        pe_id=data.pe_id,
        department_id=data.department_id,
        inspector_id=data.inspector_id,
        contractor_id=data.contractor_id,
        plan_id=data.plan_id,
        work_location=data.work_location,
        source=data.source,
        status=data.status,
    )
    db.add(inspection)
    db.flush()
    
    for v_data in data.violations:
        violation = ViolationRecord(
            inspection_id=inspection.id,
            work_type_id=v_data.work_type_id,
            is_safe=v_data.is_safe,
            violation_description=v_data.violation_description,
            is_gross_violation=v_data.is_gross_violation,
            is_work_stopped=v_data.is_work_stopped,
            zpb_rule_id=v_data.zpb_rule_id,
            order=v_data.order,
        )
        db.add(violation)
    
    db.commit()
    db.refresh(inspection)
    
    calculate_top_violations(inspection.violations)
    db.commit()
    db.refresh(inspection)
    
    return inspection_to_detail_response(
        inspection,
        db,
        pe_name=pe.name if pe else None,
        department_name=dept.name if dept else None,
        inspector_name=inspector.full_name if inspector else None,
        contractor_name=contractor.name if contractor else None,
    )


@router.get(
    "/",
    response_model=dict,
    summary="Список проверок с серверной фильтрацией и пагинацией",
)
def list_inspections(
    # 1. Зависимости (без дефолтов)
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    
    # 2. Параметры с дефолтными значениями (Query)
    pe_id: uuid.UUID | None = Query(None, description="Фильтр по ПЕ"),
    department_id: uuid.UUID | None = Query(None, description="Фильтр по подразделению"),
    date_from: date | None = Query(None, description="Дата начала (YYYY-MM-DD)"),
    date_to: date | None = Query(None, description="Дата окончания (YYYY-MM-DD)"),
    status_filter: str | None = Query(None, alias="status", description="Статус: draft/submitted/approved"),
    skip: int = Query(0, ge=0, description="Пропустить N записей"),
    limit: int = Query(100, ge=1, le=1000, description="Максимум записей"),
):
    """
    Список проверок с серверной фильтрацией и пагинацией.
    Возвращает: {items: [...], total: int, skip: int, limit: int}
    """
    query = db.query(Inspection).options(
        joinedload(Inspection.pe),
        joinedload(Inspection.department),
        joinedload(Inspection.inspector),
    )
    
    filters = []
    if pe_id:
        filters.append(Inspection.pe_id == pe_id)
    if department_id:
        filters.append(Inspection.department_id == department_id)
    if date_from:
        filters.append(Inspection.date >= date_from)
    if date_to:
        filters.append(Inspection.date <= date_to)
    if status_filter:
        filters.append(Inspection.status == status_filter)
    
    if filters:
        query = query.filter(and_(*filters))
    
    # Отдельный запрос для count, чтобы избежать дублирования строк из-за joinedload
    count_query = db.query(Inspection)
    if filters:
        count_query = count_query.filter(and_(*filters))
    total = count_query.count()
    
    inspections = (
        query
        .order_by(Inspection.date.desc(), Inspection.inspection_number.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    
    items = []
    for insp in inspections:
        items.append(InspectionResponse(
            id=insp.id,
            inspection_number=insp.inspection_number,
            date=insp.date,
            pe_id=insp.pe_id,
            department_id=insp.department_id,
            inspector_id=insp.inspector_id,
            contractor_id=insp.contractor_id,
            work_location=insp.work_location,
            plan_id=insp.plan_id,
            source=insp.source,
            status=insp.status,
            created_at=insp.created_at,
        ))
    
    return {
        "items": items,
        "total": total,
        "skip": skip,
        "limit": limit,
    }


@router.get(
    "/{inspection_id}",
    response_model=InspectionDetailResponse,
    summary="Детали проверки",
)
def get_inspection(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
):
    """Получение деталей проверки с нарушениями и фотографиями."""
    inspection = db.query(Inspection).filter(Inspection.id == inspection_id).first()
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    
    pe = db.query(PE).filter(PE.id == inspection.pe_id).first()
    dept = db.query(Department).filter(Department.id == inspection.department_id).first()
    inspector = db.query(User).filter(User.id == inspection.inspector_id).first()
    contractor = db.query(Contractor).filter(Contractor.id == inspection.contractor_id).first() if inspection.contractor_id else None
    
    return inspection_to_detail_response(
        inspection,
        db,
        pe_name=pe.name if pe else None,
        department_name=dept.name if dept else None,
        inspector_name=inspector.full_name if inspector else None,
        contractor_name=contractor.name if contractor else None,
    )


@router.put(
    "/{inspection_id}",
    response_model=InspectionDetailResponse,
    summary="Обновление проверки",
)
def update_inspection(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    data: InspectionUpdate,
):
    """Обновление шапки проверки. Нарушения обновляются отдельно."""
    inspection = db.query(Inspection).filter(Inspection.id == inspection_id).first()
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    
    update_data = data.model_dump(exclude_unset=True)
    update_data.pop("violations", None)
    
    for field, value in update_data.items():
        setattr(inspection, field, value)
    
    db.commit()
    db.refresh(inspection)
    
    pe = db.query(PE).filter(PE.id == inspection.pe_id).first()
    dept = db.query(Department).filter(Department.id == inspection.department_id).first()
    inspector = db.query(User).filter(User.id == inspection.inspector_id).first()
    contractor = db.query(Contractor).filter(Contractor.id == inspection.contractor_id).first() if inspection.contractor_id else None
    
    return inspection_to_detail_response(
        inspection,
        db,
        pe_name=pe.name if pe else None,
        department_name=dept.name if dept else None,
        inspector_name=inspector.full_name if inspector else None,
        contractor_name=contractor.name if contractor else None,
    )


@router.delete(
    "/{inspection_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удаление проверки",
)
def delete_inspection(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
):
    """Удаление проверки со всеми нарушениями и фотографиями."""
    inspection = db.query(Inspection).filter(Inspection.id == inspection_id).first()
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    
    db.delete(inspection)
    db.commit()


# ================= Violation CRUD (отдельные нарушения) =================

@router.post(
    "/{inspection_id}/violations",
    response_model=ViolationRecordResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Добавление нарушения к проверке",
)
def add_violation(
    inspection_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    data: ViolationRecordCreate,
):
    """Добавление нового нарушения к существующей проверке."""
    inspection = db.query(Inspection).filter(Inspection.id == inspection_id).first()
    if not inspection:
        raise HTTPException(status_code=404, detail="Проверка не найдена")
    
    if inspection.status != "draft":
        raise HTTPException(
            status_code=400,
            detail="Нельзя добавить нарушение к проверке, которая уже отправлена или утверждена"
        )
    
    violation = ViolationRecord(
        inspection_id=inspection_id,
        work_type_id=data.work_type_id,
        is_safe=data.is_safe,
        violation_description=data.violation_description,
        is_gross_violation=data.is_gross_violation,
        is_work_stopped=data.is_work_stopped,
        zpb_rule_id=data.zpb_rule_id,
        order=data.order,
    )
    db.add(violation)
    db.commit()
    db.refresh(violation)
    
    calculate_top_violations([violation])
    db.commit()
    db.refresh(violation)
    
    return violation_to_response(violation, db)


@router.put(
    "/violations/{violation_id}",
    response_model=ViolationRecordResponse,
    summary="Обновление нарушения",
)
def update_violation(
    violation_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
    data: ViolationRecordUpdate,
):
    """Обновление существующего нарушения."""
    violation = db.query(ViolationRecord).filter(ViolationRecord.id == violation_id).first()
    if not violation:
        raise HTTPException(status_code=404, detail="Нарушение не найдено")
    
    inspection = db.query(Inspection).filter(Inspection.id == violation.inspection_id).first()
    if inspection and inspection.status != "draft":
        raise HTTPException(
            status_code=400,
            detail="Нельзя редактировать нарушение в проверке, которая уже отправлена или утверждена"
        )
    
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(violation, field, value)
    
    calculate_top_violations([violation])
    db.commit()
    db.refresh(violation)
    
    return violation_to_response(violation, db)


@router.delete(
    "/violations/{violation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удаление нарушения",
)
def delete_violation(
    violation_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: CurrentUser,
):
    """Удаление нарушения со всеми фотографиями."""
    violation = db.query(ViolationRecord).filter(ViolationRecord.id == violation_id).first()
    if not violation:
        raise HTTPException(status_code=404, detail="Нарушение не найдено")
    
    inspection = db.query(Inspection).filter(Inspection.id == violation.inspection_id).first()
    if inspection and inspection.status != "draft":
        raise HTTPException(
            status_code=400,
            detail="Нельзя удалить нарушение в проверке, которая уже отправлена или утверждена"
        )
    
    db.delete(violation)
    db.commit()