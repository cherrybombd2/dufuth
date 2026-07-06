from datetime import UTC, datetime

from pydantic import BaseModel, Field


class DeviceTokenRecord(BaseModel):
    id: str
    token: str
    user_uid: str
    platform: str
    is_active: bool = True
    last_seen_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
