"""Репозитории для работы с инспекциями."""

from typing import Optional, List
from uuid import UUID
from datetime import date

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.inspections import Inspection


class BaseRepository:
    """Базовый репозиторий с общими методами."""

    def __init__(self, session: AsyncSession):
        self.session = session


class InspectionRepository(BaseRepository):
    """Репозиторий для работы с инспекциями."""

    async def get_by_id(self, inspection_id: UUID) -> Optional[Inspection]:
        """Получить инспекцию по ID с загруженными стадиями и вложениями."""
        result = await self.session.execute(
            select(Inspection)
            .options(
                joinedload(Inspection.stages),
                joinedload(Inspection.attachments)
            )
            .where(Inspection.id == inspection_id)
        )
        return result.scalar_one_or_none()

    async def get_by_number(self, number: str) -> Optional[Inspection]:
        """Получить инспекцию по номеру."""
        result = await self.session.execute(
            select(Inspection).where(Inspection.number == number)
        )
        return result.scalar_one_or_none()

    async def get_all(
        self,
        skip: int = 0,
        limit: int = 100,
        pe_id: Optional[UUID] = None,
        status: Optional[str] = None,
        inspector_id: Optional[UUID] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
    ) -> List[Inspection]:
        """Получить список инспекций с фильтрацией и пагинацией."""
        query = select(Inspection).options(
            joinedload(Inspection.stages),
            joinedload(Inspection.pe)
        )
        
        filters = []
        if pe_id:
            filters.append(Inspection.pe_id == pe_id)
        if status:
            filters.append(Inspection.status == status)
        if inspector_id:
            filters.append(Inspection.inspector_id == inspector_id)
        if date_from:
            filters.append(Inspection.planned_date >= date_from)
        if date_to:
            filters.append(Inspection.planned_date <= date_to)
        
        if filters:
            query = query.where(and_(*filters))
        
        query = query.order_by(Inspection.created_at.desc()).offset(skip).limit(limit)
        result = await self.session.execute(query)
        return list(result.scalars().unique().all())

    async def create(self, inspection_data: dict) -> Inspection:
        """Создать новую инспекцию."""
        inspection = Inspection(**inspection_data)
        self.session.add(inspection)
        await self.session.flush()
        await self.session.refresh(inspection)
        return inspection

    async def update(self, inspection_id: UUID, update_data: dict) -> Optional[Inspection]:
        """Обновить данные инспекции."""
        inspection = await self.get_by_id(inspection_id)
        if not inspection:
            return None
        
        for field, value in update_data.items():
            setattr(inspection, field, value)
        
        await self.session.flush()
        await self.session.refresh(inspection)
        return inspection

    async def delete(self, inspection_id: UUID) -> bool:
        """Удалить инспекцию."""
        inspection = await self.get_by_id(inspection_id)
        if not inspection:
            return False
        
        await self.session.delete(inspection)
        await self.session.flush()
        return True

    async def get_count(
        self,
        pe_id: Optional[UUID] = None,
        status: Optional[str] = None,
        inspector_id: Optional[UUID] = None,
    ) -> int:
        """Получить количество инспекций с фильтрацией."""
        query = select(Inspection)
        
        filters = []
        if pe_id:
            filters.append(Inspection.pe_id == pe_id)
        if status:
            filters.append(Inspection.status == status)
        if inspector_id:
            filters.append(Inspection.inspector_id == inspector_id)
        
        if filters:
            query = query.where(and_(*filters))
        
        result = await self.session.execute(query)
        return len(result.scalars().all())


class InspectionStageRepository(BaseRepository):
    """Репозиторий для работы со стадиями инспекций (заглушка)."""

    async def get_by_id(self, stage_id: UUID) -> Optional[object]:
        """Получить стадию по ID."""
        raise NotImplementedError("InspectionStage модель не существует")

    async def get_by_inspection(self, inspection_id: UUID) -> List[object]:
        """Получить все стадии инспекции."""
        raise NotImplementedError("InspectionStage модель не существует")

    async def create(self, stage_data: dict) -> object:
        """Создать новую стадию."""
        raise NotImplementedError("InspectionStage модель не существует")

    async def update(self, stage_id: UUID, update_data: dict) -> Optional[object]:
        """Обновить стадию."""
        raise NotImplementedError("InspectionStage модель не существует")

    async def delete(self, stage_id: UUID) -> bool:
        """Удалить стадию."""
        raise NotImplementedError("InspectionStage модель не существует")


class InspectionAttachmentRepository(BaseRepository):
    """Репозиторий для работы с вложениями инспекций (заглушка)."""

    async def get_by_id(self, attachment_id: UUID) -> Optional[object]:
        """Получить вложение по ID."""
        raise NotImplementedError("InspectionAttachment модель не существует")

    async def get_by_inspection(self, inspection_id: UUID) -> List[object]:
        """Получить все вложения инспекции."""
        raise NotImplementedError("InspectionAttachment модель не существует")

    async def create(self, attachment_data: dict) -> object:
        """Создать новое вложение."""
        raise NotImplementedError("InspectionAttachment модель не существует")

    async def delete(self, attachment_id: UUID) -> bool:
        """Удалить вложение."""
        raise NotImplementedError("InspectionAttachment модель не существует")
