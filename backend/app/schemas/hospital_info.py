from datetime import datetime

from pydantic import BaseModel, Field


class HospitalInfoResponse(BaseModel):
    hospital_name: str
    tagline: str | None = None
    address: str | None = None
    phone: str | None = None
    email: str | None = None
    working_hours: str | None = None
    visiting_hours: str | None = None
    website: str | None = None
    about: str | None = None
    patient_notice: str | None = None
    updated_at: datetime | None = None


class HospitalInfoUpdate(BaseModel):
    hospital_name: str = Field(min_length=1)
    tagline: str | None = None
    address: str | None = None
    phone: str | None = None
    email: str | None = None
    working_hours: str | None = None
    visiting_hours: str | None = None
    website: str | None = None
    about: str | None = None
    patient_notice: str | None = None
