from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_faq_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.faq import (
    FaqItemActiveUpdate,
    FaqItemCreate,
    FaqItemResponse,
    FaqItemUpdate,
)
from app.services.faq_service import FaqService

router = APIRouter()


@router.get("", response_model=list[FaqItemResponse])
async def list_patient_faq_items(
    service: FaqService = Depends(get_faq_service),
) -> list[FaqItemResponse]:
    return service.list_patient_items()


@router.get("/admin", response_model=list[FaqItemResponse])
async def list_admin_faq_items(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: FaqService = Depends(get_faq_service),
) -> list[FaqItemResponse]:
    return service.list_admin_items(current_user)


@router.post(
    "/admin",
    response_model=FaqItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_faq_item(
    payload: FaqItemCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: FaqService = Depends(get_faq_service),
) -> FaqItemResponse:
    return service.create_item(current_user, payload)


@router.put("/admin/{item_id}", response_model=FaqItemResponse)
async def update_faq_item(
    item_id: str,
    payload: FaqItemUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: FaqService = Depends(get_faq_service),
) -> FaqItemResponse:
    return service.update_item(item_id, current_user, payload)


@router.patch("/admin/{item_id}/active", response_model=FaqItemResponse)
async def update_faq_item_active_state(
    item_id: str,
    payload: FaqItemActiveUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: FaqService = Depends(get_faq_service),
) -> FaqItemResponse:
    return service.update_active_state(item_id, current_user, payload)
