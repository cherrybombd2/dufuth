from datetime import datetime
from enum import StrEnum

from app.models.common import TimestampedModel


class DoctorAlertStatus(StrEnum):
    PENDING = "pending"
    READ = "read"
    DISMISSED = "dismissed"


class DoctorAlertType(StrEnum):
    NEW_BOOKING = "new_booking"
    APPOINTMENT_CANCELLED = "appointment_cancelled"
    APPOINTMENT_RESCHEDULED = "appointment_rescheduled"


class DoctorAlert(TimestampedModel):
    id: str
    doctor_id: str
    patient_id: str | None = None
    patient_name: str | None = None
    patient_gender: str | None = None
    department_name: str | None = None
    alert_type: str = DoctorAlertType.NEW_BOOKING.value
    title: str
    message: str
    remind_at: datetime
    status: DoctorAlertStatus = DoctorAlertStatus.PENDING
    appointment_id: str | None = None
    slot_id: str | None = None
    appointment_start_at: datetime | None = None
    appointment_end_at: datetime | None = None
