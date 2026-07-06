from contextlib import asynccontextmanager
import logging
from time import perf_counter

from fastapi import FastAPI, Request

from app.api.router import api_router
from app.core.config import get_settings
from app.core.firebase import initialize_firebase


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_firebase()
    yield


settings = get_settings()
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    lifespan=lifespan,
)
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.middleware("http")
async def log_availability_slot_requests(request: Request, call_next):
    if request.url.path.startswith(f"{settings.api_v1_prefix}/availability-slots"):
        started_at = perf_counter()
        logger.warning(
            "Availability slot request received: method=%s path=%s",
            request.method,
            request.url.path,
        )
        response = await call_next(request)
        logger.warning(
            "Availability slot request finished: method=%s path=%s status=%s elapsed_ms=%s",
            request.method,
            request.url.path,
            response.status_code,
            round((perf_counter() - started_at) * 1000),
        )
        return response
    return await call_next(request)


@app.get("/", tags=["root"])
async def root() -> dict[str, str]:
    return {"message": f"{settings.app_name} is running"}
