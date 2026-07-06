from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_admin_can_create_and_deactivate_department() -> None:
    create_response = client.post(
        "/api/v1/departments",
        json={
            "name": "Dermatology",
            "description": "Skin care and related consultations.",
            "icon_key": "dermatology",
            "is_active": True,
        },
    )

    assert create_response.status_code == 201
    payload = create_response.json()
    assert payload["name"] == "Dermatology"
    assert payload["is_active"] is True

    deactivate_response = client.patch(
        "/api/v1/departments/Dermatology/active",
        json={"is_active": False},
    )

    assert deactivate_response.status_code == 200
    assert deactivate_response.json()["is_active"] is False


def test_duplicate_department_name_returns_validation_error() -> None:
    response = client.post(
        "/api/v1/departments",
        json={
            "name": "General Medicine",
            "description": "Duplicate department.",
            "icon_key": None,
            "is_active": True,
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "A department with that name already exists."


def test_delete_department_with_links_is_blocked() -> None:
    response = client.delete("/api/v1/departments/General%20Medicine")

    assert response.status_code == 409
    assert "cannot be deleted" in response.json()["detail"]
