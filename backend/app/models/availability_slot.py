from datetime import datetime
from enum import StrEnum

from app.models.common import TimestampedModel


class SlotStatus(StrEnum):
    AVAILABLE = "available"
    BOOKED = "booked"
    BLOCKED = "blocked"


class AvailabilitySlot(TimestampedModel):
    id: str
    department_id: str
    department_name: str
    doctor_id: str
    doctor_name: str
    start_at: datetime
    end_at: datetime
    status: SlotStatus = SlotStatus.AVAILABLE
