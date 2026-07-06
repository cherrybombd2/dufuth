import logging

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_availability_slot_service, get_current_user
from app.schemas.auth import AuthenticatedUser
from app.schemas.availability_slot import (
    AvailabilitySlotAutoGenerate,
    AvailabilitySlotBulkCreate,
    AvailabilitySlotCreate,
    AvailabilitySlotResponse,
    AvailabilitySlotStatusUpdate,
    AvailabilitySlotUpdate,
    CleanupSlotsResponse,
)
from app.services.availability_slot_service import AvailabilitySlotService

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("", response_model=list[AvailabilitySlotResponse])
async def list_slots(
    department_id: str | None = Query(default=None),
    doctor_id: str | None = Query(default=None),
    selected_date: str | None = Query(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> list[AvailabilitySlotResponse]:
    return service.list_slots(
        current_user,
        department_id=department_id,
        doctor_id=doctor_id,
        selected_date=selected_date,
    )


@router.get("/available", response_model=list[AvailabilitySlotResponse])
async def list_available_slots(
    department_id: str = Query(),
    doctor_id: str = Query(),
    selected_date: str = Query(),
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> list[AvailabilitySlotResponse]:
    return service.list_available_slots(
        current_user,
        department_id=department_id,
        doctor_id=doctor_id,
        selected_date=selected_date,
    )


@router.post("", response_model=AvailabilitySlotResponse, status_code=status.HTTP_201_CREATED)
async def create_slot(
    payload: AvailabilitySlotCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> AvailabilitySlotResponse:
    logger.info(
        "Availability slot create request: department_id=%s doctor_id=%s date=%s start=%s end=%s status=%s",
        payload.department_id,
        payload.doctor_id,
        payload.date,
        payload.start_time,
        payload.end_time,
        payload.status,
    )
    response = service.create_slot(current_user, payload)
    logger.info("Availability slot create response: slot_id=%s", response.id)
    return response


@router.put("/{slot_id}", response_model=AvailabilitySlotResponse)
async def update_slot(
    slot_id: str,
    payload: AvailabilitySlotUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> AvailabilitySlotResponse:
    return service.update_slot(slot_id, current_user, payload)


@router.post("/bulk", response_model=list[AvailabilitySlotResponse], status_code=status.HTTP_201_CREATED)
async def bulk_create_slots(
    payload: AvailabilitySlotBulkCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> list[AvailabilitySlotResponse]:
    logger.info(
        "Availability slot bulk create request: department_id=%s doctor_id=%s date=%s ranges=%s status=%s",
        payload.department_id,
        payload.doctor_id,
        payload.date,
        len(payload.ranges),
        payload.status,
    )
    response = service.bulk_create(current_user, payload)
    logger.info("Availability slot bulk create response: created=%s", len(response))
    return response


@router.post("/auto-generate", response_model=list[AvailabilitySlotResponse], status_code=status.HTTP_201_CREATED)
async def auto_generate_slots(
    payload: AvailabilitySlotAutoGenerate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> list[AvailabilitySlotResponse]:
    logger.info(
        "Availability slot auto-generate request: department_id=%s doctor_id=%s start=%s end=%s weekdays=%s duration=%s status=%s",
        payload.department_id,
        payload.doctor_id,
        payload.start_date,
        payload.end_date,
        payload.weekdays,
        payload.slot_duration_minutes,
        payload.status,
    )
    response = service.auto_generate(current_user, payload)
    logger.info("Availability slot auto-generate response: created=%s", len(response))
    return response


@router.patch("/{slot_id}/status", response_model=AvailabilitySlotResponse)
async def update_slot_status(
    slot_id: str,
    payload: AvailabilitySlotStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> AvailabilitySlotResponse:
    return service.update_status(slot_id, current_user, payload)


@router.post("/cleanup", response_model=CleanupSlotsResponse)
async def cleanup_expired_slots(
    department_id: str | None = Query(default=None),
    doctor_id: str | None = Query(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AvailabilitySlotService = Depends(get_availability_slot_service),
) -> CleanupSlotsResponse:
    return service.cleanup(current_user, department_id=department_id, doctor_id=doctor_id)
