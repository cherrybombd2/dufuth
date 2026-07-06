from fastapi import HTTPException, status

from app.models.common import UserRole
from app.repositories.department_repository import DepartmentRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.department import (
    DepartmentActiveUpdate,
    DepartmentCreate,
    DepartmentResponse,
    DepartmentUpdate,
)


class DepartmentService:
    def __init__(self, repository: DepartmentRepository) -> None:
        self.repository = repository

    def list_departments(self, current_user: AuthenticatedUser) -> list[DepartmentResponse]:
        self._require_admin(current_user)
        return [DepartmentResponse(**item.model_dump()) for item in self.repository.list()]

    def list_active_departments(self) -> list[DepartmentResponse]:
        return [
            DepartmentResponse(**item.model_dump())
            for item in self.repository.list()
            if item.is_active
        ]

    def create_department(
        self,
        current_user: AuthenticatedUser,
        payload: DepartmentCreate,
    ) -> DepartmentResponse:
        self._require_admin(current_user)
        department = self.repository.create(payload)
        if department is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A department with that name already exists.",
            )
        return DepartmentResponse(**department.model_dump())

    def update_department(
        self,
        name: str,
        current_user: AuthenticatedUser,
        payload: DepartmentUpdate,
    ) -> DepartmentResponse:
        self._require_admin(current_user)
        try:
            department = self.repository.update(name, payload)
        except ValueError as error:
            if str(error) == "duplicate_department":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="A department with that name already exists.",
                ) from error
            raise
        if department is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Department not found.",
            )
        return DepartmentResponse(**department.model_dump())

    def update_active_state(
        self,
        name: str,
        current_user: AuthenticatedUser,
        payload: DepartmentActiveUpdate,
    ) -> DepartmentResponse:
        self._require_admin(current_user)
        department = self.repository.set_active(name, payload.is_active)
        if department is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Department not found.",
            )
        return DepartmentResponse(**department.model_dump())

    def delete_department(self, name: str, current_user: AuthenticatedUser) -> None:
        self._require_admin(current_user)
        if self.repository.has_links(name):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "This department is linked to doctors, slots, or appointment history "
                    "and cannot be deleted."
                ),
            )
        deleted = self.repository.delete(name)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Department not found.",
            )

    def _require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can manage departments.",
            )
