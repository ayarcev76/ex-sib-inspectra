"""Репозитории для работы с данными пользователей и ролей."""

from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.users import User, Role


class BaseRepository:
    """Базовый репозиторий с общими методами."""

    def __init__(self, session: AsyncSession):
        self.session = session


class UserRepository(BaseRepository):
    """Репозиторий для работы с пользователями."""

    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        """Получить пользователя по ID."""
        result = await self.session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> Optional[User]:
        """Получить пользователя по email."""
        result = await self.session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

    async def get_all(
        self, 
        skip: int = 0, 
        limit: int = 100,
        is_active: Optional[bool] = None
    ) -> list[User]:
        """Получить список пользователей с пагинацией."""
        query = select(User)
        
        if is_active is not None:
            query = query.where(User.is_active == is_active)
        
        query = query.offset(skip).limit(limit)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def create(self, user_data: dict) -> User:
        """Создать нового пользователя."""
        user = User(**user_data)
        self.session.add(user)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def update(self, user_id: UUID, update_data: dict) -> Optional[User]:
        """Обновить данные пользователя."""
        user = await self.get_by_id(user_id)
        if not user:
            return None
        
        for field, value in update_data.items():
            setattr(user, field, value)
        
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def delete(self, user_id: UUID) -> bool:
        """Удалить пользователя."""
        user = await self.get_by_id(user_id)
        if not user:
            return False
        
        await self.session.delete(user)
        await self.session.flush()
        return True

    async def add_role(self, user_id: UUID, role_id: UUID) -> Optional[User]:
        """Добавить роль пользователю."""
        user = await self.get_by_id(user_id)
        if not user:
            return None
        
        role = await self.session.get(Role, role_id)
        if not role:
            return None
        
        if role not in user.roles:
            user.roles.append(role)
            await self.session.flush()
            await self.session.refresh(user)
        
        return user

    async def remove_role(self, user_id: UUID, role_id: UUID) -> Optional[User]:
        """Удалить роль у пользователя."""
        user = await self.get_by_id(user_id)
        if not user:
            return None
        
        role = await self.session.get(Role, role_id)
        if role and role in user.roles:
            user.roles.remove(role)
            await self.session.flush()
            await self.session.refresh(user)
        
        return user


class RoleRepository(BaseRepository):
    """Репозиторий для работы с ролями."""

    async def get_by_id(self, role_id: UUID) -> Optional[Role]:
        """Получить роль по ID."""
        return await self.session.get(Role, role_id)

    async def get_by_name(self, name: str) -> Optional[Role]:
        """Получить роль по имени."""
        result = await self.session.execute(
            select(Role).where(Role.name == name)
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 100) -> list[Role]:
        """Получить список всех ролей с пагинацией."""
        query = select(Role).offset(skip).limit(limit)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def create(self, role_data: dict) -> Role:
        """Создать новую роль."""
        role = Role(**role_data)
        self.session.add(role)
        await self.session.flush()
        await self.session.refresh(role)
        return role

    async def delete(self, role_id: UUID) -> bool:
        """Удалить роль."""
        role = await self.get_by_id(role_id)
        if not role:
            return False
        
        await self.session.delete(role)
        await self.session.flush()
        return True
