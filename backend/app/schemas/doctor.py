from datetime import datetime

from pydantic import BaseModel

from app.schemas.appointment import AppointmentResponse


class DoctorAdminResponse(BaseModel):
    user_id: str
    full_name: str
    department_id: str
    specialization: str | None = None
    gender: str | None = None
    bio: str | None = None
    consultation_mode: str | None = None
    years_of_experience: int | None = None
    linked_account_email: str | None = None
    is_active: bool = True
    created_at: datetime | None = None


class DoctorUpsert(BaseModel):
    user_id: str | None = None
    full_name: str
    department_id: str
    specialization: str | None = None
    gender: str
    bio: str | None = None
    consultation_mode: str | None = None
    years_of_experience: int | None = None
    is_active: bool = True


class DoctorActiveUpdate(BaseModel):
    is_active: bool
    force_deactivate: bool = False


class UserLookupResult(BaseModel):
    uid: str
    email: str | None = None
    role: str | None = None
    status: str | None = None
    full_name: str | None = None
    gender: str | None = None


class DoctorSummary(BaseModel):
    user_id: str
    full_name: str
    department_id: str
    specialization: str | None = None
    gender: str | None = None
    is_active: bool = True
    created_at: datetime | None = None


class DoctorScheduleResponse(BaseModel):
    doctor: DoctorSummary
    appointments: list[AppointmentResponse]
