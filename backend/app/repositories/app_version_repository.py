from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.app_version import AppVersionPolicy


class AppVersionRepository:
    _document_id = "app_version"

    def get_policy(self) -> AppVersionPolicy:
        settings = get_settings()
        policy = AppVersionPolicy(
            minimum_required_version=settings.app_minimum_required_version,
            latest_version=settings.app_latest_version,
            force_update=settings.app_force_update,
            download_url=settings.app_update_download_url,
            message=settings.app_update_message,
        )

        client = get_firestore_client()
        if client is None:
            return policy

        snapshot = (
            client.collection(settings.firestore_app_content_collection)
            .document(self._document_id)
            .get()
        )
        if not snapshot.exists:
            return policy

        data = snapshot.to_dict() or {}
        return policy.model_copy(
            update={
                "minimum_required_version": _string_value(
                    data,
                    "minimum_required_version",
                    "minimumRequiredVersion",
                    fallback=policy.minimum_required_version,
                ),
                "latest_version": _string_value(
                    data,
                    "latest_version",
                    "latestVersion",
                    fallback=policy.latest_version,
                ),
                "force_update": _bool_value(
                    data,
                    "force_update",
                    "forceUpdate",
                    fallback=policy.force_update,
                ),
                "download_url": _string_value(
                    data,
                    "download_url",
                    "downloadUrl",
                    fallback=policy.download_url,
                ),
                "message": _string_value(
                    data,
                    "message",
                    fallback=policy.message,
                ),
            }
        )


def _string_value(
    data: dict[str, object],
    *keys: str,
    fallback: str,
) -> str:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return fallback


def _bool_value(
    data: dict[str, object],
    *keys: str,
    fallback: bool,
) -> bool:
    for key in keys:
        value = data.get(key)
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"true", "1", "yes", "on"}:
                return True
            if normalized in {"false", "0", "no", "off"}:
                return False
    return fallback
