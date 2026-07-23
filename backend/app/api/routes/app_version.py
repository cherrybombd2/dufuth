from fastapi import APIRouter, Depends

from app.api.dependencies import get_app_version_service
from app.schemas.app_version import AppVersionPolicyResponse
from app.services.app_version_service import AppVersionService

router = APIRouter()


@router.get("", response_model=AppVersionPolicyResponse)
async def get_app_version_policy(
    service: AppVersionService = Depends(get_app_version_service),
) -> AppVersionPolicyResponse:
    return service.get_policy()
