from fastapi import HTTPException, status

from app.models.common import UserRole
from app.models.hospital_info import HospitalInfo
from app.repositories.hospital_info_repository import HospitalInfoRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.hospital_info import HospitalInfoResponse, HospitalInfoUpdate


class HospitalInfoService:
    def __init__(self, repository: HospitalInfoRepository) -> None:
        self.repository = repository

    def get_info(self) -> HospitalInfoResponse:
        return HospitalInfoResponse(**self.repository.get().model_dump())

    def update_info(
        self,
        current_user: AuthenticatedUser,
        payload: HospitalInfoUpdate,
    ) -> HospitalInfoResponse:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can update hospital information.",
            )

        info = HospitalInfo(**payload.model_dump())
        return HospitalInfoResponse(**self.repository.update(info).model_dump())
