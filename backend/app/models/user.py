from app.models.common import TimestampedModel, UserRole


class UserAccount(TimestampedModel):
    uid: str
    email: str
    role: UserRole
    status: str = "active"
