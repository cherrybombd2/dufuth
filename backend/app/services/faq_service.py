from fastapi import HTTPException, status

from app.models.common import UserRole
from app.repositories.faq_repository import FaqRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.faq import (
    FaqItemActiveUpdate,
    FaqItemCreate,
    FaqItemResponse,
    FaqItemUpdate,
)


class FaqService:
    def __init__(self, repository: FaqRepository) -> None:
        self.repository = repository

    def list_patient_items(self) -> list[FaqItemResponse]:
        return [FaqItemResponse(**item.model_dump()) for item in self.repository.list()]

    def list_admin_items(self, current_user: AuthenticatedUser) -> list[FaqItemResponse]:
        self._require_admin(current_user)
        return [
            FaqItemResponse(**item.model_dump())
            for item in self.repository.list(include_inactive=True)
        ]

    def create_item(
        self,
        current_user: AuthenticatedUser,
        payload: FaqItemCreate,
    ) -> FaqItemResponse:
        self._require_admin(current_user)
        item = self.repository.create(payload)
        return FaqItemResponse(**item.model_dump())

    def update_item(
        self,
        item_id: str,
        current_user: AuthenticatedUser,
        payload: FaqItemUpdate,
    ) -> FaqItemResponse:
        self._require_admin(current_user)
        item = self.repository.update(item_id, payload)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="FAQ item not found.",
            )
        return FaqItemResponse(**item.model_dump())

    def update_active_state(
        self,
        item_id: str,
        current_user: AuthenticatedUser,
        payload: FaqItemActiveUpdate,
    ) -> FaqItemResponse:
        self._require_admin(current_user)
        item = self.repository.set_active(item_id, payload.is_active)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="FAQ item not found.",
            )
        return FaqItemResponse(**item.model_dump())

    def _require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can manage FAQ items.",
            )
