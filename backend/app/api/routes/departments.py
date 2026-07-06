from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import get_current_user, get_department_service
from app.schemas.auth import AuthenticatedUser
from app.schemas.department import (
    DepartmentActiveUpdate,
    DepartmentCreate,
    DepartmentResponse,
    DepartmentUpdate,
)
from app.services.department_service import DepartmentService

router = APIRouter()


@router.get("", response_model=list[DepartmentResponse])
async def list_departments(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> list[DepartmentResponse]:
    return service.list_departments(current_user)


@router.get("/active", response_model=list[DepartmentResponse])
async def list_active_departments(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> list[DepartmentResponse]:
    return service.list_active_departments()


@router.post("", response_model=DepartmentResponse, status_code=status.HTTP_201_CREATED)
async def create_department(
    payload: DepartmentCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> DepartmentResponse:
    return service.create_department(current_user, payload)


@router.put("/{name}", response_model=DepartmentResponse)
async def update_department(
    name: str,
    payload: DepartmentUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> DepartmentResponse:
    return service.update_department(name, current_user, payload)


@router.patch("/{name}/active", response_model=DepartmentResponse)
async def update_department_active_state(
    name: str,
    payload: DepartmentActiveUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> DepartmentResponse:
    return service.update_active_state(name, current_user, payload)


@router.delete("/{name}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_department(
    name: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
) -> Response:
    service.delete_department(name, current_user)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
