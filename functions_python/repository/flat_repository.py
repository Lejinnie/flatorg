"""Repository for Flat documents in the top-level 'flats' collection.

All Firestore access for flat settings goes through this class (Repository pattern).
"""

from __future__ import annotations

from typing import Any

from constants.strings import COLLECTION_FLATS, ERROR_FLAT_NOT_FOUND
from models.flat import Flat, flat_from_firestore


class FlatRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _flat_ref(self, flat_id: str) -> Any:
        return self._db.collection(COLLECTION_FLATS).document(flat_id)

    def get_flat(self, flat_id: str) -> Flat:
        """Fetch a flat by ID; raise ValueError if not found."""
        doc = self._flat_ref(flat_id).get()
        if not doc.exists:
            raise ValueError(f"{ERROR_FLAT_NOT_FOUND}: {flat_id}")
        return flat_from_firestore(doc.id, doc.to_dict())

    def get_flat_in_transaction(self, flat_id: str, transaction: Any) -> Flat:
        """Fetch a flat within a transaction; raise ValueError if not found."""
        doc = self._flat_ref(flat_id).get(transaction=transaction)
        if not doc.exists:
            raise ValueError(f"{ERROR_FLAT_NOT_FOUND}: {flat_id}")
        return flat_from_firestore(doc.id, doc.to_dict())

    def create_flat(self, flat_id: str, flat: Flat) -> None:
        """Create a new flat document."""
        self._flat_ref(flat_id).set(
            {
                "name": flat.name,
                "admin_uid": flat.admin_uid,
                "invite_code": flat.invite_code,
                "vacation_threshold_weeks": flat.vacation_threshold_weeks,
                "grace_period_hours": flat.grace_period_hours,
                "reminder_hours_before_deadline": flat.reminder_hours_before_deadline,
                "shopping_cleanup_hours": flat.shopping_cleanup_hours,
            }
        )

    def update_flat_settings(self, flat_id: str, updates: dict[str, Any]) -> None:
        """Update specific admin-configurable settings on a flat."""
        self._flat_ref(flat_id).update(updates)

    def update_flat_settings_in_transaction(self, flat_id: str, updates: dict[str, Any], transaction: Any) -> None:
        """Update specific flat fields within an existing Firestore transaction."""
        transaction.update(self._flat_ref(flat_id), updates)

    def find_flat_by_invite_code(self, invite_code: str) -> Flat | None:
        """Look up a flat by its invite code. Returns None when no match found."""
        snapshot = self._db.collection(COLLECTION_FLATS).where("invite_code", "==", invite_code).limit(1).stream()
        docs = list(snapshot)
        if not docs:
            return None
        return flat_from_firestore(docs[0].id, docs[0].to_dict())
