from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.faq import FaqItem
from app.repositories.faq_repository import FaqRepository
from app.schemas.faq import FaqItemCreate, FaqItemUpdate


@dataclass(frozen=True, slots=True)
class SeedFaq:
    question: str
    answer: str
    sort_order: int
    category: str | None = None
    is_active: bool = True


SEED_FAQS: list[SeedFaq] = [
    SeedFaq(
        question="How do I book an appointment?",
        answer=(
            "Open the booking section, choose a department, select a doctor, "
            "pick an available date and time, then confirm your appointment."
        ),
        sort_order=1,
    ),
    SeedFaq(
        question="How do I reschedule my appointment?",
        answer=(
            "Go to the Appointments section, open your upcoming appointment, "
            "and choose the reschedule option to pick a new available date and time."
        ),
        sort_order=2,
    ),
    SeedFaq(
        question="How do I cancel an appointment?",
        answer=(
            "Open the Appointments section, select your upcoming appointment, "
            "tap Cancel, and confirm your choice when asked."
        ),
        sort_order=3,
    ),
    SeedFaq(
        question="Why can't I see some time slots?",
        answer=(
            "Only future available time slots are shown in the app. "
            "Past time slots and unavailable slots are removed automatically."
        ),
        sort_order=4,
    ),
    SeedFaq(
        question="Where can I see my upcoming appointments?",
        answer=(
            "You can view your upcoming appointments from the Home page or "
            "in the Appointments section of the app."
        ),
        sort_order=5,
    ),
    SeedFaq(
        question="Where can I find my reminders?",
        answer=(
            "Appointment reminders appear in the Reminders section, where you can "
            "review, mark them as read, or dismiss them."
        ),
        sort_order=6,
    ),
    SeedFaq(
        question="What happens after I cancel an appointment?",
        answer=(
            "Once your appointment is cancelled, it is removed from your active "
            "upcoming list and the time slot becomes available again if the "
            "hospital allows rebooking."
        ),
        sort_order=7,
    ),
    SeedFaq(
        question="Where can I find the hospital's contact details?",
        answer=(
            "You can check the Hospital Info page to see the hospital's phone number, "
            "email address, working hours, visiting hours, address, and other "
            "available details."
        ),
        sort_order=8,
    ),
    SeedFaq(
        question="What should I do if I forget my password?",
        answer=(
            "Tap the Forgot Password option on the sign-in screen and follow the "
            "instructions sent to your email to reset your password."
        ),
        sort_order=9,
    ),
    SeedFaq(
        question="What do the appointment statuses mean?",
        answer=(
            "Upcoming means your appointment is still ahead, Past means the "
            "appointment time has already passed, and Cancelled means the "
            "appointment will no longer take place."
        ),
        sort_order=10,
    ),
]


def normalize_text(value: str) -> str:
    collapsed = re.sub(r"\s+", " ", value.strip().lower())
    return re.sub(r"[^a-z0-9 ]+", "", collapsed)


def similarity_score(left: str, right: str) -> float:
    return SequenceMatcher(a=normalize_text(left), b=normalize_text(right)).ratio()


def find_best_existing_match(
    seed: SeedFaq,
    existing_items: list[FaqItem],
    used_ids: set[str],
) -> FaqItem | None:
    normalized_question = normalize_text(seed.question)

    for item in existing_items:
        if item.id in used_ids:
            continue
        if normalize_text(item.question) == normalized_question:
            return item

    ranked_candidates: list[tuple[float, FaqItem]] = []
    for item in existing_items:
        if item.id in used_ids:
            continue
        score = similarity_score(seed.question, item.question)
        if score >= 0.74:
            ranked_candidates.append((score, item))

    if not ranked_candidates:
        return None

    ranked_candidates.sort(key=lambda pair: pair[0], reverse=True)
    return ranked_candidates[0][1]


def faq_matches_seed(item: FaqItem, seed: SeedFaq) -> bool:
    return (
        item.question == seed.question
        and item.answer == seed.answer
        and item.category == seed.category
        and item.sort_order == seed.sort_order
        and item.is_active == seed.is_active
    )


def main() -> int:
    settings = get_settings()
    firestore_client = get_firestore_client()
    if firestore_client is None:
        print(
            "Firestore is not enabled or Firebase Admin is not configured. "
            "This script seeds the real FAQ database only."
        )
        print(
            "Check backend/.env and ensure USE_FIRESTORE=true plus valid "
            "Firebase project credentials before running."
        )
        return 1

    repository = FaqRepository()
    existing_items = repository.list(include_inactive=True)
    used_ids: set[str] = set()

    created = 0
    updated = 0
    skipped = 0

    print(
        f"Seeding FAQ items into collection "
        f"'{settings.firestore_faq_items_collection}'..."
    )

    for seed in SEED_FAQS:
        existing = find_best_existing_match(seed, existing_items, used_ids)

        if existing is None:
            repository.create(
                FaqItemCreate(
                    question=seed.question,
                    answer=seed.answer,
                    category=seed.category,
                    sort_order=seed.sort_order,
                    is_active=seed.is_active,
                )
            )
            created += 1
            print(f"[created] {seed.question}")
            continue

        used_ids.add(existing.id)
        if faq_matches_seed(existing, seed):
            skipped += 1
            print(f"[skipped] {seed.question}")
            continue

        repository.update(
            existing.id,
            FaqItemUpdate(
                question=seed.question,
                answer=seed.answer,
                category=seed.category,
                sort_order=seed.sort_order,
                is_active=seed.is_active,
            ),
        )
        updated += 1
        print(f"[updated] {seed.question}")

    print()
    print("FAQ seeding complete.")
    print(f"Created: {created}")
    print(f"Updated: {updated}")
    print(f"Skipped: {skipped}")
    print(f"Collection: {settings.firestore_faq_items_collection}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
