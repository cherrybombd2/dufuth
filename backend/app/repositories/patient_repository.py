from __future__ import annotations

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.patient import Patient
from app.repositories.in_memory_store import patients
from app.schemas.auth import PatientProfileUpsert


class PatientRepository:
    def list(self) -> list[Patient]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            return [
                Patient.model_validate({"user_id": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_patients_collection).stream()
            ]
        return patients

    def get_by_user_id(self, user_id: str) -> Patient | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = client.collection(settings.firestore_patients_collection).document(user_id).get()
            if not snapshot.exists:
                return None
            return Patient.model_validate({"user_id": snapshot.id, **(snapshot.to_dict() or {})})

        return next((patient for patient in patients if patient.user_id == user_id), None)

    def get_many_by_user_ids(self, user_ids: set[str]) -> dict[str, Patient]:
        if not user_ids:
            return {}

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            collection = client.collection(settings.firestore_patients_collection)
            snapshots = client.get_all([collection.document(user_id) for user_id in user_ids])
            return {
                snapshot.id: Patient.model_validate(
                    {"user_id": snapshot.id, **(snapshot.to_dict() or {})}
                )
                for snapshot in snapshots
                if snapshot.exists
            }

        return {patient.user_id: patient for patient in patients if patient.user_id in user_ids}

    def upsert(self, user_id: str, payload: PatientProfileUpsert) -> Patient:
        patient = Patient(
            user_id=user_id,
            full_name=payload.full_name,
            phone_number=payload.phone_number,
            gender=payload.gender,
            address=payload.address,
            date_of_birth=payload.date_of_birth,
        )

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_patients_collection).document(user_id).set(
                patient.model_dump(exclude={"user_id"}, mode="python")
            )
            return patient

        existing = self.get_by_user_id(user_id)
        if existing is not None:
            patients.remove(existing)
        patients.append(patient)
        return patient
