from fastapi import HTTPException, status

from app.models.common import UserRole
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.user import AdminUserSummary, UserStatusUpdate


class UserService:
    def __init__(
        self,
        user_repository: UserRepository,
        patient_repository: PatientRepository,
        doctor_repository: DoctorRepository,
    ) -> None:
        self.user_repository = user_repository
        self.patient_repository = patient_repository
        self.doctor_repository = doctor_repository

    def list_admin_users(
        self,
        current_user: AuthenticatedUser,
        role: str | None = None,
        status_filter: str | None = None,
        query: str | None = None,
    ) -> list[AdminUserSummary]:
        self._require_admin(current_user)
        normalized_role = self._normalized_role(role)
        normalized_status = self._normalized_status(status_filter)
        normalized_query = (query or "").strip().lower()

        patients = {
            patient.user_id: patient
            for patient in self.patient_repository.list()
        }
        doctors = {
            doctor.user_id: doctor
            for doctor in self.doctor_repository.list()
        }

        results: list[AdminUserSummary] = []
        for user in self.user_repository.list():
            if normalized_role is not None and user.role.value != normalized_role:
                continue
            if normalized_status is not None and user.status != normalized_status:
                continue

            patient = patients.get(user.uid)
            doctor = doctors.get(user.uid)
            full_name = patient.full_name if patient is not None else None
            phone = patient.phone_number if patient is not None else None
            if doctor is not None:
                full_name = doctor.full_name

            summary = AdminUserSummary(
                uid=user.uid,
                email=user.email,
                role=user.role.value,
                status=user.status,
                full_name=full_name,
                phone=phone,
            )
            if normalized_query and not self._matches_query(summary, normalized_query):
                continue
            results.append(summary)

        return sorted(
            results,
            key=lambda item: (
                item.role,
                (item.full_name or item.email or item.uid).lower(),
            ),
        )

    def update_admin_user_status(
        self,
        user_id: str,
        current_user: AuthenticatedUser,
        payload: UserStatusUpdate,
    ) -> AdminUserSummary:
        self._require_admin(current_user)
        new_status = self._normalized_status(payload.status)
        if new_status is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Status must be active or inactive.",
            )
        if user_id == current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot change the admin account currently in use.",
            )

        existing = self.user_repository.get_by_uid(user_id)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User account not found.",
            )
        if existing.role == UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin accounts stay managed outside this screen.",
            )

        updated = self.user_repository.set_status(user_id, new_status)
        if updated is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User account not found.",
            )

        return self._summary_for_user(updated)

    def _normalized_role(self, role: str | None) -> str | None:
        value = (role or "").strip().lower()
        if value in {"", "all"}:
            return None
        if value not in {item.value for item in UserRole}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Role filter must be patient, doctor, or admin.",
            )
        return value

    def _normalized_status(self, status_filter: str | None) -> str | None:
        value = (status_filter or "").strip().lower()
        if value in {"", "all"}:
            return None
        if value not in {"active", "inactive"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Status filter must be active or inactive.",
            )
        return value

    def _matches_query(self, user: AdminUserSummary, query: str) -> bool:
        values = [
            user.full_name or "",
            user.email or "",
            user.phone or "",
            user.uid,
        ]
        return any(query in value.lower() for value in values)

    def _summary_for_user(self, user) -> AdminUserSummary:
        patient = self.patient_repository.get_by_user_id(user.uid)
        doctor = self.doctor_repository.get_by_id(user.uid)
        full_name = patient.full_name if patient is not None else None
        phone = patient.phone_number if patient is not None else None
        if doctor is not None:
            full_name = doctor.full_name
        return AdminUserSummary(
            uid=user.uid,
            email=user.email,
            role=user.role.value,
            status=user.status,
            full_name=full_name,
            phone=phone,
        )

    def _require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can manage users.",
            )
