import logging
from datetime import UTC, date, datetime, time, timedelta

from fastapi import HTTPException, status

from app.models.availability_slot import AvailabilitySlot, SlotStatus
from app.models.common import UserRole
from app.repositories.availability_slot_repository import AvailabilitySlotRepository
from app.repositories.department_repository import DepartmentRepository
from app.repositories.doctor_repository import DoctorRepository
from app.schemas.auth import AuthenticatedUser
from app.schemas.availability_slot import (
    AvailabilitySlotAutoGenerate,
    AvailabilitySlotBulkCreate,
    AvailabilitySlotCreate,
    AvailabilitySlotResponse,
    AvailabilitySlotStatusUpdate,
    AvailabilitySlotUpdate,
    CleanupSlotsResponse,
)

logger = logging.getLogger(__name__)


class AvailabilitySlotService:
    def __init__(
        self,
        repository: AvailabilitySlotRepository,
        department_repository: DepartmentRepository,
        doctor_repository: DoctorRepository,
    ) -> None:
        self.repository = repository
        self.department_repository = department_repository
        self.doctor_repository = doctor_repository

    def list_slots(
        self,
        current_user: AuthenticatedUser,
        *,
        department_id: str | None = None,
        doctor_id: str | None = None,
        selected_date: str | None = None,
    ) -> list[AvailabilitySlotResponse]:
        if current_user.role == UserRole.DOCTOR:
            if doctor_id is not None and doctor_id != current_user.uid:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Doctors can only view their own schedule slots.",
                )
            doctor_id = current_user.uid
        else:
            self._require_admin(current_user)
        return [
            AvailabilitySlotResponse(**slot.model_dump())
            for slot in self.repository.list(
                department_id=department_id,
                doctor_id=doctor_id,
                selected_date=selected_date,
            )
        ]

    def list_available_slots(
        self,
        current_user: AuthenticatedUser,
        *,
        department_id: str,
        doctor_id: str,
        selected_date: str,
    ) -> list[AvailabilitySlotResponse]:
        if current_user.uid is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Please sign in before viewing slots.",
            )
        return [
            AvailabilitySlotResponse(**slot.model_dump())
            for slot in self.repository.list_available(
                department_id=department_id,
                doctor_id=doctor_id,
                selected_date=selected_date,
            )
        ]

    def create_slot(
        self,
        current_user: AuthenticatedUser,
        payload: AvailabilitySlotCreate,
    ) -> AvailabilitySlotResponse:
        self._require_admin(current_user)
        slot = self._create_single(payload)
        return AvailabilitySlotResponse(**slot.model_dump())

    def update_slot(
        self,
        slot_id: str,
        current_user: AuthenticatedUser,
        payload: AvailabilitySlotUpdate,
    ) -> AvailabilitySlotResponse:
        self._require_admin(current_user)
        existing = self._editable_slot(slot_id)
        department, doctor = self._validate_assignment(payload.department_id, payload.doctor_id)
        start_at, end_at = self._combine(payload.date, payload.start_time, payload.end_time)
        self._validate_future_range(start_at, end_at)
        slot = existing.model_copy(
            update={
                "department_id": department.name,
                "department_name": department.name,
                "doctor_id": doctor.user_id,
                "doctor_name": doctor.full_name,
                "start_at": start_at,
                "end_at": end_at,
                "status": payload.status,
            }
        )
        return AvailabilitySlotResponse(**self.repository.save(slot).model_dump())

    def bulk_create(
        self,
        current_user: AuthenticatedUser,
        payload: AvailabilitySlotBulkCreate,
    ) -> list[AvailabilitySlotResponse]:
        self._require_admin(current_user)
        department, doctor = self._validate_assignment(payload.department_id, payload.doctor_id)
        slots: list[AvailabilitySlot] = []
        for item in payload.ranges:
            start_at, end_at = self._combine(payload.date, item.start_time, item.end_time)
            self._validate_future_range(start_at, end_at)
            slots.append(
                self.repository.build(
                    department_id=department.name,
                    department_name=department.name,
                    doctor_id=doctor.user_id,
                    doctor_name=doctor.full_name,
                    start_at=start_at,
                    end_at=end_at,
                    status=payload.status,
                )
            )
        created = self.repository.save_many(slots)
        return [AvailabilitySlotResponse(**slot.model_dump()) for slot in created]

    def auto_generate(
        self,
        current_user: AuthenticatedUser,
        payload: AvailabilitySlotAutoGenerate,
    ) -> list[AvailabilitySlotResponse]:
        self._require_admin(current_user)
        if payload.end_date < payload.start_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="End date must be on or after start date.",
            )
        if payload.slot_duration_minutes <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Slot duration must be greater than zero.",
            )

        department, doctor = self._validate_assignment(payload.department_id, payload.doctor_id)
        slots: list[AvailabilitySlot] = []
        current = payload.start_date
        while current <= payload.end_date:
            if current.weekday() in payload.weekdays:
                start = datetime.combine(current, payload.start_time, tzinfo=UTC)
                day_end = datetime.combine(current, payload.end_time, tzinfo=UTC)
                while start + timedelta(minutes=payload.slot_duration_minutes) <= day_end:
                    end = start + timedelta(minutes=payload.slot_duration_minutes)
                    self._validate_future_range(start, end)
                    slots.append(
                        self.repository.build(
                            department_id=department.name,
                            department_name=department.name,
                            doctor_id=doctor.user_id,
                            doctor_name=doctor.full_name,
                            start_at=start,
                            end_at=end,
                            status=payload.status,
                        )
                    )
                    start = end
            current += timedelta(days=1)
        created = self.repository.save_many(slots)
        return [AvailabilitySlotResponse(**slot.model_dump()) for slot in created]

    def update_status(
        self,
        slot_id: str,
        current_user: AuthenticatedUser,
        payload: AvailabilitySlotStatusUpdate,
    ) -> AvailabilitySlotResponse:
        self._require_admin(current_user)
        existing = self._editable_slot(slot_id)
        slot = existing.model_copy(update={"status": payload.status})
        return AvailabilitySlotResponse(**self.repository.save(slot).model_dump())

    def cleanup(
        self,
        current_user: AuthenticatedUser,
        *,
        department_id: str | None = None,
        doctor_id: str | None = None,
    ) -> CleanupSlotsResponse:
        self._require_admin(current_user)
        return CleanupSlotsResponse(
            **self.repository.delete_expired_non_booked(
                department_id=department_id,
                doctor_id=doctor_id,
            )
        )

    def _create_single(self, payload: AvailabilitySlotCreate) -> AvailabilitySlot:
        logger.info(
            "Availability slot create validation started: department_id=%s doctor_id=%s date=%s start=%s end=%s",
            payload.department_id,
            payload.doctor_id,
            payload.date,
            payload.start_time,
            payload.end_time,
        )
        department, doctor = self._validate_assignment(payload.department_id, payload.doctor_id)
        start_at, end_at = self._combine(payload.date, payload.start_time, payload.end_time)
        self._validate_future_range(start_at, end_at)
        logger.info(
            "Availability slot repository create started: department_id=%s doctor_id=%s start_at=%s end_at=%s",
            department.name,
            doctor.user_id,
            start_at,
            end_at,
        )
        return self.repository.create(
            department_id=department.name,
            department_name=department.name,
            doctor_id=doctor.user_id,
            doctor_name=doctor.full_name,
            start_at=start_at,
            end_at=end_at,
            status=payload.status,
        )

    def _validate_assignment(self, department_id: str, doctor_id: str):
        department = self.department_repository.get(department_id)
        doctor = self.doctor_repository.get_by_id(doctor_id)
        if department is None or not department.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Select an active department.",
            )
        if doctor is None or not doctor.is_active or doctor.department_id != department.name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Select an active doctor in the chosen department.",
            )
        return department, doctor

    def _editable_slot(self, slot_id: str) -> AvailabilitySlot:
        slot = self.repository.get(slot_id)
        if slot is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found.")
        if slot.status == SlotStatus.BOOKED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Booked slots are locked to protect existing appointments.",
            )
        if slot.end_at <= datetime.now(UTC):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Past slots are shown for reference only.",
            )
        return slot

    def _combine(self, day: date, start: time, end: time) -> tuple[datetime, datetime]:
        return datetime.combine(day, start, tzinfo=UTC), datetime.combine(day, end, tzinfo=UTC)

    def _validate_future_range(self, start_at: datetime, end_at: datetime) -> None:
        if end_at <= start_at:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="End time must be later than start time.",
            )
        if start_at <= datetime.now(UTC):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Past times cannot be used. Please choose a future time.",
            )

    def _require_admin(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can manage availability slots.",
            )
