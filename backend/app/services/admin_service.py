from app.repositories.admin_repository import AdminRepository
from app.repositories.appointment_repository import AppointmentRepository
from app.repositories.doctor_repository import DoctorRepository
from app.schemas.admin import AdminDashboardResponse


class AdminService:
    def __init__(
        self,
        admin_repository: AdminRepository,
        doctor_repository: DoctorRepository,
        appointment_repository: AppointmentRepository,
    ) -> None:
        self.admin_repository = admin_repository
        self.doctor_repository = doctor_repository
        self.appointment_repository = appointment_repository

    def get_dashboard(self) -> AdminDashboardResponse:
        active_appointments = len(
            [item for item in self.appointment_repository.list() if item.status == "booked"]
        )
        return AdminDashboardResponse(
            total_doctors=self.admin_repository.count_doctors(),
            total_departments=self.admin_repository.count_departments(),
            active_appointments=active_appointments,
        )
