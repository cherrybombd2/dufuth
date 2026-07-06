from datetime import UTC, datetime, timedelta

from app.models.appointment import Appointment, AppointmentStatus
from app.models.availability_slot import AvailabilitySlot, SlotStatus
from app.models.doctor import Doctor
from app.models.department import Department
from app.models.doctor_alert import DoctorAlert
from app.models.faq import FaqItem
from app.models.reminder import Reminder
from app.models.patient import Patient
from app.models.user import UserAccount
from app.models.common import UserRole

users: list[UserAccount] = [
    UserAccount(
        uid="patient_1",
        email="amina@example.com",
        role=UserRole.PATIENT,
    )
]

patients: list[Patient] = [
    Patient(
        user_id="patient_1",
        full_name="Amina Yusuf",
        phone_number="+2348000000001",
    )
]

doctors: list[Doctor] = [
    Doctor(
        user_id="doctor_1",
        full_name="Dr. Tobi Adeyemi",
        department_id="General Medicine",
    ),
    Doctor(
        user_id="doctor_2",
        full_name="Dr. Chika Okafor",
        department_id="Cardiology",
    ),
]

departments: list[Department] = [
    Department(
        name="General Medicine",
        description="General consultations and routine patient care.",
        icon_key="medical_services",
    ),
    Department(
        name="Cardiology",
        description="Heart and cardiovascular care.",
        icon_key="favorite",
    ),
]

appointments: list[Appointment] = [
    Appointment(
        id="appt_1",
        patient_id="patient_1",
        doctor_id="doctor_1",
        department="General Medicine",
        scheduled_for=datetime.now(UTC) + timedelta(days=1),
        status=AppointmentStatus.BOOKED,
    )
]

reminders: list[Reminder] = []
doctor_alerts: list[DoctorAlert] = []

availability_slots: list[AvailabilitySlot] = [
    AvailabilitySlot(
        id="slot_1",
        department_id="General Medicine",
        department_name="General Medicine",
        doctor_id="doctor_1",
        doctor_name="Dr. Tobi Adeyemi",
        start_at=datetime.now(UTC) + timedelta(days=1, hours=9),
        end_at=datetime.now(UTC) + timedelta(days=1, hours=10),
        status=SlotStatus.AVAILABLE,
    ),
    AvailabilitySlot(
        id="slot_2",
        department_id="Cardiology",
        department_name="Cardiology",
        doctor_id="doctor_2",
        doctor_name="Dr. Chika Okafor",
        start_at=datetime.now(UTC) + timedelta(days=2, hours=11),
        end_at=datetime.now(UTC) + timedelta(days=2, hours=12),
        status=SlotStatus.BLOCKED,
    ),
]

faq_items: list[FaqItem] = [
    FaqItem(
        id="faq_1",
        question="How do I book an appointment?",
        answer="Open Appointments, choose a department and doctor, then select an available time slot.",
        category="Appointments",
        sort_order=1,
    ),
    FaqItem(
        id="faq_2",
        question="Can I cancel an appointment?",
        answer="Yes. Open your appointments list and cancel any upcoming appointment before the scheduled time.",
        category="Appointments",
        sort_order=2,
    ),
]

hospital_info: dict[str, str] = {
    "hospital_name": "DUFUTH SmartCare",
    "tagline": "Excellence in Health Care",
    "address": "David Umahi Federal University Teaching Hospital",
    "phone": "Not provided yet",
    "email": "Not provided yet",
    "working_hours": "Monday - Friday, 8:00 AM - 4:00 PM",
    "visiting_hours": "Not provided yet",
    "website": "Not provided yet",
    "about": "Hospital background and patient-facing information will appear here.",
    "patient_notice": "Please arrive early for your appointment and bring any relevant medical documents.",
}
