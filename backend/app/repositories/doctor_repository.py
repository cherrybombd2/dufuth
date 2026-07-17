from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.doctor import Doctor
from app.repositories.in_memory_store import doctors
from app.schemas.doctor import DoctorUpsert


class DoctorRepository:
    def list(self) -> list[Doctor]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            return [
                Doctor.model_validate({"user_id": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_doctors_collection).stream()
            ]
        return doctors

    def get_by_id(self, doctor_id: str) -> Doctor | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = client.collection(settings.firestore_doctors_collection).document(doctor_id).get()
            if not snapshot.exists:
                return None
            return Doctor.model_validate({"user_id": snapshot.id, **(snapshot.to_dict() or {})})
        return next((doctor for doctor in doctors if doctor.user_id == doctor_id), None)

    def get_many_by_ids(self, doctor_ids: set[str]) -> dict[str, Doctor]:
        if not doctor_ids:
            return {}

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            collection = client.collection(settings.firestore_doctors_collection)
            snapshots = client.get_all(
                [collection.document(doctor_id) for doctor_id in doctor_ids]
            )
            return {
                snapshot.id: Doctor.model_validate(
                    {"user_id": snapshot.id, **(snapshot.to_dict() or {})}
                )
                for snapshot in snapshots
                if snapshot.exists
            }

        return {doctor.user_id: doctor for doctor in doctors if doctor.user_id in doctor_ids}

    def upsert(self, payload: DoctorUpsert, linked_account_email: str | None = None) -> Doctor:
        doctor_id = payload.user_id or f"doctor_{uuid4().hex[:10]}"
        existing = self.get_by_id(doctor_id)
        doctor = Doctor(
            user_id=doctor_id,
            full_name=payload.full_name,
            department_id=payload.department_id,
            specialization=payload.specialization,
            gender=payload.gender,
            bio=payload.bio,
            consultation_mode=payload.consultation_mode,
            years_of_experience=payload.years_of_experience,
            linked_account_email=linked_account_email,
            is_active=payload.is_active,
            created_at=existing.created_at if existing is not None else datetime.now(UTC),
        )
        self._save(doctor)
        return doctor

    def set_active(self, doctor_id: str, is_active: bool) -> Doctor | None:
        existing = self.get_by_id(doctor_id)
        if existing is None:
            return None
        doctor = existing.model_copy(update={"is_active": is_active})
        self._save(doctor)
        return doctor

    def _save(self, doctor: Doctor) -> None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_doctors_collection).document(doctor.user_id).set(
                doctor.model_dump(exclude={"user_id"}, mode="python")
            )
            return

        existing = self.get_by_id(doctor.user_id)
        if existing is not None:
            doctors.remove(existing)
        doctors.append(doctor)
