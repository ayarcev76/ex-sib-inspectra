"""Репозитории для работы с инспекциями."""

from typing import Optional, List
from uuid import UUID
from datetime import date

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.inspections import Inspection, InspectionStage, InspectionAttachment


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
    """Репозиторий для работы со стадиями инспекций."""

    async def get_by_id(self, stage_id: UUID) -> Optional[InspectionStage]:
        """Получить стадию по ID."""
        return await self.session.get(InspectionStage, stage_id)

    async def get_by_inspection(self, inspection_id: UUID) -> List[InspectionStage]:
        """Получить все стадии инспекции."""
        result = await self.session.execute(
            select(InspectionStage)
            .where(InspectionStage.inspection_id == inspection_id)
            .order_by(InspectionStage.stage_order)
        )
        return list(result.scalars().all())

    async def create(self, stage_data: dict) -> InspectionStage:
        """Создать новую стадию."""
        stage = InspectionStage(**stage_data)
        self.session.add(stage)
        await self.session.flush()
        await self.session.refresh(stage)
        return stage

    async def update(self, stage_id: UUID, update_data: dict) -> Optional[InspectionStage]:
        """Обновить стадию."""
        stage = await self.get_by_id(stage_id)
        if not stage:
            return None
        
        for field, value in update_data.items():
            setattr(stage, field, value)
        
        await self.session.flush()
        await self.session.refresh(stage)
        return stage

    async def delete(self, stage_id: UUID) -> bool:
        """Удалить стадию."""
        stage = await self.get_by_id(stage_id)
        if not stage:
            return False
        
        await self.session.delete(stage)
        await self.session.flush()
        return True


class InspectionAttachmentRepository(BaseRepository):
    """Репозиторий для работы с вложениями инспекций."""

    async def get_by_id(self, attachment_id: UUID) -> Optional[InspectionAttachment]:
        """Получить вложение по ID."""
        return await self.session.get(InspectionAttachment, attachment_id)

    async def get_by_inspection(self, inspection_id: UUID) -> List[InspectionAttachment]:
        """Получить все вложения инспекции."""
        result = await self.session.execute(
            select(InspectionAttachment)
            .where(InspectionAttachment.inspection_id == inspection_id)
        )
        return list(result.scalars().all())

    async def create(self, attachment_data: dict) -> InspectionAttachment:
        """Создать новое вложение."""
        attachment = InspectionAttachment(**attachment_data)
        self.session.add(attachment)
        await self.session.flush()
        await self.session.refresh(attachment)
        return attachment

    async def delete(self, attachment_id: UUID) -> bool:
        """Удалить вложение."""
        attachment = await self.get_by_id(attachment_id)
        if not attachment:
            return False
        
        await self.session.delete(attachment)
        await self.session.flush()
        return True
