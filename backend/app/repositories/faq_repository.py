from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.faq import FaqItem
from app.repositories.in_memory_store import faq_items
from app.schemas.faq import FaqItemCreate, FaqItemUpdate


class FaqRepository:
    def list(self, *, include_inactive: bool = False) -> list[FaqItem]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            items = [
                FaqItem.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_faq_items_collection).stream()
            ]
        else:
            items = list(faq_items)

        if not include_inactive:
            items = [item for item in items if item.is_active]

        return sorted(items, key=lambda item: (item.sort_order, item.question.lower()))

    def get(self, item_id: str) -> FaqItem | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = client.collection(settings.firestore_faq_items_collection).document(item_id).get()
            if not snapshot.exists:
                return None
            return FaqItem.model_validate({"id": snapshot.id, **(snapshot.to_dict() or {})})

        return next((item for item in faq_items if item.id == item_id), None)

    def create(self, payload: FaqItemCreate) -> FaqItem:
        now = datetime.now(UTC)
        item = FaqItem(
            id=uuid4().hex,
            question=payload.question,
            answer=payload.answer,
            category=payload.category,
            sort_order=payload.sort_order,
            is_active=payload.is_active,
            created_at=now,
            updated_at=now,
        )
        self._save(item)
        return item

    def update(self, item_id: str, payload: FaqItemUpdate) -> FaqItem | None:
        existing = self.get(item_id)
        if existing is None:
            return None

        item = existing.model_copy(
            update={
                "question": payload.question,
                "answer": payload.answer,
                "category": payload.category,
                "sort_order": payload.sort_order,
                "is_active": payload.is_active,
                "updated_at": datetime.now(UTC),
            }
        )
        self._save(item)
        return item

    def set_active(self, item_id: str, is_active: bool) -> FaqItem | None:
        existing = self.get(item_id)
        if existing is None:
            return None

        item = existing.model_copy(
            update={
                "is_active": is_active,
                "updated_at": datetime.now(UTC),
            }
        )
        self._save(item)
        return item

    def _save(self, item: FaqItem) -> None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_faq_items_collection).document(item.id).set(
                item.model_dump(exclude={"id"}, mode="python")
            )
            return

        existing = self.get(item.id)
        if existing is not None:
            faq_items.remove(existing)
        faq_items.append(item)
