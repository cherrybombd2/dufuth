from fastapi import APIRouter, BackgroundTasks, Depends, status

from app.api.dependencies import get_appointment_service, get_current_user
from app.schemas.auth import AuthenticatedUser
from app.schemas.appointment import (
    AppointmentBookingCreate,
    AppointmentCreate,
    AppointmentReschedule,
    AppointmentResponse,
    AppointmentStatusUpdate,
    PatientAppointmentResponse,
)
from app.services.appointment_service import AppointmentService

router = APIRouter()


@router.get("", response_model=list[AppointmentResponse])
async def list_appointments(
    service: AppointmentService = Depends(get_appointment_service),
) -> list[AppointmentResponse]:
    return service.list_appointments()


@router.get("/mine", response_model=list[PatientAppointmentResponse])
async def list_my_appointments(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service),
) -> list[PatientAppointmentResponse]:
    return service.list_patient_appointments(current_user)


@router.post("", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    payload: AppointmentCreate,
    service: AppointmentService = Depends(get_appointment_service),
) -> AppointmentResponse:
    return service.create_appointment(payload)


@router.post("/book", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
async def book_appointment(
    payload: AppointmentBookingCreate,
    background_tasks: BackgroundTasks,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service),
) -> AppointmentResponse:
    return service.book_appointment(current_user, payload, background_tasks=background_tasks)


@router.post("/{appointment_id}/reschedule", response_model=AppointmentResponse)
async def reschedule_appointment(
    appointment_id: str,
    payload: AppointmentReschedule,
    background_tasks: BackgroundTasks,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service),
) -> AppointmentResponse:
    return service.reschedule_appointment(
        appointment_id,
        current_user,
        payload,
        background_tasks=background_tasks,
    )


@router.post("/{appointment_id}/cancel", response_model=PatientAppointmentResponse)
async def cancel_my_appointment(
    appointment_id: str,
    background_tasks: BackgroundTasks,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service),
) -> PatientAppointmentResponse:
    return service.cancel_patient_appointment(
        appointment_id,
        current_user,
        background_tasks=background_tasks,
    )


@router.patch("/{appointment_id}/status", response_model=AppointmentResponse)
async def update_appointment_status(
    appointment_id: str,
    payload: AppointmentStatusUpdate,
    service: AppointmentService = Depends(get_appointment_service),
) -> AppointmentResponse:
    return service.update_status(appointment_id, payload.status)
