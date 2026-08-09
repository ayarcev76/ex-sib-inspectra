"""Тесты для репозиториев."""

import pytest
from uuid import uuid4
from datetime import date

from app.repositories.users import UserRepository, RoleRepository
from app.models.users import User, Role


class TestUserRepository:
    """Тесты для UserRepository."""

    def test_create_user(self, db_session):
        """Тест создания пользователя."""
        repo = UserRepository(db_session)
        
        user_data = {
            "email": f"test_{uuid4()}@example.com",
            "full_name": "Test User",
            "hashed_password": "hashed_test_password",
            "is_active": True,
        }
        
        user = repo.create(user_data)
        
        assert user.email == user_data["email"]
        assert user.full_name == user_data["full_name"]
        assert user.id is not None

    def test_get_by_id(self, db_session, test_user):
        """Тест получения пользователя по ID."""
        repo = UserRepository(db_session)
        
        user = repo.get_by_id(test_user.id)
        
        assert user is not None
        assert user.id == test_user.id
        assert user.email == test_user.email

    def test_get_by_email(self, db_session, test_user):
        """Тест получения пользователя по email."""
        repo = UserRepository(db_session)
        
        user = repo.get_by_email(test_user.email)
        
        assert user is not None
        assert user.id == test_user.id

    def test_get_by_email_not_found(self, db_session):
        """Тест получения несуществующего пользователя."""
        repo = UserRepository(db_session)
        
        user = repo.get_by_email("nonexistent@example.com")
        
        assert user is None

    def test_update_user(self, db_session, test_user):
        """Тест обновления пользователя."""
        repo = UserRepository(db_session)
        
        updated = repo.update(
            test_user.id,
            {"full_name": "Updated Name"}
        )
        
        assert updated is not None
        assert updated.full_name == "Updated Name"

    def test_update_nonexistent_user(self, db_session):
        """Тест обновления несуществующего пользователя."""
        repo = UserRepository(db_session)
        
        updated = repo.update(uuid4(), {"full_name": "Test"})
        
        assert updated is None

    def test_delete_user(self, db_session, test_user):
        """Тест удаления пользователя."""
        repo = UserRepository(db_session)
        
        result = repo.delete(test_user.id)
        
        assert result is True
        assert repo.get_by_id(test_user.id) is None

    def test_get_all_with_pagination(self, db_session, test_users_batch):
        """Тест получения списка пользователей с пагинацией."""
        repo = UserRepository(db_session)
        
        users = repo.get_all(skip=0, limit=5)
        
        assert len(users) <= 5
        assert all(isinstance(u, User) for u in users)

    def test_get_all_filter_by_active(self, db_session, test_users_batch):
        """Тест фильтрации пользователей по статусу."""
        repo = UserRepository(db_session)
        
        active_users = repo.get_all(is_active=True)
        inactive_users = repo.get_all(is_active=False)
        
        assert len(active_users) + len(inactive_users) == len(test_users_batch)


class TestRoleRepository:
    """Тесты для RoleRepository."""

    def test_create_role(self, db_session):
        """Тест создания роли."""
        repo = RoleRepository(db_session)
        
        role_data = {
            "name": f"test_role_{uuid4()}",
            "description": "Test role",
        }
        
        role = repo.create(role_data)
        
        assert role.name == role_data["name"]
        assert role.id is not None

    def test_get_by_name(self, db_session, test_role):
        """Тест получения роли по имени."""
        repo = RoleRepository(db_session)
        
        role = repo.get_by_name(test_role.name)
        
        assert role is not None
        assert role.id == test_role.id

    def test_get_all_roles(self, db_session, test_roles_batch):
        """Тест получения всех ролей."""
        repo = RoleRepository(db_session)
        
        roles = repo.get_all(skip=0, limit=100)
        
        assert len(roles) == len(test_roles_batch)
