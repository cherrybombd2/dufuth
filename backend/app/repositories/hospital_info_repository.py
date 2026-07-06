from datetime import UTC, datetime

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.hospital_info import HospitalInfo
from app.repositories.in_memory_store import hospital_info


class HospitalInfoRepository:
    _document_id = "hospital_info"

    def get(self) -> HospitalInfo:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_app_content_collection)
                .document(self._document_id)
                .get()
            )
            if snapshot.exists:
                return HospitalInfo(**(snapshot.to_dict() or {}))

        return HospitalInfo(**hospital_info)

    def update(self, info: HospitalInfo) -> HospitalInfo:
        info.updated_at = datetime.now(UTC)
        settings = get_settings()
        client = get_firestore_client()
        payload = info.model_dump()

        if client is not None:
            (
                client.collection(settings.firestore_app_content_collection)
                .document(self._document_id)
                .set(payload, merge=True)
            )
            return info

        hospital_info.clear()
        hospital_info.update(
            {
                key: value
                for key, value in payload.items()
                if key != "updated_at" and value is not None
            }
        )
        return info
