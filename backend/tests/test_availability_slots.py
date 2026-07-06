from datetime import UTC, date, datetime, time, timedelta

from fastapi.testclient import TestClient

from app.main import app
from app.models.availability_slot import AvailabilitySlot, SlotStatus
from app.repositories.in_memory_store import availability_slots

client = TestClient(app)


def test_admin_can_create_and_block_slot() -> None:
    tomorrow = date.today() + timedelta(days=1)
    response = client.post(
        "/api/v1/availability-slots",
        json={
            "department_id": "General Medicine",
            "doctor_id": "doctor_1",
            "date": tomorrow.isoformat(),
            "start_time": "09:00:00",
            "end_time": "10:00:00",
            "status": "available",
        },
    )

    assert response.status_code == 201
    slot = response.json()
    assert slot["status"] == "available"

    block_response = client.patch(
        f"/api/v1/availability-slots/{slot['id']}/status",
        json={"status": "blocked"},
    )

    assert block_response.status_code == 200
    assert block_response.json()["status"] == "blocked"


def test_bulk_create_slots() -> None:
    response = client.post(
        "/api/v1/availability-slots/bulk",
        json={
            "department_id": "Cardiology",
            "doctor_id": "doctor_2",
            "date": (date.today() + timedelta(days=2)).isoformat(),
            "status": "available",
            "ranges": [
                {"start_time": "09:00:00", "end_time": "09:30:00"},
                {"start_time": "09:30:00", "end_time": "10:00:00"},
            ],
        },
    )

    assert response.status_code == 201
    assert len(response.json()) == 2


def test_cleanup_removes_expired_non_booked_slots_only() -> None:
    old_available = AvailabilitySlot(
        id="old_available_slot",
        department_id="General Medicine",
        department_name="General Medicine",
        doctor_id="doctor_1",
        doctor_name="Dr. Tobi Adeyemi",
        start_at=datetime.now(UTC) - timedelta(days=3),
        end_at=datetime.now(UTC) - timedelta(days=3, hours=-1),
        status=SlotStatus.AVAILABLE,
    )
    old_booked = AvailabilitySlot(
        id="old_booked_slot",
        department_id="General Medicine",
        department_name="General Medicine",
        doctor_id="doctor_1",
        doctor_name="Dr. Tobi Adeyemi",
        start_at=datetime.now(UTC) - timedelta(days=3),
        end_at=datetime.now(UTC) - timedelta(days=3, hours=-1),
        status=SlotStatus.BOOKED,
    )
    availability_slots.extend([old_available, old_booked])

    response = client.post("/api/v1/availability-slots/cleanup")

    assert response.status_code == 200
    assert response.json()["deleted"] >= 1
    assert all(slot.id != "old_available_slot" for slot in availability_slots)
    assert any(slot.id == "old_booked_slot" for slot in availability_slots)


def test_booked_slots_are_locked() -> None:
    booked = AvailabilitySlot(
        id="locked_booked_slot",
        department_id="General Medicine",
        department_name="General Medicine",
        doctor_id="doctor_1",
        doctor_name="Dr. Tobi Adeyemi",
        start_at=datetime.now(UTC) + timedelta(days=1),
        end_at=datetime.now(UTC) + timedelta(days=1, hours=1),
        status=SlotStatus.BOOKED,
    )
    availability_slots.append(booked)

    response = client.patch(
        "/api/v1/availability-slots/locked_booked_slot/status",
        json={"status": "blocked"},
    )

    assert response.status_code == 409
