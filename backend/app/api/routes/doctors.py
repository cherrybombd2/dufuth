from datetime import date

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import (
    get_current_user,
    get_doctor_alert_service,
    get_doctor_service,
)
from app.schemas.appointment import AppointmentResponse
from app.schemas.auth import AuthenticatedUser
from app.schemas.doctor_alert import DoctorAlertResponse, DoctorAlertStatusUpdate
from app.schemas.doctor import (
    DoctorActiveUpdate,
    DoctorAdminResponse,
    DoctorScheduleResponse,
    DoctorSummary,
    DoctorUpsert,
    UserLookupResult,
)
from app.services.doctor_service import DoctorService
from app.services.doctor_alert_service import DoctorAlertService

router = APIRouter()


@router.get("", response_model=list[DoctorSummary])
async def list_doctors(
    service: DoctorService = Depends(get_doctor_service),
) -> list[DoctorSummary]:
    return service.list_doctors()


@router.get("/admin", response_model=list[DoctorAdminResponse])
async def list_admin_doctors(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> list[DoctorAdminResponse]:
    return service.list_admin_doctors(current_user)


@router.get("/admin/user-search", response_model=list[UserLookupResult])
async def search_user_accounts(
    query: str = Query(min_length=3),
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> list[UserLookupResult]:
    return service.search_user_accounts(current_user, query)


@router.post("/admin", response_model=DoctorAdminResponse, status_code=status.HTTP_201_CREATED)
async def create_admin_doctor(
    payload: DoctorUpsert,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> DoctorAdminResponse:
    return service.create_admin_doctor(current_user, payload)


@router.put("/admin/{doctor_id}", response_model=DoctorAdminResponse)
async def update_admin_doctor(
    doctor_id: str,
    payload: DoctorUpsert,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> DoctorAdminResponse:
    return service.update_admin_doctor(doctor_id, current_user, payload)


@router.patch("/admin/{doctor_id}/active", response_model=DoctorAdminResponse)
async def update_admin_doctor_active_state(
    doctor_id: str,
    payload: DoctorActiveUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> DoctorAdminResponse:
    return service.update_admin_doctor_active_state(doctor_id, current_user, payload)


@router.get("/alerts", response_model=list[DoctorAlertResponse])
async def list_my_doctor_alerts(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorAlertService = Depends(get_doctor_alert_service),
) -> list[DoctorAlertResponse]:
    return service.list_my_alerts(current_user)


@router.patch("/alerts/{alert_id}/status", response_model=DoctorAlertResponse)
async def update_my_doctor_alert_status(
    alert_id: str,
    payload: DoctorAlertStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorAlertService = Depends(get_doctor_alert_service),
) -> DoctorAlertResponse:
    return service.update_my_alert_status(alert_id, current_user, payload.status)


@router.get("/appointments/{appointment_id}", response_model=AppointmentResponse)
async def get_doctor_appointment_detail(
    appointment_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DoctorService = Depends(get_doctor_service),
) -> AppointmentResponse:
    return service.get_appointment_detail(current_user, appointment_id)


@router.get("/{doctor_id}/schedule", response_model=DoctorScheduleResponse)
async def get_doctor_schedule(
    doctor_id: str,
    selected_date: date | None = None,
    service: DoctorService = Depends(get_doctor_service),
) -> DoctorScheduleResponse:
    return service.get_schedule(doctor_id, selected_date=selected_date)
