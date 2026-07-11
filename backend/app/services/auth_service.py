from fastapi import HTTPException, status

from app.models.common import UserRole
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.user_repository import UserRepository
from app.repositories.device_token_repository import DeviceTokenRepository
from app.schemas.auth import (
    AuthenticatedUser,
    PatientProfileUpsert,
    SessionProfile,
    SessionResponse,
    SessionUser,
)
from app.schemas.device import DeviceTokenRegistration, DeviceTokenResponse
from app.services.device_token_service import DeviceTokenService


class AuthService:
    def __init__(
        self,
        user_repository: UserRepository,
        patient_repository: PatientRepository,
        doctor_repository: DoctorRepository,
        device_token_service: DeviceTokenService | None = None,
    ) -> None:
        self.user_repository = user_repository
        self.patient_repository = patient_repository
        self.doctor_repository = doctor_repository
        self.device_token_service = device_token_service or DeviceTokenService(
            DeviceTokenRepository()
        )

    def get_session(self, current_user: AuthenticatedUser) -> SessionResponse:
        if not current_user.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Authenticated user is missing an email address",
            )

        user = self.user_repository.get_by_uid(current_user.uid)
        if user is None:
            inferred_role = UserRole(current_user.role or UserRole.PATIENT.value)
            user = self.user_repository.create_default_from_auth(
                uid=current_user.uid,
                email=current_user.email,
                role=inferred_role,
            )

        profile = None
        if user.role == UserRole.PATIENT:
            profile = self.patient_repository.get_by_user_id(current_user.uid)
        elif user.role == UserRole.DOCTOR:
            profile = self.doctor_repository.get_by_id(current_user.uid)
        elif user.role == UserRole.ADMIN:
            profile = SessionProfile(
                user_id=user.uid,
                full_name="DUFUTH Admin",
                created_at=user.created_at,
                updated_at=getattr(user, "updated_at", None),
            )

        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "PROFILE_MISSING",
                    "role": user.role.value,
                },
            )

        return SessionResponse(
            user=SessionUser(
                uid=user.uid,
                email=user.email,
                role=user.role.value,
                status=user.status,
                created_at=user.created_at,
                updated_at=getattr(user, "updated_at", None),
            ),
            profile=profile
            if isinstance(profile, SessionProfile)
            else SessionProfile.model_validate(profile.model_dump(mode="python")),
        )

    def upsert_patient_profile(
        self,
        current_user: AuthenticatedUser,
        payload: PatientProfileUpsert,
    ) -> SessionResponse:
        if not current_user.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Authenticated user is missing an email address",
            )

        user = self.user_repository.create_default_from_auth(
            uid=current_user.uid,
            email=current_user.email,
            role=UserRole.PATIENT,
        )
        profile = self.patient_repository.upsert(current_user.uid, payload)

        return SessionResponse(
            user=SessionUser(
                uid=user.uid,
                email=user.email,
                role=user.role.value,
                status=user.status,
                created_at=user.created_at,
                updated_at=getattr(user, "updated_at", None),
            ),
            profile=SessionProfile.model_validate(profile.model_dump(mode="python")),
        )

    def register_device_token(
        self,
        current_user: AuthenticatedUser,
        payload: DeviceTokenRegistration,
    ) -> DeviceTokenResponse:
        return self.device_token_service.register(current_user.uid, payload)
