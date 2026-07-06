from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_patient_service
from app.schemas.auth import AuthenticatedUser, PatientProfileUpsert
from app.schemas.patient import PatientResponse
from app.services.patient_service import PatientService

router = APIRouter()


@router.get("", response_model=list[PatientResponse])
async def list_patients(
    service: PatientService = Depends(get_patient_service),
) -> list[PatientResponse]:
    return service.list_patients()
