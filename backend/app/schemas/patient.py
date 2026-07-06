from datetime import datetime

from pydantic import BaseModel


class PatientResponse(BaseModel):
    user_id: str
    full_name: str
    phone_number: str | None = None
    gender: str | None = None
    address: str | None = None
    date_of_birth: str | None = None
    created_at: datetime
