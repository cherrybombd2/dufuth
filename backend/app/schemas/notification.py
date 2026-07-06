from pydantic import BaseModel


class NotificationSendRequest(BaseModel):
    token: str
    title: str
    body: str
    data: dict[str, str] | None = None


class NotificationSendResponse(BaseModel):
    message_id: str
