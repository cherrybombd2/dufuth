from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from app.models.reminder import ReminderDeliveryStatus
from app.repositories.reminder_repository import ReminderRepository
from app.services.messaging_service import MessagingService


@dataclass(slots=True)
class ScheduledReminderResult:
    checked: int = 0
    sent: int = 0
    skipped: int = 0


class ScheduledReminderService:
    def __init__(
        self,
        repository: ReminderRepository,
        messaging_service: MessagingService,
    ) -> None:
        self.repository = repository
        self.messaging_service = messaging_service

    async def send_due_reminders(self) -> ScheduledReminderResult:
        due = self.repository.list_due()
        result = ScheduledReminderResult(checked=len(due))
        for reminder in due:
            if not reminder.patient_id:
                result.skipped += 1
                continue
            sent = await self.messaging_service.send_to_user(
                reminder.patient_id,
                title=reminder.title,
                body=reminder.message,
                data={
                    "event": "appointment_reminder_due",
                    "appointmentId": reminder.appointment_id or "",
                    "reminderId": reminder.id,
                },
            )
            if sent > 0:
                self.repository.mark_delivery(
                    reminder.id,
                    ReminderDeliveryStatus.SENT,
                    sent_at=datetime.now(UTC),
                )
                result.sent += 1
            else:
                result.skipped += 1
        return result
