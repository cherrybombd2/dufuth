from fastapi import HTTPException, status

from app.models.common import UserRole
from app.models.doctor_alert import DoctorAlertStatus
from app.repositories.doctor_alert_repository import DoctorAlertRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.doctor_alert import DoctorAlertResponse


class DoctorAlertService:
    def __init__(self, repository: DoctorAlertRepository) -> None:
        self.repository = repository

    def list_my_alerts(
        self,
        current_user: AuthenticatedUser,
    ) -> list[DoctorAlertResponse]:
        self._require_doctor(current_user)
        return [
            DoctorAlertResponse.model_validate(item)
            for item in self.repository.list_by_doctor(current_user.uid)
        ]

    def update_my_alert_status(
        self,
        alert_id: str,
        current_user: AuthenticatedUser,
        alert_status: DoctorAlertStatus,
    ) -> DoctorAlertResponse:
        self._require_doctor(current_user)
        alert = self.repository.get(alert_id)
        if alert is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Doctor alert not found.",
            )
        if alert.doctor_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only update alerts linked to your profile.",
            )
        updated = self.repository.update_status(alert_id, alert_status)
        return DoctorAlertResponse.model_validate(updated)

    def _require_doctor(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.DOCTOR:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only doctors can view doctor alerts.",
            )
