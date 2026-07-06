import logging
from pathlib import Path

import firebase_admin
from fastapi import HTTPException, status
from firebase_admin import auth, credentials, firestore, messaging

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def initialize_firebase() -> None:
    settings = get_settings()

    if firebase_admin._apps:
        return

    if settings.firebase_credentials_path:
        cred = credentials.Certificate(Path(settings.firebase_credentials_path))
        firebase_admin.initialize_app(
            cred,
            {"projectId": settings.firebase_project_id or None},
        )
        return

    if settings.firebase_project_id:
        firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})


def get_firestore_client() -> firestore.Client | None:
    settings = get_settings()
    if not settings.use_firestore:
        return None

    initialize_firebase()
    if not firebase_admin._apps:
        return None

    return firestore.client()


def verify_firebase_token(id_token: str) -> dict:
    initialize_firebase()
    settings = get_settings()

    if not firebase_admin._apps:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase Auth is not configured on the backend",
        )

    try:
        return auth.verify_id_token(id_token, clock_skew_seconds=60)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Firebase token verification failed: error_type=%s, "
            "message=%s, configured_project_id=%s, token_length=%s",
            exc.__class__.__name__,
            exc,
            settings.firebase_project_id or "not-set",
            len(id_token),
        )
        detail = "Invalid Firebase ID token"
        if settings.debug:
            detail = f"Invalid Firebase ID token: {exc}"
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        ) from exc


def send_fcm_message(
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> str:
    settings = get_settings()
    if not settings.fcm_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="FCM is not enabled on the backend",
        )

    initialize_firebase()
    if not firebase_admin._apps:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase Admin is not configured on the backend",
        )

    message = messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body),
        data=data or None,
    )
    return messaging.send(message)


def send_fcm_multicast(
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> messaging.BatchResponse:
    settings = get_settings()
    if not settings.fcm_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="FCM is not enabled on the backend",
        )

    initialize_firebase()
    if not firebase_admin._apps:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase Admin is not configured on the backend",
        )

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data=data or None,
    )
    return messaging.send_each_for_multicast(message)
