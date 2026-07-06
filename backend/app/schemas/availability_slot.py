from datetime import date, datetime, time

from pydantic import BaseModel, Field

from app.models.availability_slot import SlotStatus


class AvailabilitySlotResponse(BaseModel):
    id: str
    department_id: str
    department_name: str
    doctor_id: str
    doctor_name: str
    start_at: datetime
    end_at: datetime
    status: SlotStatus = SlotStatus.AVAILABLE
    created_at: datetime | None = None


class AvailabilitySlotCreate(BaseModel):
    department_id: str
    doctor_id: str
    date: date
    start_time: time
    end_time: time
    status: SlotStatus = SlotStatus.AVAILABLE


class AvailabilitySlotUpdate(AvailabilitySlotCreate):
    pass


class AvailabilitySlotStatusUpdate(BaseModel):
    status: SlotStatus


class BulkSlotRange(BaseModel):
    start_time: time
    end_time: time


class AvailabilitySlotBulkCreate(BaseModel):
    department_id: str
    doctor_id: str
    date: date
    status: SlotStatus = SlotStatus.AVAILABLE
    ranges: list[BulkSlotRange] = Field(min_length=1)


class AvailabilitySlotAutoGenerate(BaseModel):
    department_id: str
    doctor_id: str
    start_date: date
    end_date: date
    weekdays: list[int] = Field(min_length=1)
    start_time: time
    end_time: time
    slot_duration_minutes: int
    status: SlotStatus = SlotStatus.AVAILABLE


class CleanupSlotsResponse(BaseModel):
    deleted: int
    matched: int
    checked: int
