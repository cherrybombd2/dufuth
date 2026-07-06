from app.models.common import UserRole
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthenticatedUser
from app.services.auth_service import AuthService


def test_admin_session_does_not_require_patient_or_doctor_profile() -> None:
    service = AuthService(
        user_repository=UserRepository(),
        patient_repository=PatientRepository(),
        doctor_repository=DoctorRepository(),
    )

    session = service.get_session(
        AuthenticatedUser(
            uid="admin-user",
            email="admin@example.com",
            role=UserRole.ADMIN.value,
            token_payload={"uid": "admin-user", "email": "admin@example.com", "role": "admin"},
        )
    )

    assert session.user.role == UserRole.ADMIN.value
    assert session.profile.user_id == "admin-user"
    assert session.profile.full_name == "DUFUTH Admin"
