from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.availability_slot import AvailabilitySlot, SlotStatus
from app.repositories.in_memory_store import availability_slots


class AvailabilitySlotRepository:
    def list(
        self,
        *,
        department_id: str | None = None,
        doctor_id: str | None = None,
        selected_date: str | None = None,
    ) -> list[AvailabilitySlot]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = client.collection(settings.firestore_availability_slots_collection)
            if department_id:
                query = query.where("department_id", "==", department_id)
            if doctor_id:
                query = query.where("doctor_id", "==", doctor_id)
            items = [
                AvailabilitySlot.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query.stream()
            ]
        else:
            items = list(availability_slots)
            if department_id:
                items = [item for item in items if item.department_id == department_id]
            if doctor_id:
                items = [item for item in items if item.doctor_id == doctor_id]

        if selected_date:
            items = [
                item for item in items if item.start_at.date().isoformat() == selected_date
            ]
        return sorted(items, key=lambda item: item.start_at)

    def list_available(
        self,
        *,
        department_id: str,
        doctor_id: str,
        selected_date: str,
    ) -> list[AvailabilitySlot]:
        now = datetime.now(UTC)
        return [
            item
            for item in self.list(
                department_id=department_id,
                doctor_id=doctor_id,
                selected_date=selected_date,
            )
            if item.status == SlotStatus.AVAILABLE and item.start_at > now
        ]

    def get(self, slot_id: str) -> AvailabilitySlot | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_availability_slots_collection)
                .document(slot_id)
                .get()
            )
            if not snapshot.exists:
                return None
            return AvailabilitySlot.model_validate({"id": snapshot.id, **(snapshot.to_dict() or {})})
        return next((item for item in availability_slots if item.id == slot_id), None)

    def get_many_by_ids(self, slot_ids: set[str]) -> dict[str, AvailabilitySlot]:
        if not slot_ids:
            return {}

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            collection = client.collection(settings.firestore_availability_slots_collection)
            snapshots = client.get_all([collection.document(slot_id) for slot_id in slot_ids])
            return {
                snapshot.id: AvailabilitySlot.model_validate(
                    {"id": snapshot.id, **(snapshot.to_dict() or {})}
                )
                for snapshot in snapshots
                if snapshot.exists
            }

        return {slot.id: slot for slot in availability_slots if slot.id in slot_ids}

    def save(self, slot: AvailabilitySlot) -> AvailabilitySlot:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_availability_slots_collection).document(slot.id).set(
                slot.model_dump(exclude={"id"}, mode="python")
            )
            return slot

        existing = self.get(slot.id)
        if existing is not None:
            availability_slots.remove(existing)
        availability_slots.append(slot)
        return slot

    def set_status(self, slot_id: str, status: SlotStatus) -> AvailabilitySlot | None:
        slot = self.get(slot_id)
        if slot is None:
            return None
        return self.save(slot.model_copy(update={"status": status}))

    def create(
        self,
        *,
        department_id: str,
        department_name: str,
        doctor_id: str,
        doctor_name: str,
        start_at: datetime,
        end_at: datetime,
        status: SlotStatus,
        ) -> AvailabilitySlot:
        return self.save(
            self.build(
                department_id=department_id,
                department_name=department_name,
                doctor_id=doctor_id,
                doctor_name=doctor_name,
                start_at=start_at,
                end_at=end_at,
                status=status,
            )
        )

    def build(
        self,
        *,
        department_id: str,
        department_name: str,
        doctor_id: str,
        doctor_name: str,
        start_at: datetime,
        end_at: datetime,
        status: SlotStatus,
    ) -> AvailabilitySlot:
        return AvailabilitySlot(
            id=f"slot_{uuid4().hex[:10]}",
            department_id=department_id,
            department_name=department_name,
            doctor_id=doctor_id,
            doctor_name=doctor_name,
            start_at=start_at,
            end_at=end_at,
            status=status,
        )

    def save_many(self, slots: list[AvailabilitySlot]) -> list[AvailabilitySlot]:
        if not slots:
            return []

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            collection = client.collection(settings.firestore_availability_slots_collection)
            batch = client.batch()
            for slot in slots:
                batch.set(
                    collection.document(slot.id),
                    slot.model_dump(exclude={"id"}, mode="python"),
                )
            batch.commit()
            return slots

        for slot in slots:
            existing = self.get(slot.id)
            if existing is not None:
                availability_slots.remove(existing)
            availability_slots.append(slot)
        return slots

    def delete_expired_non_booked(
        self,
        *,
        department_id: str | None = None,
        doctor_id: str | None = None,
    ) -> dict[str, int]:
        cutoff = datetime.now(UTC) - timedelta(hours=24)
        checked = 0
        matched: list[AvailabilitySlot] = []
        for slot in self.list(department_id=department_id, doctor_id=doctor_id):
            checked += 1
            if slot.end_at < cutoff and slot.status != SlotStatus.BOOKED:
                matched.append(slot)

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            for slot in matched:
                client.collection(settings.firestore_availability_slots_collection).document(slot.id).delete()
        else:
            for slot in matched:
                availability_slots.remove(slot)

        return {"deleted": len(matched), "matched": len(matched), "checked": checked}
