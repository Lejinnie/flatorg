"""Person model: a flat member mapped to a Firebase Auth user."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Any


class PersonRole(StrEnum):
    """Access role within a flat."""

    Admin = "admin"
    Member = "member"


@dataclass
class Person:
    """A flat member. Corresponds to a Firebase Auth user and a Firestore members document."""

    # Firebase Auth user ID (primary key).
    uid: str
    # Display name.
    name: str
    # Used for login.
    email: str
    # Access role — drives UI permissions.
    role: PersonRole
    # True when the member has marked themselves as on vacation.
    on_vacation: bool
    # Resets to SWAP_TOKENS_PER_SEMESTER at the start of each ETH semester.
    swap_tokens_remaining: int


def person_from_firestore(doc_id: str, data: dict[str, Any]) -> Person:
    """Convert a Firestore members document dict to a typed Person."""
    return Person(
        uid=doc_id,
        name=data.get("name", ""),
        email=data.get("email", ""),
        role=PersonRole(data.get("role", PersonRole.Member)),
        on_vacation=data.get("on_vacation", False),
        swap_tokens_remaining=data.get("swap_tokens_remaining", 0),
    )


def person_to_firestore(person: Person) -> dict[str, Any]:
    """Convert a Person to a plain Firestore-compatible dict (excludes uid)."""
    return {
        "name": person.name,
        "email": person.email,
        "role": person.role.value,
        "on_vacation": person.on_vacation,
        "swap_tokens_remaining": person.swap_tokens_remaining,
    }
