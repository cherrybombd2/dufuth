from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "DUFUTH SmartCare API"
    environment: str = "development"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"
    firebase_project_id: str = ""
    firebase_credentials_path: str | None = None
    firebase_auth_required: bool = False
    use_firestore: bool = False
    fcm_enabled: bool = False
    notification_retry_attempts: int = 2
    notification_retry_base_delay_seconds: float = 0.4
    firestore_users_collection: str = "users"
    firestore_patients_collection: str = "patient_profiles"
    firestore_doctors_collection: str = "doctor_profiles"
    firestore_appointments_collection: str = "appointments"
    firestore_departments_collection: str = "departments"
    firestore_availability_slots_collection: str = "availability_slots"
    firestore_device_tokens_collection: str = "device_tokens"
    firestore_app_content_collection: str = "app_content"
    firestore_faq_items_collection: str = "faq_items"
    firestore_reminders_collection: str = "reminders"
    firestore_doctor_alerts_collection: str = "doctor_alerts"
    app_minimum_required_version: str = "1.0.0"
    app_latest_version: str = "1.0.0"
    app_force_update: bool = False
    app_update_download_url: str = "https://dufuth-smartcare-download.netlify.app/"
    app_update_message: str = "Please update DUFUTH SmartCare to continue."

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
