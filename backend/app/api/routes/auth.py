from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_auth_service, get_current_user
from app.schemas.auth import AuthenticatedUser, PatientProfileUpsert, SessionResponse
from app.schemas.device import DeviceTokenRegistration, DeviceTokenResponse
from app.services.auth_service import AuthService

router = APIRouter()


@router.get("/me", response_model=AuthenticatedUser)
async def get_me(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    return current_user


@router.get("/session", response_model=SessionResponse)
async def get_session(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> SessionResponse:
    return service.get_session(current_user)


@router.post("/verify-token", response_model=SessionResponse)
async def verify_token(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> SessionResponse:
    return service.get_session(current_user)


@router.post("/device-token", response_model=DeviceTokenResponse)
async def register_device_token(
    payload: DeviceTokenRegistration,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> DeviceTokenResponse:
    return service.register_device_token(current_user, payload)


@router.post("/patient-profile", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def upsert_patient_profile(
    payload: PatientProfileUpsert,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> SessionResponse:
    return service.upsert_patient_profile(current_user, payload)
