from pydantic import BaseModel, EmailStr


class AdminUserSummary(BaseModel):
    uid: str
    email: EmailStr | str | None = None
    role: str
    status: str
    full_name: str | None = None
    phone: str | None = None


class UserStatusUpdate(BaseModel):
    status: str
