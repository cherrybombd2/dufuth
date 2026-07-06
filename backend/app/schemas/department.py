from datetime import datetime

from pydantic import BaseModel, Field


class DepartmentResponse(BaseModel):
    name: str
    description: str | None = None
    icon_key: str | None = None
    is_active: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


class DepartmentCreate(BaseModel):
    name: str = Field(min_length=1)
    description: str | None = None
    icon_key: str | None = None
    is_active: bool = True


class DepartmentUpdate(BaseModel):
    name: str = Field(min_length=1)
    description: str | None = None
    icon_key: str | None = None
    is_active: bool = True


class DepartmentActiveUpdate(BaseModel):
    is_active: bool
