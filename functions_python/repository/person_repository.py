"""Repository for Person documents under flats/{flatId}/members.

All Firestore access for members goes through this class (Repository pattern).
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import Client, Transaction

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_MEMBERS,
    ERROR_PERSON_NOT_FOUND,
)
from constants.task_constants import SWAP_TOKENS_PER_SEMESTER
from models.person import Person, person_from_firestore, person_to_firestore


class PersonRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _member_ref(self, flat_id: str, uid: str):
        return (
            self._db.collection(COLLECTION_FLATS)
            .document(flat_id)
            .collection(COLLECTION_MEMBERS)
            .document(uid)
        )

    def _members_collection(self, flat_id: str):
        return (
            self._db.collection(COLLECTION_FLATS)
            .document(flat_id)
            .collection(COLLECTION_MEMBERS)
        )

    def get_all_members(self, flat_id: str) -> list[Person]:
        """Fetch all members of a flat."""
        snapshot = self._members_collection(flat_id).stream()
        return [person_from_firestore(doc.id, doc.to_dict()) for doc in snapshot]

    def get_all_members_in_transaction(
        self, flat_id: str, transaction: Any
    ) -> list[Person]:
        """Fetch all members within a transaction."""
        docs = transaction.get(self._members_collection(flat_id))
        return [person_from_firestore(doc.id, doc.to_dict()) for doc in docs]

    def get_member(self, flat_id: str, uid: str) -> Person:
        """Fetch a single member by UID; raise ValueError if not found."""
        doc = self._member_ref(flat_id, uid).get()
        if not doc.exists:
            raise ValueError(f"{ERROR_PERSON_NOT_FOUND}: {uid}")
        return person_from_firestore(doc.id, doc.to_dict())

    def update_member(self, flat_id: str, uid: str, updates: dict) -> None:
        """Update specific fields on a member document."""
        self._member_ref(flat_id, uid).update(updates)

    def update_member_in_transaction(
        self, flat_id: str, uid: str, updates: dict, transaction: Any
    ) -> None:
        """Update specific fields on a member document within a transaction."""
        transaction.update(self._member_ref(flat_id, uid), updates)

    def create_member(self, flat_id: str, person: Person) -> None:
        """Create a new member document."""
        self._member_ref(flat_id, person.uid).set(person_to_firestore(person))

    def set_vacation(self, flat_id: str, uid: str, on_vacation: bool) -> None:
        """Set the vacation status for a member.

        Takes effect on the next week_reset() if set before it fires.
        """
        self.update_member(flat_id, uid, {"on_vacation": on_vacation})

    def reset_all_swap_tokens(self, flat_id: str) -> None:
        """Reset swap_tokens_remaining to SWAP_TOKENS_PER_SEMESTER for all members.

        Called by the token-reset Cloud Function at each ETH semester start.
        """
        members = self.get_all_members(flat_id)
        batch = self._db.batch()
        for member in members:
            batch.update(
                self._member_ref(flat_id, member.uid),
                {"swap_tokens_remaining": SWAP_TOKENS_PER_SEMESTER},
            )
        batch.commit()
