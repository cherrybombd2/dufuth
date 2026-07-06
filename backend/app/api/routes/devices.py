from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_device_token_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.device import DeviceTokenRegistration, DeviceTokenResponse
from app.services.device_token_service import DeviceTokenService

router = APIRouter()


@router.post("/register", response_model=DeviceTokenResponse, status_code=status.HTTP_201_CREATED)
async def register_device_token(
    payload: DeviceTokenRegistration,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DeviceTokenService = Depends(get_device_token_service),
) -> DeviceTokenResponse:
    return service.register(current_user.uid, payload)
