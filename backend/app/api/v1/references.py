"""Эндпоинты CRUD для справочников."""
import uuid
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import IntegrityError  # Добавлено для обработки RESTRICT

from app.api.deps import get_db, get_current_user, CurrentUser
from app.models.references import PE, Department, Contractor, WorkType, ZPBRule
from app.schemas.references import (
    PECreate, PEUpdate, PEResponse,
    DepartmentCreate, DepartmentUpdate, DepartmentResponse,
    ContractorCreate, ContractorUpdate, ContractorResponse,
    WorkTypeCreate, WorkTypeUpdate, WorkTypeResponse,
    ZPBRuleCreate, ZPBRuleUpdate, ZPBRuleResponse,
)

router = APIRouter(prefix="/references", tags=["Справочники"])

# ================= PE =================
@router.get("/pe", response_model=list[PEResponse])
def get_all_pe(db: Annotated[Session, Depends(get_db)]):
    return db.query(PE).filter(PE.is_active == True).all()

@router.post("/pe", response_model=PEResponse, status_code=status.HTTP_201_CREATED)
def create_pe(data: PECreate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    pe = PE(**data.model_dump())
    db.add(pe)
    db.commit()
    db.refresh(pe)
    return pe

@router.put("/pe/{pe_id}", response_model=PEResponse)
def update_pe(pe_id: uuid.UUID, data: PEUpdate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    pe = db.query(PE).filter(PE.id == pe_id).first()
    if not pe:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ПЕ не найдено")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(pe, k, v)
    db.commit()
    db.refresh(pe)
    return pe

@router.delete("/pe/{pe_id}", status_code=status.HTTP_200_OK)
def delete_pe(pe_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    pe = db.query(PE).filter(PE.id == pe_id).first()
    if not pe:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ПЕ не найдено")
    try:
        db.delete(pe)
        db.commit()
        return {"message": "Производственная единица успешно удалена"}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Невозможно удалить ПЕ: с этой производственной единицей связаны существующие подразделения или проверки."
        )


# ================= Department =================
@router.get("/departments", response_model=list[DepartmentResponse])
def get_departments(
    pe_id: uuid.UUID | None = Query(None, description="Фильтр по ПЕ (каскадная фильтрация)"),
    db: Annotated[Session, Depends(get_db)] = None
):
    query = db.query(Department).options(joinedload(Department.pe)).filter(Department.is_active == True)
    if pe_id:
        query = query.filter(Department.pe_id == pe_id)
    return query.all()

@router.post("/departments", response_model=DepartmentResponse, status_code=status.HTTP_201_CREATED)
def create_department(data: DepartmentCreate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    if not db.query(PE).filter(PE.id == data.pe_id).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Указанное ПЕ не существует")
    if db.query(Department).filter(Department.name == data.name, Department.pe_id == data.pe_id).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Подразделение с таким именем уже существует в этом ПЕ")
    dept = Department(**data.model_dump())
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept

@router.delete("/departments/{dept_id}", status_code=status.HTTP_200_OK)
def delete_department(dept_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    dept = db.query(Department).filter(Department.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Подразделение не найдено")
    try:
        db.delete(dept)
        db.commit()
        return {"message": "Подразделение успешно удалено"}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Невозможно удалить подразделение: с ним связаны существующие проверки."
        )


# ================= Contractor =================
@router.get("/contractors", response_model=list[ContractorResponse])
def get_contractors(db: Annotated[Session, Depends(get_db)]):
    return db.query(Contractor).filter(Contractor.is_active == True).all()

@router.post("/contractors", response_model=ContractorResponse, status_code=status.HTTP_201_CREATED)
def create_contractor(data: ContractorCreate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    contractor = Contractor(**data.model_dump())
    db.add(contractor)
    db.commit()
    db.refresh(contractor)
    return contractor

@router.delete("/contractors/{contractor_id}", status_code=status.HTTP_200_OK)
def delete_contractor(contractor_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    contractor = db.query(Contractor).filter(Contractor.id == contractor_id).first()
    if not contractor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Подрядчик не найден")
    try:
        db.delete(contractor)
        db.commit()
        return {"message": "Подрядчик успешно удален"}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Невозможно удалить подрядчика: с ним связаны существующие проверки."
        )


# ================= WorkType =================
@router.get("/work-types", response_model=list[WorkTypeResponse])
def get_work_types(db: Annotated[Session, Depends(get_db)]):
    return db.query(WorkType).filter(WorkType.is_active == True).all()

@router.post("/work-types", response_model=WorkTypeResponse, status_code=status.HTTP_201_CREATED)
def create_work_type(data: WorkTypeCreate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    wt = WorkType(**data.model_dump())
    db.add(wt)
    db.commit()
    db.refresh(wt)
    return wt

@router.delete("/work-types/{wt_id}", status_code=status.HTTP_200_OK)
def delete_work_type(wt_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    wt = db.query(WorkType).filter(WorkType.id == wt_id).first()
    if not wt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Вид работ не найден")
    try:
        db.delete(wt)
        db.commit()
        return {"message": "Вид работ успешно удален"}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Невозможно удалить вид работ: с ним связаны существующие проверки."
        )


# ================= ZPBRule =================
@router.get("/zpb-rules", response_model=list[ZPBRuleResponse])
def get_zpb_rules(db: Annotated[Session, Depends(get_db)]):
    return db.query(ZPBRule).filter(ZPBRule.is_active == True).order_by(ZPBRule.number).all()

@router.post("/zpb-rules", response_model=ZPBRuleResponse, status_code=status.HTTP_201_CREATED)
def create_zpb_rule(data: ZPBRuleCreate, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    rule = ZPBRule(**data.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule

@router.delete("/zpb-rules/{rule_id}", status_code=status.HTTP_200_OK)
def delete_zpb_rule(rule_id: uuid.UUID, db: Annotated[Session, Depends(get_db)], _: CurrentUser):
    rule = db.query(ZPBRule).filter(ZPBRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Правило ЗПБ не найдено")
    try:
        db.delete(rule)
        db.commit()
        return {"message": "Правило ЗПБ успешно удалено"}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Невозможно удалить правило ЗПБ: с ним связаны существующие проверки."
        )