from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.reminder import ReminderDeliveryStatus, ReminderStatus


class ReminderStatusUpdate(BaseModel):
    status: ReminderStatus


class ReminderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    patient_id: str
    reminder_type: str
    title: str
    message: str
    remind_at: datetime
    status: ReminderStatus
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
    created_at: datetime


class ReminderDispatchSummary(BaseModel):
    checked: int
    sent: int
    skipped: int
