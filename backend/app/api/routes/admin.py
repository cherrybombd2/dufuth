from fastapi import APIRouter, Depends

from app.api.dependencies import get_admin_service
from app.schemas.admin import AdminDashboardResponse
from app.services.admin_service import AdminService

router = APIRouter()


@router.get("/dashboard", response_model=AdminDashboardResponse)
async def get_dashboard(
    service: AdminService = Depends(get_admin_service),
) -> AdminDashboardResponse:
    return service.get_dashboard()
