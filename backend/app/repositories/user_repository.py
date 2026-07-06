from __future__ import annotations

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.models.common import UserRole
from app.models.user import UserAccount

_users: dict[str, UserAccount] = {}


class UserRepository:
    def get_by_uid(self, uid: str) -> UserAccount | None:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            snapshot = client.collection(settings.firestore_users_collection).document(uid).get()
            if not snapshot.exists:
                return None
            return UserAccount.model_validate({"uid": snapshot.id, **(snapshot.to_dict() or {})})

        return _users.get(uid)

    def list(self) -> list[UserAccount]:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            return [
                UserAccount.model_validate({"uid": item.id, **(item.to_dict() or {})})
                for item in client.collection(settings.firestore_users_collection).stream()
            ]

        return list(_users.values())

    def search_by_email(self, query: str) -> list[UserAccount]:
        lowered = query.strip().lower()
        if len(lowered) < 3:
            return []
        return [
            user
            for user in self.list()
            if lowered in user.email.lower()
        ]

    def upsert(self, user: UserAccount) -> UserAccount:
        settings = get_settings()
        client = get_firestore_client()
        if client is not None:
            client.collection(settings.firestore_users_collection).document(user.uid).set(
                user.model_dump(exclude={"uid"}, mode="python")
            )
            return user

        _users[user.uid] = user
        return user

    def set_status(self, uid: str, status: str) -> UserAccount | None:
        existing = self.get_by_uid(uid)
        if existing is None:
            return None

        updated = existing.model_copy(update={"status": status})
        return self.upsert(updated)

    def create_default_from_auth(
        self,
        uid: str,
        email: str,
        role: UserRole = UserRole.PATIENT,
    ) -> UserAccount:
        return self.upsert(UserAccount(uid=uid, email=email, role=role))
