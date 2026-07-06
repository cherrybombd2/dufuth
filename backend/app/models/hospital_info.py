from datetime import UTC, datetime

from pydantic import BaseModel, Field


class HospitalInfo(BaseModel):
    hospital_name: str = "DUFUTH SmartCare"
    tagline: str | None = None
    address: str | None = None
    phone: str | None = None
    email: str | None = None
    working_hours: str | None = None
    visiting_hours: str | None = None
    website: str | None = None
    about: str | None = None
    patient_notice: str | None = None
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
