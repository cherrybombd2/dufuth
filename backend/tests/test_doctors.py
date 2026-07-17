from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.main import app
from app.models.appointment import Appointment, AppointmentStatus
from app.models.common import UserRole
from app.models.user import UserAccount
from app.repositories.in_memory_store import appointments
from app.repositories.user_repository import UserRepository

client = TestClient(app)


def test_admin_can_create_doctor() -> None:
    response = client.post(
        "/api/v1/doctors/admin",
        json={
            "full_name": "Dr. Ada Nwosu",
            "department_id": "Cardiology",
            "specialization": "Cardiology",
            "gender": "Female",
            "bio": "Consultant cardiologist.",
            "consultation_mode": "In person",
            "years_of_experience": 8,
            "is_active": True,
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["full_name"] == "Dr. Ada Nwosu"
    assert payload["department_id"] == "Cardiology"
    assert payload["is_active"] is True


def test_deactivate_doctor_with_future_appointment_requires_confirmation() -> None:
    response = client.patch(
        "/api/v1/doctors/admin/doctor_1/active",
        json={"is_active": False},
    )

    assert response.status_code == 409
    assert "future booked appointments" in response.json()["detail"]


def test_admin_can_force_deactivate_doctor_after_confirmation() -> None:
    response = client.patch(
        "/api/v1/doctors/admin/doctor_1/active",
        json={"is_active": False, "force_deactivate": True},
    )

    assert response.status_code == 200
    assert response.json()["is_active"] is False


def test_admin_can_search_existing_app_accounts_by_email() -> None:
    UserRepository().upsert(
        UserAccount(
            uid="patient_1",
            email="amina@example.com",
            role=UserRole.PATIENT,
        )
    )

    response = client.get("/api/v1/doctors/admin/user-search?query=amina")

    assert response.status_code == 200
    payload = response.json()
    assert payload[0]["email"] == "amina@example.com"
    assert payload[0]["full_name"] == "Amina Yusuf"


def test_doctor_schedule_can_be_filtered_by_selected_date() -> None:
    target_date_time = datetime.now(UTC) + timedelta(days=5)
    other_date_time = target_date_time + timedelta(days=1)
    appointments.extend(
        [
            Appointment(
                id="doctor_schedule_target_date",
                patient_id="patient_1",
                doctor_id="doctor_1",
                department="General Medicine",
                scheduled_for=target_date_time,
                status=AppointmentStatus.BOOKED,
            ),
            Appointment(
                id="doctor_schedule_other_date",
                patient_id="patient_1",
                doctor_id="doctor_1",
                department="General Medicine",
                scheduled_for=other_date_time,
                status=AppointmentStatus.BOOKED,
            ),
        ]
    )

    response = client.get(
        "/api/v1/doctors/doctor_1/schedule",
        params={"selected_date": target_date_time.date().isoformat()},
    )

    assert response.status_code == 200
    appointment_ids = {item["id"] for item in response.json()["appointments"]}
    assert "doctor_schedule_target_date" in appointment_ids
    assert "doctor_schedule_other_date" not in appointment_ids
