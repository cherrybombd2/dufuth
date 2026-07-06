from __future__ import annotations

from uuid import uuid4

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.doctor_alert import DoctorAlert, DoctorAlertStatus
from app.repositories.in_memory_store import doctor_alerts


class DoctorAlertRepository:
    def list_by_doctor(self, doctor_id: str) -> list[DoctorAlert]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            query = (
                client.collection(settings.firestore_doctor_alerts_collection)
                .where("doctor_id", "==", doctor_id)
                .stream()
            )
            return [
                DoctorAlert.model_validate({"id": item.id, **(item.to_dict() or {})})
                for item in query
            ]
        return [item for item in doctor_alerts if item.doctor_id == doctor_id]

    def get(self, alert_id: str) -> DoctorAlert | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = (
                client.collection(settings.firestore_doctor_alerts_collection)
                .document(alert_id)
                .get()
            )
            if not snapshot.exists:
                return None
            return DoctorAlert.model_validate({"id": snapshot.id, **(snapshot.to_dict() or {})})
        return next((item for item in doctor_alerts if item.id == alert_id), None)

    def save(self, alert: DoctorAlert) -> DoctorAlert:
        if not alert.id:
            alert = alert.model_copy(update={"id": f"dalert_{uuid4().hex[:10]}"})

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_doctor_alerts_collection).document(alert.id).set(
                alert.model_dump(exclude={"id"}, mode="python")
            )
            return alert

        existing = self.get(alert.id)
        if existing is not None:
            doctor_alerts.remove(existing)
        doctor_alerts.append(alert)
        return alert

    def update_status(
        self,
        alert_id: str,
        status: DoctorAlertStatus,
    ) -> DoctorAlert | None:
        alert = self.get(alert_id)
        if alert is None:
            return None
        return self.save(alert.model_copy(update={"status": status}))
