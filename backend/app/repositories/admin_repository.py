from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.repositories.in_memory_store import doctors


class AdminRepository:
    def count_doctors(self) -> int:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            return sum(1 for _ in client.collection(settings.firestore_doctors_collection).stream())
        return len(doctors)

    def count_departments(self) -> int:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            departments = {
                (item.to_dict() or {}).get("department_id")
                for item in client.collection(settings.firestore_doctors_collection).stream()
            }
            return len({department for department in departments if department})
        return len({doctor.department_id for doctor in doctors})
