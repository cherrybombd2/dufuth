from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_hospital_info_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.hospital_info import HospitalInfoResponse, HospitalInfoUpdate
from app.services.hospital_info_service import HospitalInfoService

router = APIRouter()


@router.get("", response_model=HospitalInfoResponse)
async def get_hospital_info(
    service: HospitalInfoService = Depends(get_hospital_info_service),
) -> HospitalInfoResponse:
    return service.get_info()


@router.put("", response_model=HospitalInfoResponse)
async def update_hospital_info(
    payload: HospitalInfoUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: HospitalInfoService = Depends(get_hospital_info_service),
) -> HospitalInfoResponse:
    return service.update_info(current_user, payload)
