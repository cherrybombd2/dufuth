from app.repositories.app_version_repository import AppVersionRepository
from app.schemas.app_version import AppVersionPolicyResponse


class AppVersionService:
    def __init__(self, repository: AppVersionRepository) -> None:
        self.repository = repository

    def get_policy(self) -> AppVersionPolicyResponse:
        return AppVersionPolicyResponse(
            **self.repository.get_policy().model_dump(),
        )
