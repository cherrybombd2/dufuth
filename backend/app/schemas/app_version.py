from pydantic import BaseModel, ConfigDict, Field


class AppVersionPolicyResponse(BaseModel):
    minimum_required_version: str = Field(alias="minimumRequiredVersion")
    latest_version: str = Field(alias="latestVersion")
    force_update: bool = Field(alias="forceUpdate")
    download_url: str = Field(alias="downloadUrl")
    message: str

    model_config = ConfigDict(populate_by_name=True)
