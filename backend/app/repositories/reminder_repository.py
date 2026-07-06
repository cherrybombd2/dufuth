from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.reminder import Reminder, ReminderDeliveryStatus, ReminderStatus
from app.repositories.in_memory_store import reminders


class ReminderRepository:
    def list_by_patient(self, patient_id: str) -> list[Reminder]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_reminders_collection)
                .where("patient_id", "==", patient_id)
                .stream()
            )
            return [
                Reminder.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]
        return [item for item in reminders if item.patient_id == patient_id]

    def list_due(self, now: datetime | None = None) -> list[Reminder]:
        cutoff = now or datetime.now(UTC)
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_reminders_collection)
                .where("reminder_type", "==", "appointment_reminder")
                .where("status", "==", ReminderStatus.PENDING.value)
                .where("remind_at", "<=", cutoff)
                .stream()
            )
            results = [
                Reminder.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]
            return [
                item for item in results if item.delivery_status != ReminderDeliveryStatus.SENT
            ]
        return [
            item
            for item in reminders
            if item.reminder_type == "appointment_reminder"
            and item.status == ReminderStatus.PENDING
            and item.delivery_status != ReminderDeliveryStatus.SENT
            and item.remind_at <= cutoff
        ]

    def get(self, reminder_id: str) -> Reminder | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_reminders_collection)
                .document(reminder_id)
                .get()
            )
            if not snapshot.exists:
                return None
            return Reminder.model_validate({"id": snapshot.id, **(snapshot.to_dict() or {})})
        return next((item for item in reminders if item.id == reminder_id), None)

    def upsert_for_appointment(self, reminder: Reminder) -> Reminder:
        existing = self._get_for_appointment(reminder.patient_id, reminder.appointment_id)
        saved = reminder.model_copy(update={"id": existing.id}) if existing is not None else reminder
        return self.save(saved)

    def save(self, reminder: Reminder) -> Reminder:
        if not reminder.id:
            reminder = reminder.model_copy(update={"id": f"rem_{uuid4().hex[:10]}"})

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_reminders_collection).document(reminder.id).set(
                reminder.model_dump(exclude={"id"}, mode="python")
            )
            return reminder

        existing = self.get(reminder.id)
        if existing is not None:
            reminders.remove(existing)
        reminders.append(reminder)
        return reminder

    def update_status(self, reminder_id: str, status: ReminderStatus) -> Reminder | None:
        reminder = self.get(reminder_id)
        if reminder is None:
            return None
        return self.save(reminder.model_copy(update={"status": status}))

    def mark_delivery(
        self,
        reminder_id: str,
        delivery_status: ReminderDeliveryStatus,
        sent_at: datetime | None = None,
    ) -> Reminder | None:
        reminder = self.get(reminder_id)
        if reminder is None:
            return None
        return self.save(
            reminder.model_copy(
                update={
                    "delivery_status": delivery_status,
                    "sent_at": sent_at,
                }
            )
        )

    def dismiss_for_appointment(self, patient_id: str, appointment_id: str | None) -> Reminder | None:
        reminder = self._get_for_appointment(patient_id, appointment_id)
        if reminder is None:
            return None
        return self.save(reminder.model_copy(update={"status": ReminderStatus.DISMISSED}))

    def cancel_for_appointment(self, patient_id: str, appointment_id: str | None) -> Reminder | None:
        reminder = self._get_for_appointment(patient_id, appointment_id)
        if reminder is None:
            return None
        return self.save(
            reminder.model_copy(
                update={
                    "status": ReminderStatus.CANCELLED,
                    "delivery_status": ReminderDeliveryStatus.CANCELLED,
                }
            )
        )

    def _get_for_appointment(
        self,
        patient_id: str,
        appointment_id: str | None,
    ) -> Reminder | None:
        if appointment_id is None:
            return None

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_reminders_collection)
                .where("patient_id", "==", patient_id)
                .where("appointment_id", "==", appointment_id)
                .limit(1)
                .stream()
            )
            for item in query:
                return Reminder.model_validate({"id": item.id, **(item.to_dict() or {})})
            return None

        return next(
            (
                item
                for item in reminders
                if item.patient_id == patient_id and item.appointment_id == appointment_id
            ),
            None,
        )
