from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from functools import lru_cache

from app.core.config import get_settings
from app.core.firebase import verify_firebase_token
from app.repositories.device_token_repository import DeviceTokenRepository
from app.repositories.admin_repository import AdminRepository
from app.repositories.appointment_repository import AppointmentRepository
from app.repositories.availability_slot_repository import AvailabilitySlotRepository
from app.repositories.department_repository import DepartmentRepository
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.doctor_alert_repository import DoctorAlertRepository
from app.repositories.faq_repository import FaqRepository
from app.repositories.hospital_info_repository import HospitalInfoRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.reminder_repository import ReminderRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthenticatedUser
from app.services.auth_service import AuthService
from app.services.admin_service import AdminService
from app.services.appointment_service import AppointmentService
from app.services.availability_slot_service import AvailabilitySlotService
from app.services.device_token_service import DeviceTokenService
from app.services.department_service import DepartmentService
from app.services.doctor_service import DoctorService
from app.services.doctor_alert_service import DoctorAlertService
from app.services.faq_service import FaqService
from app.services.hospital_info_service import HospitalInfoService
from app.services.messaging_service import MessagingService
from app.services.patient_service import PatientService
from app.services.reminder_service import ReminderService
from app.services.scheduled_reminder_service import ScheduledReminderService
from app.services.user_service import UserService

bearer_scheme = HTTPBearer(auto_error=False)


@lru_cache
def get_patient_service() -> PatientService:
    return PatientService(repository=PatientRepository())


@lru_cache
def get_doctor_service() -> DoctorService:
    return DoctorService(
        doctor_repository=DoctorRepository(),
        appointment_repository=AppointmentRepository(),
        department_repository=DepartmentRepository(),
        user_repository=UserRepository(),
        patient_repository=PatientRepository(),
    )


@lru_cache
def get_admin_service() -> AdminService:
    return AdminService(
        admin_repository=AdminRepository(),
        doctor_repository=DoctorRepository(),
        appointment_repository=AppointmentRepository(),
    )


@lru_cache
def get_appointment_service() -> AppointmentService:
    return AppointmentService(
        repository=AppointmentRepository(),
        slot_repository=AvailabilitySlotRepository(),
        doctor_repository=DoctorRepository(),
        patient_repository=PatientRepository(),
        reminder_repository=ReminderRepository(),
        doctor_alert_repository=DoctorAlertRepository(),
        messaging_service=get_messaging_service(),
    )


@lru_cache
def get_availability_slot_service() -> AvailabilitySlotService:
    return AvailabilitySlotService(
        repository=AvailabilitySlotRepository(),
        department_repository=DepartmentRepository(),
        doctor_repository=DoctorRepository(),
    )


@lru_cache
def get_department_service() -> DepartmentService:
    return DepartmentService(repository=DepartmentRepository())


@lru_cache
def get_device_token_service() -> DeviceTokenService:
    return DeviceTokenService(repository=DeviceTokenRepository())


@lru_cache
def get_messaging_service() -> MessagingService:
    return MessagingService(repository=DeviceTokenRepository())


@lru_cache
def get_hospital_info_service() -> HospitalInfoService:
    return HospitalInfoService(repository=HospitalInfoRepository())


@lru_cache
def get_faq_service() -> FaqService:
    return FaqService(repository=FaqRepository())


@lru_cache
def get_reminder_service() -> ReminderService:
    return ReminderService(repository=ReminderRepository())


@lru_cache
def get_scheduled_reminder_service() -> ScheduledReminderService:
    return ScheduledReminderService(
        repository=ReminderRepository(),
        messaging_service=get_messaging_service(),
    )


@lru_cache
def get_doctor_alert_service() -> DoctorAlertService:
    return DoctorAlertService(repository=DoctorAlertRepository())


@lru_cache
def get_user_service() -> UserService:
    return UserService(
        user_repository=UserRepository(),
        patient_repository=PatientRepository(),
        doctor_repository=DoctorRepository(),
    )


@lru_cache
def get_auth_service() -> AuthService:
    return AuthService(
        user_repository=UserRepository(),
        patient_repository=PatientRepository(),
        doctor_repository=DoctorRepository(),
        device_token_service=get_device_token_service(),
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    settings = get_settings()

    if not settings.firebase_auth_required:
        return AuthenticatedUser(
            uid="development-user",
            email=None,
            role="admin",
            token_payload={},
        )

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization token",
        )

    payload = verify_firebase_token(credentials.credentials)
    current_user = AuthenticatedUser.from_token_payload(payload)
    user_record = UserRepository().get_by_uid(current_user.uid)
    if user_record is None:
        return current_user
    if user_record.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is inactive. Contact the hospital administrator.",
        )

    return current_user.model_copy(update={"role": user_record.role.value})
