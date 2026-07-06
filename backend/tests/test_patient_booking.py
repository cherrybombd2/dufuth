from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user
from app.main import app
from app.models.appointment import Appointment, AppointmentStatus
from app.models.availability_slot import AvailabilitySlot, SlotStatus
from app.repositories.in_memory_store import appointments, availability_slots, reminders
from app.schemas.auth import AuthenticatedUser

client = TestClient(app)


def _patient_user() -> AuthenticatedUser:
    return AuthenticatedUser(
        uid="patient_1",
        email="amina@example.com",
        role="patient",
        token_payload={},
    )


def _admin_user() -> AuthenticatedUser:
    return AuthenticatedUser(
        uid="test-admin",
        email="admin@example.com",
        role="admin",
        token_payload={},
    )


def _future_slot(slot_id: str, *, department: str = "General Medicine") -> AvailabilitySlot:
    return AvailabilitySlot(
        id=slot_id,
        department_id=department,
        department_name=department,
        doctor_id="doctor_1" if department == "General Medicine" else "doctor_2",
        doctor_name="Dr. Tobi Adeyemi" if department == "General Medicine" else "Dr. Chika Okafor",
        start_at=datetime.now(UTC) + timedelta(days=3),
        end_at=datetime.now(UTC) + timedelta(days=3, hours=1),
        status=SlotStatus.AVAILABLE,
    )


def test_patient_can_book_available_slot() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    slot = _future_slot("patient_book_slot")
    availability_slots.append(slot)

    try:
        response = client.post(
            "/api/v1/appointments/book",
            json={
                "department_id": slot.department_id,
                "doctor_id": slot.doctor_id,
                "slot_id": slot.id,
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 201
    assert response.json()["slot_id"] == slot.id
    assert next(item for item in availability_slots if item.id == slot.id).status == SlotStatus.BOOKED
    assert any(item.slot_id == slot.id for item in reminders)


def test_patient_cannot_book_blocked_slot() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    slot = _future_slot("patient_blocked_slot")
    availability_slots.append(slot.model_copy(update={"status": SlotStatus.BLOCKED}))

    try:
        response = client.post(
            "/api/v1/appointments/book",
            json={
                "department_id": slot.department_id,
                "doctor_id": slot.doctor_id,
                "slot_id": slot.id,
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 409


def test_patient_reschedule_stays_in_original_department() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    old_slot = _future_slot("reschedule_old_slot")
    new_slot = _future_slot("reschedule_new_slot")
    appointment = Appointment(
        id="reschedule_appt",
        patient_id="patient_1",
        doctor_id=old_slot.doctor_id,
        department=old_slot.department_name,
        scheduled_for=old_slot.start_at,
        slot_id=old_slot.id,
        status=AppointmentStatus.BOOKED,
    )
    availability_slots.extend([old_slot.model_copy(update={"status": SlotStatus.BOOKED}), new_slot])
    appointments.append(appointment)

    try:
        response = client.post(
            "/api/v1/appointments/reschedule_appt/reschedule",
            json={
                "department_id": new_slot.department_id,
                "doctor_id": new_slot.doctor_id,
                "slot_id": new_slot.id,
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 200
    assert response.json()["slot_id"] == new_slot.id
    assert next(item for item in availability_slots if item.id == old_slot.id).status == SlotStatus.AVAILABLE
    assert next(item for item in availability_slots if item.id == new_slot.id).status == SlotStatus.BOOKED


def test_patient_reschedule_rejects_other_department() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    appointment = Appointment(
        id="cross_department_appt",
        patient_id="patient_1",
        doctor_id="doctor_1",
        department="General Medicine",
        scheduled_for=datetime.now(UTC) + timedelta(days=2),
        status=AppointmentStatus.BOOKED,
    )
    cardiology_slot = _future_slot("cross_department_slot", department="Cardiology")
    appointments.append(appointment)
    availability_slots.append(cardiology_slot)

    try:
        response = client.post(
            "/api/v1/appointments/cross_department_appt/reschedule",
            json={
                "department_id": cardiology_slot.department_id,
                "doctor_id": cardiology_slot.doctor_id,
                "slot_id": cardiology_slot.id,
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 400
    assert "original department" in response.json()["detail"]


def test_signed_in_user_can_load_available_slots() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    slot = _future_slot("visible_slots")
    availability_slots.append(slot)

    try:
        response = client.get(
            "/api/v1/availability-slots/available",
            params={
                "department_id": slot.department_id,
                "doctor_id": slot.doctor_id,
                "selected_date": slot.start_at.date().isoformat(),
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 200
    assert any(item["id"] == slot.id for item in response.json())


def test_patient_can_list_only_own_appointments() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    own_slot = _future_slot("own_visible_slot")
    other_slot = _future_slot("other_hidden_slot")
    appointments.extend(
        [
            Appointment(
                id="own_appt",
                patient_id="patient_1",
                doctor_id=own_slot.doctor_id,
                department=own_slot.department_name,
                scheduled_for=own_slot.start_at,
                slot_id=own_slot.id,
                status=AppointmentStatus.BOOKED,
            ),
            Appointment(
                id="other_appt",
                patient_id="patient_2",
                doctor_id=other_slot.doctor_id,
                department=other_slot.department_name,
                scheduled_for=other_slot.start_at,
                slot_id=other_slot.id,
                status=AppointmentStatus.BOOKED,
            ),
        ]
    )
    availability_slots.extend([own_slot, other_slot])

    try:
        response = client.get("/api/v1/appointments/mine")
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()}
    assert "own_appt" in ids
    assert "other_appt" not in ids


def test_patient_can_cancel_own_appointment_and_release_slot() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    slot = _future_slot("cancel_release_slot")
    availability_slots.append(slot.model_copy(update={"status": SlotStatus.BOOKED}))
    appointments.append(
        Appointment(
            id="cancel_appt",
            patient_id="patient_1",
            doctor_id=slot.doctor_id,
            department=slot.department_name,
            scheduled_for=slot.start_at,
            slot_id=slot.id,
            status=AppointmentStatus.BOOKED,
        )
    )

    try:
        response = client.post("/api/v1/appointments/cancel_appt/cancel")
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert response.status_code == 200
    assert response.json()["status"] == AppointmentStatus.CANCELLED
    assert next(item for item in availability_slots if item.id == slot.id).status == SlotStatus.AVAILABLE


def test_patient_can_list_and_mark_reminder_read() -> None:
    app.dependency_overrides[get_current_user] = _patient_user
    slot = _future_slot("reminder_status_slot")
    availability_slots.append(slot)

    try:
        booking_response = client.post(
            "/api/v1/appointments/book",
            json={
                "department_id": slot.department_id,
                "doctor_id": slot.doctor_id,
                "slot_id": slot.id,
            },
        )
        list_response = client.get("/api/v1/reminders")
        reminder_id = next(
            item["id"]
            for item in list_response.json()
            if item["appointment_id"] == booking_response.json()["id"]
        )
        update_response = client.patch(
            f"/api/v1/reminders/{reminder_id}/status",
            json={"status": "read"},
        )
    finally:
        app.dependency_overrides[get_current_user] = _admin_user

    assert booking_response.status_code == 201
    assert list_response.status_code == 200
    assert update_response.status_code == 200
    assert update_response.json()["status"] == "read"
