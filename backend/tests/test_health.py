from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check() -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert "environment" in payload


def test_health_check_accepts_head() -> None:
    response = client.head("/api/v1/health")

    assert response.status_code == 200
    assert response.content == b""
