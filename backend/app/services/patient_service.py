from app.repositories.patient_repository import PatientRepository
from app.schemas.auth import PatientProfileUpsert
from app.schemas.patient import PatientResponse


class PatientService:
    def __init__(self, repository: PatientRepository) -> None:
        self.repository = repository

    def list_patients(self) -> list[PatientResponse]:
        return [PatientResponse.model_validate(item) for item in self.repository.list()]

    def create_patient(self, user_id: str, payload: PatientProfileUpsert) -> PatientResponse:
        patient = self.repository.upsert(user_id, payload)
        return PatientResponse.model_validate(patient)
