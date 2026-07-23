from __future__ import annotations

from datetime import UTC, datetime

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.department import Department
from app.repositories.in_memory_store import appointments, departments, doctors
from app.schemas.department import DepartmentCreate, DepartmentUpdate


class DepartmentRepository:
    def list(self) -> list[Department]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            items = [
                Department.model_validate({"name": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_departments_collection).stream()
            ]
        else:
            items = list(departments)

        return sorted(items, key=lambda item: item.name.lower())

    def get(self, name: str) -> Department | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            collection = client.collection(settings.firestore_departments_collection)
            snapshot = collection.document(name).get()
            if not snapshot.exists:
                matches = collection.where("name", "==", name).limit(1).stream()
                snapshot = next(matches, None)
                if snapshot is None:
                    return None
            if not snapshot.exists:
                return None
            return Department.model_validate({"name": snapshot.id, **(snapshot.to_dict() or {})})

        return next((item for item in departments if item.name == name), None)

    def create(self, payload: DepartmentCreate) -> Department | None:
        if self.get(payload.name) is not None:
            return None

        now = datetime.now(UTC)
        department = Department(
            name=payload.name,
            description=payload.description,
            icon_key=payload.icon_key,
            is_active=payload.is_active,
            created_at=now,
            updated_at=now,
        )
        self._save(department)
        return department

    def update(self, current_name: str, payload: DepartmentUpdate) -> Department | None:
        existing = self.get(current_name)
        if existing is None:
            return None
        if payload.name != current_name and self.get(payload.name) is not None:
            raise ValueError("duplicate_department")

        department = existing.model_copy(
            update={
                "name": payload.name,
                "description": payload.description,
                "icon_key": payload.icon_key,
                "is_active": payload.is_active,
                "updated_at": datetime.now(UTC),
            }
        )
        self._save(department, previous_name=current_name)
        return department

    def set_active(self, name: str, is_active: bool) -> Department | None:
        existing = self.get(name)
        if existing is None:
            return None

        department = existing.model_copy(
            update={"is_active": is_active, "updated_at": datetime.now(UTC)}
        )
        self._save(department)
        return department

    def delete(self, name: str) -> bool:
        existing = self.get(name)
        if existing is None:
            return False

        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_departments_collection).document(name).delete()
            return True

        departments.remove(existing)
        return True

    def has_links(self, name: str) -> bool:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            doctor_refs = (
                client.collection(settings.firestore_doctors_collection)
                .where("department_id", "==", name)
                .limit(1)
                .stream()
            )
            if any(True for _ in doctor_refs):
                return True

            appointment_refs = (
                client.collection(settings.firestore_appointments_collection)
                .where("department", "==", name)
                .limit(1)
                .stream()
            )
            if any(True for _ in appointment_refs):
                return True

            slot_refs = (
                client.collection(settings.firestore_availability_slots_collection)
                .where("department", "==", name)
                .limit(1)
                .stream()
            )
            if any(True for _ in slot_refs):
                return True

            slot_id_refs = (
                client.collection(settings.firestore_availability_slots_collection)
                .where("department_id", "==", name)
                .limit(1)
                .stream()
            )
            return any(True for _ in slot_id_refs)

        return any(doctor.department_id == name for doctor in doctors) or any(
            appointment.department == name for appointment in appointments
        )

    def _save(self, department: Department, previous_name: str | None = None) -> None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            if previous_name is not None and previous_name != department.name:
                client.collection(settings.firestore_departments_collection).document(previous_name).delete()
            client.collection(settings.firestore_departments_collection).document(department.name).set(
                department.model_dump(exclude={"name"}, mode="python")
            )
            return

        if previous_name is not None and previous_name != department.name:
            previous = self.get(previous_name)
            if previous is not None:
                departments.remove(previous)
        existing = self.get(department.name)
        if existing is not None:
            departments.remove(existing)
        departments.append(department)
