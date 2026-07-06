from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, get_user_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.user import AdminUserSummary, UserStatusUpdate
from app.services.user_service import UserService

router = APIRouter()


@router.get("/admin", response_model=list[AdminUserSummary])
def list_admin_users(
    role: str | None = Query(default=None),
    status: str | None = Query(default=None),
    query: str | None = Query(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> list[AdminUserSummary]:
    return service.list_admin_users(
        current_user=current_user,
        role=role,
        status_filter=status,
        query=query,
    )


@router.patch("/admin/{user_id}/status", response_model=AdminUserSummary)
def update_admin_user_status(
    user_id: str,
    payload: UserStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> AdminUserSummary:
    return service.update_admin_user_status(
        user_id=user_id,
        current_user=current_user,
        payload=payload,
    )
