from fastapi import HTTPException, status

from app.models.common import UserRole
from app.models.reminder import ReminderStatus
from app.repositories.reminder_repository import ReminderRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.reminder import ReminderResponse


class ReminderService:
    def __init__(self, repository: ReminderRepository) -> None:
        self.repository = repository

    def list_patient_reminders(
        self,
        current_user: AuthenticatedUser,
    ) -> list[ReminderResponse]:
        self._require_patient(current_user)
        return [
            ReminderResponse.model_validate(item)
            for item in self.repository.list_by_patient(current_user.uid)
        ]

    def update_patient_status(
        self,
        reminder_id: str,
        current_user: AuthenticatedUser,
        reminder_status: ReminderStatus,
    ) -> ReminderResponse:
        self._require_patient(current_user)
        reminder = self.repository.get(reminder_id)
        if reminder is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Reminder not found.",
            )
        if reminder.patient_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only update your own reminders.",
            )
        if reminder.status == ReminderStatus.CANCELLED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cancelled reminders can no longer be updated.",
            )

        updated = self.repository.update_status(reminder_id, reminder_status)
        return ReminderResponse.model_validate(updated)

    def _require_patient(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.PATIENT:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only patients can view reminders.",
            )

    def require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can run reminder dispatch.",
            )
