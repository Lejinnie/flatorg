"""ShoppingItem model: a single entry in the shared shopping list."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class ShoppingItem:
    """A shared shopping list item stored under /flats/{flatId}/shoppingItems."""

    id: str
    text: str
    added_by: str
    is_bought: bool
    # Set to the Firestore Timestamp when marked bought; empty string otherwise.
    bought_at: Any  # Firestore Timestamp or None


def shopping_item_from_firestore(doc_id: str, data: dict[str, Any]) -> ShoppingItem:
    """Convert a Firestore shoppingItems document dict to a typed ShoppingItem."""
    return ShoppingItem(
        id=doc_id,
        text=data.get("text", ""),
        added_by=data.get("added_by", ""),
        is_bought=data.get("is_bought", False),
        bought_at=data.get("bought_at"),
    )
