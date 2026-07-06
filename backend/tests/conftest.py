import os

os.environ["FIREBASE_AUTH_REQUIRED"] = "false"
os.environ["FIREBASE_CREDENTIALS_PATH"] = ""
os.environ["FIREBASE_PROJECT_ID"] = ""
os.environ["FCM_ENABLED"] = "false"
os.environ["USE_FIRESTORE"] = "false"

from app.api.dependencies import get_current_user
from app.main import app
from app.schemas.auth import AuthenticatedUser


def _admin_user() -> AuthenticatedUser:
    return AuthenticatedUser(
        uid="test-admin",
        email="admin@example.com",
        role="admin",
        token_payload={},
    )


app.dependency_overrides[get_current_user] = _admin_user
