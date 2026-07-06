from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_list_patient_faq_items() -> None:
    response = client.get("/api/v1/faq-items")

    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_admin_can_create_and_hide_faq_item() -> None:
    create_response = client.post(
        "/api/v1/faq-items/admin",
        json={
            "question": "What should I bring?",
            "answer": "Bring your appointment details and relevant medical documents.",
            "category": "Appointments",
            "sort_order": 10,
            "is_active": True,
        },
    )

    assert create_response.status_code == 201
    item = create_response.json()
    assert item["question"] == "What should I bring?"
    assert item["is_active"] is True

    hide_response = client.patch(
        f"/api/v1/faq-items/admin/{item['id']}/active",
        json={"is_active": False},
    )

    assert hide_response.status_code == 200
    assert hide_response.json()["is_active"] is False
