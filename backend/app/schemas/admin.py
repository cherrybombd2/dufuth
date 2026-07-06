from pydantic import BaseModel


class AdminDashboardResponse(BaseModel):
    total_doctors: int
    total_departments: int
    active_appointments: int
