from app.repositories.device_token_repository import DeviceTokenRepository
from app.schemas.device import DeviceTokenRegistration, DeviceTokenResponse


class DeviceTokenService:
    def __init__(self, repository: DeviceTokenRepository) -> None:
        self.repository = repository

    def register(self, user_id: str, payload: DeviceTokenRegistration) -> DeviceTokenResponse:
        record = self.repository.register(user_id, payload)
        return DeviceTokenResponse.model_validate(record)
