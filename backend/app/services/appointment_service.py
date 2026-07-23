from datetime import UTC, datetime, timedelta

from fastapi import BackgroundTasks, HTTPException, status

from app.models.availability_slot import SlotStatus
from app.models.appointment import AppointmentStatus
from app.models.common import UserRole
from app.models.doctor_alert import DoctorAlert, DoctorAlertStatus, DoctorAlertType
from app.models.reminder import (
    Reminder,
    ReminderDeliveryStatus,
    ReminderStatus,
    ReminderType,
)
from app.repositories.appointment_repository import AppointmentRepository
from app.repositories.availability_slot_repository import AvailabilitySlotRepository
from app.repositories.doctor_repository import DoctorRepository
from app.repositories.doctor_alert_repository import DoctorAlertRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.reminder_repository import ReminderRepository
from app.schemas.appointment import (
    AppointmentBookingCreate,
    AppointmentCreate,
    AppointmentReschedule,
    AppointmentResponse,
    PatientAppointmentResponse,
)
from app.schemas.auth import AuthenticatedUser
from app.services.messaging_service import MessagingService


class AppointmentService:
    def __init__(
        self,
        repository: AppointmentRepository,
        slot_repository: AvailabilitySlotRepository | None = None,
        doctor_repository: DoctorRepository | None = None,
        patient_repository: PatientRepository | None = None,
        reminder_repository: ReminderRepository | None = None,
        doctor_alert_repository: DoctorAlertRepository | None = None,
        messaging_service: MessagingService | None = None,
    ) -> None:
        self.repository = repository
        self.slot_repository = slot_repository
        self.doctor_repository = doctor_repository
        self.patient_repository = patient_repository
        self.reminder_repository = reminder_repository
        self.doctor_alert_repository = doctor_alert_repository
        self.messaging_service = messaging_service

    def list_appointments(self) -> list[AppointmentResponse]:
        return [AppointmentResponse.model_validate(item) for item in self.repository.list()]

    def list_patient_appointments(
        self,
        current_user: AuthenticatedUser,
    ) -> list[PatientAppointmentResponse]:
        self._require_patient(current_user)
        patient_appointments = self.repository.list_by_patient(current_user.uid)
        slots_by_id = {}
        if self.slot_repository is not None:
            slot_ids = {item.slot_id for item in patient_appointments if item.slot_id}
            slots_by_id = self.slot_repository.get_many_by_ids(slot_ids)

        doctor_ids = {item.doctor_id for item in patient_appointments}
        doctors_by_id = {}
        if self.doctor_repository is not None:
            doctors_by_id = self.doctor_repository.get_many_by_ids(doctor_ids)

        return [
            self._patient_response(
                item,
                slot=slots_by_id.get(item.slot_id) if item.slot_id else None,
                doctor=doctors_by_id.get(item.doctor_id),
                lookup_related=False,
            )
            for item in patient_appointments
        ]

    def create_appointment(self, payload: AppointmentCreate) -> AppointmentResponse:
        appointment = self.repository.create(payload)
        return AppointmentResponse.model_validate(appointment)

    def book_appointment(
        self,
        current_user: AuthenticatedUser,
        payload: AppointmentBookingCreate,
        background_tasks: BackgroundTasks | None = None,
    ) -> AppointmentResponse:
        self._require_patient(current_user)
        slot = self._bookable_slot(payload.slot_id)
        self._validate_slot_assignment(slot, payload.department_id, payload.doctor_id)
        appointment = self.repository.create_from_slot(patient_id=current_user.uid, slot=slot)
        self.slot_repository.set_status(slot.id, SlotStatus.BOOKED)
        patient = self._get_patient(appointment.patient_id)
        doctor = self._get_doctor(slot.doctor_id)
        self._save_appointment_reminder(appointment, slot, doctor=doctor, patient=patient)
        self._save_doctor_alert(
            appointment=appointment,
            slot=slot,
            alert_type=DoctorAlertType.NEW_BOOKING,
            patient=patient,
            doctor=doctor,
        )
        self._queue_booking_notifications(
            appointment=appointment,
            slot=slot,
            patient=patient,
            doctor=doctor,
            background_tasks=background_tasks,
        )
        return AppointmentResponse.model_validate(appointment)

    def reschedule_appointment(
        self,
        appointment_id: str,
        current_user: AuthenticatedUser,
        payload: AppointmentReschedule,
        background_tasks: BackgroundTasks | None = None,
    ) -> AppointmentResponse:
        self._require_patient(current_user)
        existing = self.repository.get(appointment_id)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Appointment not found.",
            )
        if existing.patient_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only reschedule your own appointments.",
            )
        if existing.status != AppointmentStatus.BOOKED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Only booked appointments can be rescheduled.",
            )

        slot = self._bookable_slot(payload.slot_id)
        self._validate_slot_assignment(slot, payload.department_id, payload.doctor_id)
        if slot.department_name != existing.department:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reschedules must stay within the original department.",
            )

        old_slot = None
        old_doctor_id = existing.doctor_id
        if existing.slot_id and existing.slot_id != slot.id:
            old_slot = self.slot_repository.get(existing.slot_id)
            if old_slot is not None and old_slot.status == SlotStatus.BOOKED:
                self.slot_repository.set_status(old_slot.id, SlotStatus.AVAILABLE)

        updated = existing.model_copy(
            update={
                "doctor_id": slot.doctor_id,
                "department": slot.department_name,
                "scheduled_for": slot.start_at,
                "slot_id": slot.id,
                "status": AppointmentStatus.BOOKED,
            }
        )
        saved = self.repository.save(updated)
        self.slot_repository.set_status(slot.id, SlotStatus.BOOKED)
        patient = self._get_patient(saved.patient_id)
        doctor = self._get_doctor(slot.doctor_id)
        self._save_appointment_reminder(saved, slot, doctor=doctor, patient=patient)
        if old_slot is not None and old_doctor_id != slot.doctor_id:
            self._save_doctor_alert(
                appointment=existing,
                slot=old_slot,
                alert_type=DoctorAlertType.APPOINTMENT_CANCELLED,
                patient=patient,
            )
        self._save_doctor_alert(
            appointment=saved,
            slot=slot,
            alert_type=DoctorAlertType.APPOINTMENT_RESCHEDULED,
            patient=patient,
            doctor=doctor,
        )
        self._queue_reschedule_notifications(
            appointment=saved,
            slot=slot,
            patient=patient,
            doctor=doctor,
            background_tasks=background_tasks,
        )
        return AppointmentResponse.model_validate(saved)

    def cancel_patient_appointment(
        self,
        appointment_id: str,
        current_user: AuthenticatedUser,
        background_tasks: BackgroundTasks | None = None,
    ) -> PatientAppointmentResponse:
        self._require_patient(current_user)
        appointment = self.repository.get(appointment_id)
        if appointment is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Appointment not found.",
            )
        if appointment.patient_id != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only cancel your own appointments.",
            )
        if appointment.status != AppointmentStatus.BOOKED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Only booked appointments can be cancelled.",
            )

        saved = self.repository.save(
            appointment.model_copy(update={"status": AppointmentStatus.CANCELLED})
        )
        if saved.slot_id and self.slot_repository is not None:
            slot = self.slot_repository.get(saved.slot_id)
            if slot is not None and slot.status == SlotStatus.BOOKED:
                self.slot_repository.set_status(slot.id, SlotStatus.AVAILABLE)
        if self.reminder_repository is not None:
            self.reminder_repository.cancel_for_appointment(saved.patient_id, saved.id)
        slot = None
        if saved.slot_id and self.slot_repository is not None:
            slot = self.slot_repository.get(saved.slot_id)
        patient = self._get_patient(saved.patient_id)
        doctor = self._get_doctor(saved.doctor_id)
        if slot is not None:
            self._save_doctor_alert(
                appointment=saved,
                slot=slot,
                alert_type=DoctorAlertType.APPOINTMENT_CANCELLED,
                patient=patient,
                doctor=doctor,
            )
            self._queue_cancellation_notifications(
                appointment=saved,
                slot=slot,
                patient=patient,
                doctor=doctor,
                background_tasks=background_tasks,
            )
        return self._patient_response(saved)

    def update_status(
        self,
        appointment_id: str,
        status_value: AppointmentStatus,
    ) -> AppointmentResponse:
        appointment = self.repository.update_status(appointment_id, status_value)
        if appointment is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Appointment not found",
            )
        return AppointmentResponse.model_validate(appointment)

    def _bookable_slot(self, slot_id: str):
        if self.slot_repository is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Availability slot service is not configured.",
            )
        slot = self.slot_repository.get(slot_id)
        if slot is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found.")
        if slot.status != SlotStatus.AVAILABLE:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This time slot is no longer available.",
            )
        if slot.start_at <= datetime.now(UTC):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This time slot has already passed. Please choose a later time.",
            )
        return slot

    def _validate_slot_assignment(
        self,
        slot,
        department_id: str,
        doctor_id: str,
    ) -> None:
        if slot.department_id != department_id or slot.doctor_id != doctor_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected slot does not match the chosen department and doctor.",
            )

    def _require_patient(self, current_user: AuthenticatedUser) -> None:
        if current_user.role != UserRole.PATIENT:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only patients can book appointments.",
            )

    def _save_appointment_reminder(self, appointment, slot, doctor=None, patient=None) -> None:
        if self.reminder_repository is None:
            return

        doctor_name = doctor.full_name if doctor is not None else slot.doctor_name
        remind_at = self._build_remind_at(slot.start_at)
        reminder = Reminder(
            id=f"rem_{appointment.id}",
            patient_id=appointment.patient_id,
            patient_name=patient.full_name if patient is not None else None,
            reminder_type=ReminderType.APPOINTMENT.value,
            title="Upcoming appointment reminder",
            message=(
                f"You have an appointment with {doctor_name} on "
                f"{self._format_date(slot.start_at)} at {self._format_time(slot.start_at)}."
            ),
            remind_at=remind_at,
            status=ReminderStatus.PENDING,
            delivery_status=ReminderDeliveryStatus.PENDING,
            sent_at=None,
            appointment_id=appointment.id,
            slot_id=slot.id,
            doctor_id=slot.doctor_id,
            doctor_name=doctor_name,
            doctor_gender=doctor.gender if doctor is not None else None,
            department_name=slot.department_name,
            appointment_start_at=slot.start_at,
            appointment_end_at=slot.end_at,
        )
        self.reminder_repository.upsert_for_appointment(reminder)

    def _save_doctor_alert(
        self,
        appointment,
        slot,
        alert_type: DoctorAlertType,
        patient=None,
        doctor=None,
    ) -> None:
        if self.doctor_alert_repository is None:
            return

        patient_name = "Patient"
        patient_gender = None
        if patient is not None:
            patient_name = patient.full_name
            patient_gender = patient.gender

        doctor_name = doctor.full_name if doctor is not None else slot.doctor_name
        title, message = self._doctor_alert_copy(
            alert_type,
            patient_name,
            doctor_name,
            slot.start_at,
        )
        alert = DoctorAlert(
            id="",
            doctor_id=slot.doctor_id,
            patient_id=appointment.patient_id,
            patient_name=patient_name,
            patient_gender=patient_gender,
            department_name=slot.department_name,
            alert_type=alert_type.value,
            title=title,
            message=message,
            remind_at=datetime.now(UTC),
            status=DoctorAlertStatus.PENDING,
            appointment_id=appointment.id,
            slot_id=slot.id,
            appointment_start_at=slot.start_at,
            appointment_end_at=slot.end_at,
        )
        self.doctor_alert_repository.save(alert)

    def _doctor_alert_copy(
        self,
        alert_type: DoctorAlertType,
        patient_name: str,
        doctor_name: str,
        start_at: datetime,
    ) -> tuple[str, str]:
        date_text = self._format_date(start_at)
        time_text = self._format_time(start_at)
        if alert_type == DoctorAlertType.NEW_BOOKING:
            return (
                "New patient booking",
                f"{patient_name} booked {date_text} at {time_text}.",
            )
        if alert_type == DoctorAlertType.APPOINTMENT_CANCELLED:
            return (
                "Patient cancelled appointment",
                f"{patient_name} cancelled the visit on {date_text} at {time_text}.",
            )
        return (
            "Patient rescheduled visit",
            f"{patient_name} moved the visit to {date_text} at {time_text}.",
        )

    def _get_patient(self, patient_id: str):
        if self.patient_repository is None:
            return None
        return self.patient_repository.get_by_user_id(patient_id)

    def _get_doctor(self, doctor_id: str):
        if self.doctor_repository is None:
            return None
        return self.doctor_repository.get_by_id(doctor_id)

    def _build_remind_at(self, start_at: datetime) -> datetime:
        now = datetime.now(UTC)
        try:
            delta = start_at - now
            if delta > timedelta(hours=24):
                return start_at - timedelta(hours=24)
            if delta > timedelta(hours=2):
                return start_at - timedelta(hours=2)
            return start_at
        except Exception:  # noqa: BLE001
            return start_at

    def _format_date(self, value: datetime) -> str:
        return value.astimezone(UTC).strftime("%Y-%m-%d")

    def _format_time(self, value: datetime) -> str:
        return value.astimezone(UTC).strftime("%H:%M")

    def _queue_booking_notifications(
        self,
        appointment,
        slot,
        patient,
        doctor,
        background_tasks: BackgroundTasks | None,
    ) -> None:
        if background_tasks is None or self.messaging_service is None:
            return
        doctor_name = doctor.full_name if doctor is not None else slot.doctor_name
        patient_name = patient.full_name if patient is not None else "Patient"
        date_text = self._format_date(slot.start_at)
        time_text = self._format_time(slot.start_at)
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            appointment.patient_id,
            "Appointment booked",
            f"Your visit with {doctor_name} on {date_text} at {time_text} is confirmed.",
            {
                "event": "appointment_booked",
                "appointmentId": appointment.id,
            },
        )
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            slot.doctor_id,
            "New patient booking",
            f"{patient_name} booked {date_text} at {time_text}.",
            {
                "event": "doctor_new_booking",
                "appointmentId": appointment.id,
            },
        )

    def _queue_cancellation_notifications(
        self,
        appointment,
        slot,
        patient,
        doctor,
        background_tasks: BackgroundTasks | None,
    ) -> None:
        if background_tasks is None or self.messaging_service is None:
            return
        doctor_name = doctor.full_name if doctor is not None else slot.doctor_name
        patient_name = patient.full_name if patient is not None else "Patient"
        date_text = self._format_date(slot.start_at)
        time_text = self._format_time(slot.start_at)
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            appointment.patient_id,
            "Appointment cancelled",
            f"Your appointment with {doctor_name} on {date_text} at {time_text} was cancelled.",
            {
                "event": "appointment_cancelled",
                "appointmentId": appointment.id,
            },
        )
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            slot.doctor_id,
            "Patient cancelled appointment",
            f"{patient_name} cancelled the visit on {date_text} at {time_text}.",
            {
                "event": "doctor_appointment_cancelled",
                "appointmentId": appointment.id,
            },
        )

    def _queue_reschedule_notifications(
        self,
        appointment,
        slot,
        patient,
        doctor,
        background_tasks: BackgroundTasks | None,
    ) -> None:
        if background_tasks is None or self.messaging_service is None:
            return
        doctor_name = doctor.full_name if doctor is not None else slot.doctor_name
        patient_name = patient.full_name if patient is not None else "Patient"
        date_text = self._format_date(slot.start_at)
        time_text = self._format_time(slot.start_at)
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            appointment.patient_id,
            "Appointment rescheduled",
            f"Your visit with {doctor_name} was moved to {date_text} at {time_text}.",
            {
                "event": "appointment_rescheduled",
                "appointmentId": appointment.id,
            },
        )
        background_tasks.add_task(
            self.messaging_service.send_to_user,
            slot.doctor_id,
            "Patient rescheduled visit",
            f"{patient_name} moved the visit to {date_text} at {time_text}.",
            {
                "event": "doctor_appointment_rescheduled",
                "appointmentId": appointment.id,
            },
        )

    def _patient_response(
        self,
        appointment,
        *,
        slot=None,
        doctor=None,
        lookup_related: bool = True,
    ) -> PatientAppointmentResponse:
        if lookup_related and slot is None and appointment.slot_id and self.slot_repository is not None:
            slot = self.slot_repository.get(appointment.slot_id)

        if lookup_related and doctor is None and self.doctor_repository is not None:
            doctor = self.doctor_repository.get_by_id(appointment.doctor_id)

        start_at = slot.start_at if slot is not None else appointment.scheduled_for
        end_at = (
            slot.end_at
            if slot is not None
            else appointment.scheduled_for + timedelta(minutes=30)
        )
        department_name = slot.department_name if slot is not None else appointment.department
        department_id = slot.department_id if slot is not None else appointment.department
        doctor_name = (
            slot.doctor_name
            if slot is not None
            else doctor.full_name
            if doctor is not None
            else appointment.doctor_id
        )

        return PatientAppointmentResponse(
            id=appointment.id,
            patient_id=appointment.patient_id,
            doctor_id=appointment.doctor_id,
            doctor_name=doctor_name,
            doctor_gender=doctor.gender if doctor is not None else None,
            department_id=department_id,
            department_name=department_name,
            start_at=start_at,
            end_at=end_at,
            slot_id=appointment.slot_id,
            status=appointment.status,
            created_at=appointment.created_at,
        )
