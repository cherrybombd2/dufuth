from datetime import UTC, datetime

from pydantic import BaseModel, Field


class FaqItem(BaseModel):
    id: str
    question: str
    answer: str
    category: str | None = None
    sort_order: int = 0
    is_active: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
