from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.doctor_alert import DoctorAlertStatus


class DoctorAlertStatusUpdate(BaseModel):
    status: DoctorAlertStatus


class DoctorAlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    doctor_id: str
    patient_id: str | None = None
    patient_name: str | None = None
    patient_gender: str | None = None
    department_name: str | None = None
    alert_type: str
    title: str
    message: str
    remind_at: datetime
    status: DoctorAlertStatus
    appointment_id: str | None = None
    slot_id: str | None = None
    appointment_start_at: datetime | None = None
    appointment_end_at: datetime | None = None
    created_at: datetime
