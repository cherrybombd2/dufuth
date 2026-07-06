import asyncio
import logging

from app.core.config import get_settings
from app.core.firebase import send_fcm_message, send_fcm_multicast
from app.repositories.device_token_repository import DeviceTokenRepository
from app.schemas.notification import NotificationSendRequest, NotificationSendResponse

logger = logging.getLogger(__name__)


class MessagingService:
    def __init__(self, repository: DeviceTokenRepository | None = None) -> None:
        self._repository = repository or DeviceTokenRepository()

    def send_to_device(self, payload: NotificationSendRequest) -> NotificationSendResponse:
        message_id = send_fcm_message(
            token=payload.token,
            title=payload.title,
            body=payload.body,
            data=payload.data,
        )
        return NotificationSendResponse(message_id=message_id)

    async def send_to_user(
        self,
        user_uid: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> int:
        tokens = self._repository.list_active_for_user(user_uid)
        if not tokens:
            return 0

        token_values = [item.token for item in tokens]
        settings = get_settings()
        attempts = max(1, settings.notification_retry_attempts)
        delay_seconds = max(0.0, settings.notification_retry_base_delay_seconds)
        last_error: Exception | None = None

        for attempt in range(attempts):
            try:
                response = send_fcm_multicast(
                    token_values,
                    title=title,
                    body=body,
                    data=data,
                )
                success_count = 0
                for record, send_response in zip(tokens, response.responses, strict=False):
                    if send_response.success:
                        success_count += 1
                        continue
                    if self._is_permanent_token_error(send_response.exception):
                        self._repository.deactivate_token(record.token)
                return success_count
            except Exception as error:  # noqa: BLE001
                last_error = error
                if attempt == attempts - 1:
                    break
                await asyncio.sleep(delay_seconds * (2**attempt))

        logger.warning(
            "Notification delivery failed after retries for user %s: %s",
            user_uid,
            last_error,
        )
        return 0

    def _is_permanent_token_error(self, error: Exception | None) -> bool:
        if error is None:
            return False
        type_name = error.__class__.__name__.lower()
        message = str(error).lower()
        return any(
            key in type_name or key in message
            for key in (
                "unregistered",
                "invalidargument",
                "senderidmismatch",
                "registration token is not a valid fcm registration token",
            )
        )
