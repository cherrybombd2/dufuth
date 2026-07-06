from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.appointment import Appointment, AppointmentStatus
from app.models.availability_slot import AvailabilitySlot
from app.repositories.in_memory_store import appointments
from app.schemas.appointment import AppointmentCreate


class AppointmentRepository:
    def list(self) -> list[Appointment]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            return [
                Appointment.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_appointments_collection).stream()
            ]
        return appointments

    def list_by_doctor(self, doctor_id: str) -> list[Appointment]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_appointments_collection)
                .where("doctor_id", "==", doctor_id)
                .stream()
            )
            return [
                Appointment.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]
        return [item for item in appointments if item.doctor_id == doctor_id]

    def list_by_patient(self, patient_id: str) -> list[Appointment]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_appointments_collection)
                .where("patient_id", "==", patient_id)
                .stream()
            )
            return [
                Appointment.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]
        return [item for item in appointments if item.patient_id == patient_id]

    def has_future_booked_for_doctor(self, doctor_id: str) -> bool:
        now = datetime.now(UTC)
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_appointments_collection)
                .where("doctor_id", "==", doctor_id)
                .where("status", "==", AppointmentStatus.BOOKED.value)
                .stream()
            )
            for item in query:
                appointment = Appointment.model_validate({"id": item.id, **(item.to_dict() or {})})
                if appointment.scheduled_for > now:
                    return True
            return False

        return any(
            item.doctor_id == doctor_id
            and item.status == AppointmentStatus.BOOKED
            and item.scheduled_for > now
            for item in appointments
        )

    def create(self, payload: AppointmentCreate) -> Appointment:
        appointment = Appointment(
            id=f"appt_{uuid4().hex[:8]}",
            patient_id=payload.patient_id,
            doctor_id=payload.doctor_id,
            department=payload.department,
            scheduled_for=payload.scheduled_for,
        )

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_appointments_collection).document(appointment.id).set(
                appointment.model_dump(exclude={"id"}, mode="python")
            )
            return appointment

        appointments.append(appointment)
        return appointment

    def create_from_slot(
        self,
        *,
        patient_id: str,
        slot: AvailabilitySlot,
    ) -> Appointment:
        appointment = Appointment(
            id=f"appt_{uuid4().hex[:8]}",
            patient_id=patient_id,
            doctor_id=slot.doctor_id,
            department=slot.department_name,
            scheduled_for=slot.start_at,
            slot_id=slot.id,
        )
        return self.save(appointment)

    def get(self, appointment_id: str) -> Appointment | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_appointments_collection)
                .document(appointment_id)
                .get()
            )
            if not snapshot.exists:
                return None
            return Appointment.model_validate({"id": snapshot.id, **(snapshot.to_dict() or {})})
        return next((item for item in appointments if item.id == appointment_id), None)

    def save(self, appointment: Appointment) -> Appointment:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_appointments_collection).document(appointment.id).set(
                appointment.model_dump(exclude={"id"}, mode="python")
            )
            return appointment

        existing = self.get(appointment.id)
        if existing is not None:
            appointments.remove(existing)
        appointments.append(appointment)
        return appointment

    def update_status(
        self,
        appointment_id: str,
        status: AppointmentStatus,
    ) -> Appointment | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            reference = client.collection(settings.firestore_appointments_collection).document(
                appointment_id
            )
            snapshot = reference.get()
            if not snapshot.exists:
                return None
            reference.update({"status": status.value})
            return Appointment.model_validate(
                {"id": snapshot.id, **(snapshot.to_dict() or {}), "status": status.value}
            )

        appointment = next((item for item in appointments if item.id == appointment_id), None)
        if appointment is None:
            return None
        appointment.status = status
        return appointment
