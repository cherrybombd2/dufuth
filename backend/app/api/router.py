from fastapi import APIRouter

from app.api.routes import (
    admin,
    appointments,
    auth,
    availability_slots,
    departments,
    devices,
    doctors,
    faq,
    health,
    hospital_info,
    messaging,
    patients,
    reminders,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(patients.router, prefix="/patients", tags=["patients"])
api_router.include_router(doctors.router, prefix="/doctors", tags=["doctors"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(departments.router, prefix="/departments", tags=["departments"])
api_router.include_router(appointments.router, prefix="/appointments", tags=["appointments"])
api_router.include_router(
    availability_slots.router,
    prefix="/availability-slots",
    tags=["availability-slots"],
)
api_router.include_router(devices.router, prefix="/devices", tags=["devices"])
api_router.include_router(messaging.router, prefix="/messaging", tags=["messaging"])
api_router.include_router(hospital_info.router, prefix="/hospital-info", tags=["hospital-info"])
api_router.include_router(faq.router, prefix="/faq-items", tags=["faq-items"])
api_router.include_router(reminders.router, prefix="/reminders", tags=["reminders"])
