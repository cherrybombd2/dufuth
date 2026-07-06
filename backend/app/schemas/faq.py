from datetime import datetime

from pydantic import BaseModel, Field


class FaqItemResponse(BaseModel):
    id: str
    question: str
    answer: str
    category: str | None = None
    sort_order: int = 0
    is_active: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


class FaqItemCreate(BaseModel):
    question: str = Field(min_length=1)
    answer: str = Field(min_length=1)
    category: str | None = None
    sort_order: int = 0
    is_active: bool = True


class FaqItemUpdate(BaseModel):
    question: str = Field(min_length=1)
    answer: str = Field(min_length=1)
    category: str | None = None
    sort_order: int = 0
    is_active: bool = True


class FaqItemActiveUpdate(BaseModel):
    is_active: bool
