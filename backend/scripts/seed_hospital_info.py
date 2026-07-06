from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.repositories.hospital_info_repository import HospitalInfoRepository


HOSPITAL_INFO_VALUES = {
    "hospital_name": "DUFUTH",
    "tagline": "Clinics, Exams, Diagnostics, Training & Research",
    "about": (
        "Our driving objective at DUFUTH is to become a world class teaching "
        "hospital, We hope to achieve this using cutting edge technology and "
        "highly developed human resources committed to rendering excellent "
        "medical services to the good people of Nigeria and beyond."
    ),
    "phone": "+234 0815 839 8323+234 0815 825 6450",
    "email": "dufuth@support.com",
    "working_hours": "24/7",
    "visiting_hours": "12am-10pm",
    "address": "UMUNAGU ENUAGU ROAD UBURU P.O.BOX 337, EBONYI STATE",
    "website": "https://www.dufuthuburu.online/",
}


def main() -> int:
    settings = get_settings()
    firestore_client = get_firestore_client()
    if firestore_client is None:
        print(
            "Firestore is not enabled or Firebase Admin is not configured. "
            "This script updates the real hospital info document only."
        )
        print(
            "Check backend/.env and ensure USE_FIRESTORE=true plus valid "
            "Firebase project credentials before running."
        )
        return 1

    repository = HospitalInfoRepository()
    current_info = repository.get()

    for field_name, field_value in HOSPITAL_INFO_VALUES.items():
        setattr(current_info, field_name, field_value)

    saved_info = repository.update(current_info)

    print(
        "Hospital info upsert complete: "
        f"collection='{settings.firestore_app_content_collection}', "
        "document_id='hospital_info'"
    )
    print(f"Hospital name: {saved_info.hospital_name}")
    print(f"Updated at: {saved_info.updated_at.isoformat()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
