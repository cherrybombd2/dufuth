from datetime import datetime
from enum import StrEnum

from app.models.common import TimestampedModel


class ReminderStatus(StrEnum):
    PENDING = "pending"
    READ = "read"
    DISMISSED = "dismissed"
    CANCELLED = "cancelled"


class ReminderDeliveryStatus(StrEnum):
    PENDING = "pending"
    SENT = "sent"
    CANCELLED = "cancelled"


class ReminderType(StrEnum):
    APPOINTMENT = "appointment_reminder"


class Reminder(TimestampedModel):
    id: str
    patient_id: str
    patient_name: str | None = None
    reminder_type: str = ReminderType.APPOINTMENT.value
    title: str
    message: str
    remind_at: datetime
    status: ReminderStatus = ReminderStatus.PENDING
    delivery_status: ReminderDeliveryStatus = ReminderDeliveryStatus.PENDING
    sent_at: datetime | None = None
    appointment_id: str | None = None
    slot_id: str | None = None
    doctor_id: str | None = None
    doctor_name: str | None = None
    doctor_gender: str | None = None
    department_name: str | None = None
    appointment_start_at: datetime | None = None
    appointment_end_at: datetime | None = None
