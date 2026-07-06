from datetime import UTC, datetime

from pydantic import BaseModel, Field


class Department(BaseModel):
    name: str
    description: str | None = None
    icon_key: str | None = None
    is_active: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
