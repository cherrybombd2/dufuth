from datetime import datetime
from enum import StrEnum

from app.models.common import TimestampedModel


class AppointmentStatus(StrEnum):
    BOOKED = "booked"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class Appointment(TimestampedModel):
    id: str
    patient_id: str
    doctor_id: str
    department: str
    scheduled_for: datetime
    slot_id: str | None = None
    status: AppointmentStatus = AppointmentStatus.BOOKED
