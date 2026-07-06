from __future__ import annotations

import hashlib
from datetime import UTC, datetime

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.device_token import DeviceTokenRecord
from app.schemas.device import DeviceTokenRegistration

_device_tokens: dict[str, DeviceTokenRecord] = {}


class DeviceTokenRepository:
    def register(self, user_uid: str, payload: DeviceTokenRegistration) -> DeviceTokenRecord:
        settings = get_settings()
        existing = self.get_by_token(payload.token)
        now = datetime.now(UTC)
        record = DeviceTokenRecord(
            id=self._document_id_for_token(payload.token),
            token=payload.token,
            user_uid=user_uid,
            platform=payload.platform,
            is_active=True,
            last_seen_at=now,
            updated_at=now,
            created_at=existing.created_at if existing is not None else now,
        )

        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_device_tokens_collection).document(record.id).set(
                record.model_dump(exclude={"id"}, mode="python")
            )
            return record

        _device_tokens[record.id] = record
        return record

    def list_active_for_user(self, user_uid: str) -> list[DeviceTokenRecord]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_device_tokens_collection)
                .where("user_uid", "==", user_uid)
                .where("is_active", "==", True)
                .stream()
            )
            return [
                DeviceTokenRecord.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]

        return [
            item
            for item in _device_tokens.values()
            if item.user_uid == user_uid and item.is_active
        ]

    def deactivate_token(self, token: str) -> DeviceTokenRecord | None:
        existing = self.get_by_token(token)
        if existing is None:
            return None

        updated = existing.model_copy(
            update={
                "is_active": False,
                "updated_at": datetime.now(UTC),
            }
        )
        return self._save(updated)

    def get_by_token(self, token: str) -> DeviceTokenRecord | None:
        document_id = self._document_id_for_token(token)
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_device_tokens_collection)
                .document(document_id)
                .get()
            )
            if not snapshot.exists:
                return None
            return DeviceTokenRecord.model_validate(
                {"id": snapshot.id, **(snapshot.to_dict() or {})}
            )

        return _device_tokens.get(document_id)

    def _save(self, record: DeviceTokenRecord) -> DeviceTokenRecord:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_device_tokens_collection).document(record.id).set(
                record.model_dump(exclude={"id"}, mode="python")
            )
            return record

        _device_tokens[record.id] = record
        return record

    def _document_id_for_token(self, token: str) -> str:
        digest = hashlib.sha256(token.encode("utf-8")).hexdigest()
        return f"device_{digest}"
