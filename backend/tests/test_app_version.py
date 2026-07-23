from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_get_app_version_policy() -> None:
    response = client.get("/api/v1/app-version")

    assert response.status_code == 200
    payload = response.json()
    assert payload["minimumRequiredVersion"] == "1.0.0"
    assert payload["latestVersion"] == "1.0.0"
    assert payload["forceUpdate"] is False
    assert payload["downloadUrl"].startswith("https://")
    assert payload["message"]
