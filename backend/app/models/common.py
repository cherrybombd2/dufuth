from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class UserRole(StrEnum):
    PATIENT = "patient"
    DOCTOR = "doctor"
    ADMIN = "admin"


class TimestampedModel(BaseModel):
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
