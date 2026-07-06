from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DeviceTokenRegistration(BaseModel):
    token: str
    platform: str = "android"


class DeviceTokenResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    token: str
    user_uid: str
    platform: str
    is_active: bool
    last_seen_at: datetime
    updated_at: datetime
    created_at: datetime
