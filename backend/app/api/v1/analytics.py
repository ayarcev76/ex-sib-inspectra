"""Эндпоинты для аналитики и дашборда."""
import logging
from datetime import date, timedelta
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, case
from pydantic import BaseModel

from app.api.deps import get_db, get_current_user
from app.models.inspections import Inspection, ViolationRecord
from app.models.references import PE, Department
from app.models.users import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["Аналитика"])


# ==================== Pydantic схемы ====================
class KPIResponse(BaseModel):
    """KPI показатели дашборда."""
    totalInspections: int
    totalObservations: int
    safePercentage: float
    violationPercentage: float
    topViolations: int
    workStops: int


class TrendItem(BaseModel):
    """Элемент тренда для графика."""
    date: str
    inspections: int
    violations: int


class PEViolationItem(BaseModel):
    """ПЕ по нарушениям."""
    name: str
    violations: int
    inspections: int


class WorkTypeViolationItem(BaseModel):
    """Нарушения по видам работ."""
    name: str
    count: int


class ZPBViolationItem(BaseModel):
    """Нарушения ЗПБ."""
    name: str
    count: int


class DistributionItem(BaseModel):
    """Распределение наблюдений."""
    name: str
    value: int
    color: str


class RecentInspectionItem(BaseModel):
    """Последние проверки."""
    key: str
    date: str
    pe_name: str
    department_name: str
    inspector_name: str
    observations: int
    violations: int
    topViolations: int
    status: str


class TopViolationItem(BaseModel):
    """ТОП нарушения."""
    key: str
    date: str
    pe_name: str
    department_name: str
    description: str
    zpb_rule: str
    workStopped: bool


class DashboardResponse(BaseModel):
    """Полный ответ дашборда."""
    kpi: KPIResponse
    trendData: List[TrendItem]
    topPE: List[PEViolationItem]
    workTypeViolations: List[WorkTypeViolationItem]
    zpbViolations: List[ZPBViolationItem]
    distribution: List[DistributionItem]
    recentInspections: List[RecentInspectionItem]
    topViolationsList: List[TopViolationItem]


