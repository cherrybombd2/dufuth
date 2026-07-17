from fastapi import APIRouter
from starlette import status
from starlette.responses import Response

from app.core.config import get_settings

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    settings = get_settings()
    return {
        "status": "ok",
        "environment": settings.environment,
    }


@router.head("/health")
async def health_check_head() -> Response:
    return Response(status_code=status.HTTP_200_OK)
