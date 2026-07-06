from datetime import datetime

from pydantic import BaseModel, EmailStr


class AuthenticatedUser(BaseModel):
    uid: str
    email: str | None = None
    role: str | None = None
    token_payload: dict

    @classmethod
    def from_token_payload(cls, payload: dict) -> "AuthenticatedUser":
        return cls(
            uid=payload["uid"],
            email=payload.get("email"),
            role=payload.get("role"),
            token_payload=payload,
        )

class SessionProfile(BaseModel):
    user_id: str
    full_name: str = ""
    phone_number: str | None = None
    gender: str | None = None
    address: str | None = None
    date_of_birth: str | None = None
    department_id: str | None = None
    specialization: str | None = None
    bio: str | None = None
    consultation_mode: str | None = None
    years_of_experience: int | None = None
    title: str | None = None
    is_active: bool | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SessionUser(BaseModel):
    uid: str
    email: EmailStr
    role: str
    status: str
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SessionResponse(BaseModel):
    user: SessionUser
    profile: SessionProfile


class PatientProfileUpsert(BaseModel):
    full_name: str
    phone_number: str | None = None
    gender: str | None = None
    address: str | None = None
    date_of_birth: str | None = None