def get_period_dates(period: str) -> tuple[date, date]:
    """Возвращает даты начала и окончания периода."""
    today = date.today()
    
    if period == "today":
        return today, today
    elif period == "week":
        return today - timedelta(days=today.weekday()), today
    elif period == "month":
        return today.replace(day=1), today
    elif period == "quarter":
        quarter_month = ((today.month - 1) // 3) * 3 + 1
        return today.replace(month=quarter_month, day=1), today
    elif period == "year":
        return today.replace(month=1, day=1), today
    else:
        # По умолчанию месяц
        return today.replace(day=1), today


@router.get("/dashboard", response_model=DashboardResponse, summary="Данные для дашборда")
def get_dashboard_data(
    db: Session = Depends(get_db),
    period: str = Query("month", description="Период: today/week/month/quarter/year"),
    pe_id: Optional[UUID] = Query(None, description="Фильтр по ПЕ"),
    department_id: Optional[UUID] = Query(None, description="Фильтр по подразделению"),
    current_user: User = Depends(get_current_user),
):
    """
    Получение всех данных для дашборда с реальными данными из БД.
    
    Поддерживает фильтрацию по периоду, ПЕ и подразделению.
    """
    date_from, date_to = get_period_dates(period)
    
    # Базовый фильтр
    filters = [
        Inspection.date >= date_from,
        Inspection.date <= date_to,
    ]
    
    if pe_id:
        filters.append(Inspection.pe_id == pe_id)
    if department_id:
        filters.append(Inspection.department_id == department_id)
    
    # Запрос проверок с фильтрами
    inspections_query = db.query(Inspection).filter(and_(*filters))
    inspections = inspections_query.all()
    inspection_ids = [insp.id for insp in inspections]
    
    if not inspection_ids:
        # Нет данных - возвращаем пустые значения
        return DashboardResponse(
            kpi=KPIResponse(0, 0, 0.0, 0.0, 0, 0),
            trend_data=[],
            top_pe=[],
            work_type_violations=[],
            zpb_violations=[],
            distribution=[
                DistributionItem("Безопасные", 0, "#52c41a"),
                DistributionItem("Обычные нарушения", 0, "#faad14"),
                DistributionItem("Грубейшие", 0, "#ff4d4f"),
                DistributionItem("ТОП", 0, "#cf1322"),
            ],
            recent_inspections=[],
            top_violations=[],
        )
    
    # Запрос нарушений для этих проверок
    violations = db.query(ViolationRecord).filter(
        ViolationRecord.inspection_id.in_(inspection_ids)
    ).all()
    
    # ════════════════════════════════════════════════════════
    # KPI РАСЧЕТ
    # ════════════════════════════════════════════════════════
    total_inspections = len(inspections)
    total_observations = len(violations)
    
    safe_count = sum(1 for v in violations if v.is_safe)
    violation_count = sum(1 for v in violations if not v.is_safe)
    
    if total_observations > 0:
        safe_percentage = (safe_count / total_observations) * 100
        violation_percentage = (violation_count / total_observations) * 100
    else:
        safe_percentage = 0.0
        violation_percentage = 0.0
    
    top_violations_count = sum(1 for v in violations if v.is_top_violation)
    work_stops_count = sum(1 for v in violations if v.is_work_stopped)
    
    kpi = KPIResponse(
        total_inspections=total_inspections,
        total_observations=total_observations,
        safe_percentage=safe_percentage,
        violation_percentage=violation_percentage,
        top_violations=top_violations_count,
        work_stops=work_stops_count,
    )
    
    # ════════════════════════════════════════════════════════
    # ТРЕНД ПО ДНЯМ/НЕДЕЛЯМ
    # ════════════════════════════════════════════════════════
    trend_data = []
    
    # Группировка по датам
    from collections import defaultdict
    inspections_by_date = defaultdict(int)
    violations_by_date = defaultdict(int)
    
    for insp in inspections:
        date_key = insp.date.strftime("%d.%m")
        inspections_by_date[date_key] += 1
    
    for v in violations:
        # Находим дату проверки для этого нарушения
        for insp in inspections:
            if insp.id == v.inspection_id:
                date_key = insp.date.strftime("%d.%m")
                violations_by_date[date_key] += 1
                break
    
    # Собираем все уникальные даты и сортируем
    all_dates = sorted(set(inspections_by_date.keys()))
    
    for date_key in all_dates:
        trend_data.append(TrendItem(
            date=date_key,
            inspections=inspections_by_date[date_key],
            violations=violations_by_date[date_key],
        ))
    
    # ════════════════════════════════════════════════════════
    # ТОП ПЕ ПО НАРУШЕНИЯМ
    # ════════════════════════════════════════════════════════
    pe_stats = db.query(
        PE.name,
        func.count(Inspection.id).label("inspections"),
        func.sum(case((ViolationRecord.id != None, 1), else_=0)).label("violations")
    ).join(
        Inspection, PE.id == Inspection.pe_id
    ).join(
        ViolationRecord, Inspection.id == ViolationRecord.inspection_id, isouter=True
    ).filter(
        and_(*filters)
    ).group_by(PE.id, PE.name).order_by(
        func.count(ViolationRecord.id).desc()
    ).limit(5).all()
    
    top_pe = [PEViolationItem(name=row.name, violations=row.violations or 0, inspections=row.inspections) for row in pe_stats]
    
    # ════════════════════════════════════════════════════════
    # НАРУШЕНИЯ ПО ВИДАМ РАБОТ
    # ════════════════════════════════════════════════════════
    from app.models.references import WorkType
    
    work_type_stats = db.query(
        WorkType.name,
        func.count(ViolationRecord.id).label("count")
    ).join(
        ViolationRecord, WorkType.id == ViolationRecord.work_type_id
    ).filter(
        ViolationRecord.inspection_id.in_(inspection_ids)
    ).group_by(WorkType.id, WorkType.name).order_by(
        func.count(ViolationRecord.id).desc()
    ).limit(8).all()
    
    work_type_violations = [WorkTypeViolationItem(name=row.name, count=row.count) for row in work_type_stats]
    
    # ════════════════════════════════════════════════════════
    # НАРУШЕНИЯ ЗПБ
    # ════════════════════════════════════════════════════════
    from app.models.references import ZPBRule
    
    zpb_stats = db.query(
        ZPBRule.number,
        ZPBRule.name,
        func.count(ViolationRecord.id).label("count")
    ).join(
        ViolationRecord, ZPBRule.id == ViolationRecord.zpb_rule_id
    ).filter(
        ViolationRecord.inspection_id.in_(inspection_ids),
        ViolationRecord.zpb_rule_id != None
    ).group_by(ZPBRule.id, ZPBRule.number, ZPBRule.name).order_by(
        func.count(ViolationRecord.id).desc()
    ).limit(7).all()
    
    zpb_violations = [ZPBViolationItem(number=row.number, name=row.name, count=row.count) for row in zpb_stats]
    
    # ════════════════════════════════════════════════════════
    # РАСПРЕДЕЛЕНИЕ НАБЛЮДЕНИЙ
    # ════════════════════════════════════════════════════════
    safe_obs = sum(1 for v in violations if v.is_safe)
    regular_violations = sum(1 for v in violations if not v.is_safe and not v.is_gross_violation and not v.is_top_violation)
    gross_violations = sum(1 for v in violations if v.is_gross_violation and not v.is_top_violation)
    top_obs = sum(1 for v in violations if v.is_top_violation)
    
    distribution = [
        DistributionItem("Безопасные", safe_obs, "#52c41a"),
        DistributionItem("Обычные нарушения", regular_violations, "#faad14"),
        DistributionItem("Грубейшие", gross_violations, "#ff4d4f"),
        DistributionItem("ТОП", top_obs, "#cf1322"),
    ]
    
    # ════════════════════════════════════════════════════════
    # ПОСЛЕДНИЕ ПРОВЕРКИ
    # ════════════════════════════════════════════════════════
    recent_insp = db.query(Inspection).filter(and_(*filters)).order_by(
        Inspection.date.desc(), Inspection.inspection_number.desc()
    ).limit(5).all()
    
    recent_inspections = []
    for idx, insp in enumerate(recent_insp):
        # Считаем нарушения для этой проверки
        insp_violations = [v for v in violations if v.inspection_id == insp.id]
        insp_top = sum(1 for v in insp_violations if v.is_top_violation)
        
        recent_inspections.append(RecentInspectionItem(
            key=str(idx + 1),
            date=insp.date.strftime("%Y-%m-%d"),
            pe_name=insp.pe.name if insp.pe else "",
            department_name=insp.department.name if insp.department else "",
            inspector_name=insp.inspector.full_name if insp.inspector else "",
            observations=len(insp_violations),
            violations=sum(1 for v in insp_violations if not v.is_safe),
            top_violations=insp_top,
            status=insp.status,
        ))
    
    # ════════════════════════════════════════════════════════
    # ТОП НАРУШЕНИЯ
    # ════════════════════════════════════════════════════════
    top_violations_list = []
    
    # Берем нарушения с остановкой работ или ТОП
    critical_violations = [v for v in violations if v.is_work_stopped or v.is_top_violation][:5]
    
    for idx, v in enumerate(critical_violations):
        # Находим проверку для этого нарушения
        insp = next((i for i in inspections if i.id == v.inspection_id), None)
        if insp:
            zpb_text = ""
            if v.zpb_rule:
                zpb_text = f"{v.zpb_rule.number}. {v.zpb_rule.name}"
            
            top_violations_list.append(TopViolationItem(
                key=str(idx + 1),
                date=insp.date.strftime("%Y-%m-%d"),
                pe_name=insp.pe.name if insp.pe else "",
                department_name=insp.department.name if insp.department else "",
                description=v.violation_description or "",
                zpb_rule=zpb_text,
                work_stopped=v.is_work_stopped,
            ))
    
    return DashboardResponse(
        kpi=kpi,
        trend_data=trend_data,
        top_pe=top_pe,
        work_type_violations=work_type_violations,
        zpb_violations=zpb_violations,
        distribution=distribution,
        recent_inspections=recent_inspections,
        top_violations=top_violations_list,
    )
