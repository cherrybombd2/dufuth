from fastapi import APIRouter, Depends

from app.api.dependencies import (
    get_current_user,
    get_reminder_service,
    get_scheduled_reminder_service,
)
from app.schemas.auth import AuthenticatedUser
from app.schemas.reminder import (
    ReminderDispatchSummary,
    ReminderResponse,
    ReminderStatusUpdate,
)
from app.services.reminder_service import ReminderService
from app.services.scheduled_reminder_service import ScheduledReminderService

router = APIRouter()


@router.get("", response_model=list[ReminderResponse])
async def list_my_reminders(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: ReminderService = Depends(get_reminder_service),
) -> list[ReminderResponse]:
    return service.list_patient_reminders(current_user)


@router.post("/send-due", response_model=ReminderDispatchSummary)
async def send_due_reminders(
    current_user: AuthenticatedUser = Depends(get_current_user),
    reminder_service: ReminderService = Depends(get_reminder_service),
    service: ScheduledReminderService = Depends(get_scheduled_reminder_service),
) -> ReminderDispatchSummary:
    reminder_service.require_admin(current_user)
    result = await service.send_due_reminders()
    return ReminderDispatchSummary(
        checked=result.checked,
        sent=result.sent,
        skipped=result.skipped,
    )


@router.patch("/{reminder_id}/status", response_model=ReminderResponse)
async def update_my_reminder_status(
    reminder_id: str,
    payload: ReminderStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: ReminderService = Depends(get_reminder_service),
) -> ReminderResponse:
    return service.update_patient_status(reminder_id, current_user, payload.status)
