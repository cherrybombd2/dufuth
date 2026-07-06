from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_messaging_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.notification import NotificationSendRequest, NotificationSendResponse
from app.services.messaging_service import MessagingService

router = APIRouter()


@router.post("/send-test", response_model=NotificationSendResponse)
async def send_test_message(
    payload: NotificationSendRequest,
    _: AuthenticatedUser = Depends(get_current_user),
    service: MessagingService = Depends(get_messaging_service),
) -> NotificationSendResponse:
    return service.send_to_device(payload)
