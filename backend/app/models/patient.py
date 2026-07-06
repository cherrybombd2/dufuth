from app.models.common import TimestampedModel, UserRole


class Patient(TimestampedModel):
    user_id: str
    full_name: str
    phone_number: str | None = None
    gender: str | None = None
    address: str | None = None
    date_of_birth: str | None = None
    role: UserRole = UserRole.PATIENT
