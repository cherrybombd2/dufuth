from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_appointment() -> None:
    response = client.post(
        "/api/v1/appointments",
        json={
            "patient_id": "patient_1",
            "doctor_id": "doctor_1",
            "department": "General Medicine",
            "scheduled_for": (datetime.now(UTC) + timedelta(days=2)).isoformat(),
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["patient_id"] == "patient_1"
    assert payload["status"] == "booked"
