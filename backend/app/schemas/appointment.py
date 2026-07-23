from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.appointment import AppointmentStatus


class AppointmentCreate(BaseModel):
    patient_id: str
    doctor_id: str
    department: str
    scheduled_for: datetime


class AppointmentStatusUpdate(BaseModel):
    status: AppointmentStatus


class AppointmentBookingCreate(BaseModel):
    department_id: str
    doctor_id: str
    slot_id: str


class AppointmentReschedule(BaseModel):
    department_id: str
    doctor_id: str
    slot_id: str


class AppointmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    patient_id: str
    patient_name: str | None = None
    patient_gender: str | None = None
    doctor_id: str
    department: str
    scheduled_for: datetime
    slot_id: str | None = None
    status: AppointmentStatus
    created_at: datetime


class PatientAppointmentResponse(BaseModel):
    id: str
    patient_id: str
    doctor_id: str
    doctor_name: str
    doctor_gender: str | None = None
    department_id: str
    department_name: str
    start_at: datetime
    end_at: datetime
    slot_id: str | None = None
    status: AppointmentStatus
    created_at: datetime
