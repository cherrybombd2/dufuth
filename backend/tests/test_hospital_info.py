from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_get_hospital_info() -> None:
    response = client.get("/api/v1/hospital-info")

    assert response.status_code == 200
    payload = response.json()
    assert payload["hospital_name"]


def test_update_hospital_info() -> None:
    response = client.put(
        "/api/v1/hospital-info",
        json={
            "hospital_name": "DUFUTH SmartCare",
            "tagline": "Excellence in Health Care",
            "address": "David Umahi Federal University Teaching Hospital",
            "phone": "08000000000",
            "email": "info@dufuth.example",
            "working_hours": "Monday - Friday, 8:00 AM - 4:00 PM",
            "visiting_hours": "Not provided yet",
            "website": "https://dufuth.example",
            "about": "Hospital background and patient-facing information.",
            "patient_notice": "Please arrive early for your appointment.",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["hospital_name"] == "DUFUTH SmartCare"
    assert payload["phone"] == "08000000000"
