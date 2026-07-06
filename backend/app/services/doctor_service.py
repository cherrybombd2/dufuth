from fastapi import HTTPException, status

from app.models.common import UserRole
from app.repositories.appointment_repository import AppointmentRepository
from app.repositories.department_repository import DepartmentRepository
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.appointment import AppointmentResponse
from app.schemas.doctor import (
    DoctorActiveUpdate,
    DoctorAdminResponse,
    DoctorScheduleResponse,
    DoctorSummary,
    DoctorUpsert,
    UserLookupResult,
)


class DoctorService:
    def __init__(
        self,
        doctor_repository: DoctorRepository,
        appointment_repository: AppointmentRepository,
        department_repository: DepartmentRepository | None = None,
        user_repository: UserRepository | None = None,
        patient_repository: PatientRepository | None = None,
    ) -> None:
        self.doctor_repository = doctor_repository
        self.appointment_repository = appointment_repository
        self.department_repository = department_repository
        self.user_repository = user_repository
        self.patient_repository = patient_repository

    def list_doctors(self) -> list[DoctorSummary]:
        return [
            DoctorSummary(**item.model_dump())
            for item in self.doctor_repository.list()
        ]

    def get_schedule(self, doctor_id: str) -> DoctorScheduleResponse:
        doctor = self.doctor_repository.get_by_id(doctor_id)
        if doctor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Doctor not found",
            )

        schedule = self.appointment_repository.list_by_doctor(doctor_id)
        return DoctorScheduleResponse(
            doctor=DoctorSummary(**doctor.model_dump()),
            appointments=[self._appointment_response(item) for item in schedule],
        )

    def get_appointment_detail(
        self,
        current_user: AuthenticatedUser,
        appointment_id: str,
    ) -> AppointmentResponse:
        if current_user.role != UserRole.DOCTOR:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only doctors can view appointment details here.",
            )

        appointment = self.appointment_repository.get(appointment_id)
        if appointment is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Appointment not found.",
            )

        if appointment.doctor_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only view appointments assigned to your profile.",
            )

        return self._appointment_response(appointment)

    def list_admin_doctors(
        self,
        current_user: AuthenticatedUser,
    ) -> list[DoctorAdminResponse]:
        self._require_admin(current_user)
        return [
            DoctorAdminResponse(**item.model_dump())
            for item in self.doctor_repository.list()
        ]

    def create_admin_doctor(
        self,
        current_user: AuthenticatedUser,
        payload: DoctorUpsert,
    ) -> DoctorAdminResponse:
        self._require_admin(current_user)
        self._require_active_department(payload.department_id)
        self._assign_linked_user_role(payload.user_id)
        linked_email = self._linked_email(payload.user_id)
        doctor = self.doctor_repository.upsert(payload, linked_account_email=linked_email)
        return DoctorAdminResponse(**doctor.model_dump())

    def update_admin_doctor(
        self,
        doctor_id: str,
        current_user: AuthenticatedUser,
        payload: DoctorUpsert,
    ) -> DoctorAdminResponse:
        self._require_admin(current_user)
        existing = self.doctor_repository.get_by_id(doctor_id)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Doctor not found.",
            )
        self._require_active_department(payload.department_id)
        self._assign_linked_user_role(payload.user_id)
        linked_email = self._linked_email(payload.user_id)
        doctor = self.doctor_repository.upsert(
            payload.model_copy(update={"user_id": payload.user_id or doctor_id}),
            linked_account_email=linked_email,
        )
        return DoctorAdminResponse(**doctor.model_dump())

    def update_admin_doctor_active_state(
        self,
        doctor_id: str,
        current_user: AuthenticatedUser,
        payload: DoctorActiveUpdate,
    ) -> DoctorAdminResponse:
        self._require_admin(current_user)
        if (
            not payload.is_active
            and not payload.force_deactivate
            and self.appointment_repository.has_future_booked_for_doctor(doctor_id)
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "This doctor has future booked appointments. Deactivate only "
                    "after the hospital team has an alternate plan."
                ),
            )

        doctor = self.doctor_repository.set_active(doctor_id, payload.is_active)
        if doctor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Doctor not found.",
            )
        return DoctorAdminResponse(**doctor.model_dump())

    def search_user_accounts(
        self,
        current_user: AuthenticatedUser,
        query: str,
    ) -> list[UserLookupResult]:
        self._require_admin(current_user)
        if self.user_repository is None:
            return []
        users = self.user_repository.search_by_email(query)
        results: list[UserLookupResult] = []
        for user in users[:10]:
            patient = self.patient_repository.get_by_user_id(user.uid) if self.patient_repository else None
            doctor = self.doctor_repository.get_by_id(user.uid)
            full_name = None
            gender = None
            if patient is not None:
                full_name = patient.full_name
                gender = patient.gender
            elif doctor is not None:
                full_name = doctor.full_name
                gender = doctor.gender
            results.append(
                UserLookupResult(
                    uid=user.uid,
                    email=user.email,
                    role=user.role.value,
                    status=user.status,
                    full_name=full_name,
                    gender=gender,
                )
            )
        return results

    def _linked_email(self, user_id: str | None) -> str | None:
        if user_id is None or self.user_repository is None:
            return None
        user = self.user_repository.get_by_uid(user_id)
        return user.email if user is not None else None

    def _assign_linked_user_role(self, user_id: str | None) -> None:
        if user_id is None or self.user_repository is None:
            return
        user = self.user_repository.get_by_uid(user_id)
        if user is None:
            return
        if user.role == UserRole.DOCTOR:
            return
        self.user_repository.upsert(user.model_copy(update={"role": UserRole.DOCTOR}))

    def _appointment_response(self, appointment) -> AppointmentResponse:
        patient_name = None
        patient_gender = None
        if self.patient_repository is not None:
            patient = self.patient_repository.get_by_user_id(appointment.patient_id)
            if patient is not None:
                patient_name = patient.full_name
                patient_gender = patient.gender
        return AppointmentResponse.model_validate(
            {
                **appointment.model_dump(mode="python"),
                "patient_name": patient_name,
                "patient_gender": patient_gender,
            }
        )

    def _require_active_department(self, department_id: str) -> None:
        if self.department_repository is None:
            return
        department = self.department_repository.get(department_id)
        if department is None or not department.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Doctors can only belong to active departments.",
            )

    def _require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can manage doctors.",
            )
