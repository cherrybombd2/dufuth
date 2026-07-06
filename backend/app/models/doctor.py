from app.models.common import TimestampedModel, UserRole


class Doctor(TimestampedModel):
    user_id: str
    full_name: str
    department_id: str
    specialization: str | None = None
    gender: str | None = None
    bio: str | None = None
    consultation_mode: str | None = None
    years_of_experience: int | None = None
    linked_account_email: str | None = None
    title: str | None = None
    is_active: bool = True
    role: UserRole = UserRole.DOCTOR
