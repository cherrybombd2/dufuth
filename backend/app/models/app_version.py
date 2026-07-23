from pydantic import BaseModel


class AppVersionPolicy(BaseModel):
    minimum_required_version: str
    latest_version: str
    force_update: bool
    download_url: str
    message: str
