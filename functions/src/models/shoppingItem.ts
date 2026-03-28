import { Timestamp } from 'firebase-admin/firestore';

/**
 * A shopping list item.
 * Stored at flats/{flatId}/shoppingItems/{itemId}.
 */
export interface ShoppingItem {
  id: string;
  text: string;
  added_by: string;
  is_bought: boolean;
  /** Null when not yet bought. Set when member marks as bought. */
  bought_at: Timestamp | null;
}

export type ShoppingItemData = Omit<ShoppingItem, 'id'>;

export function shoppingItemFromFirestore(
  id: string,
  data: FirebaseFirestore.DocumentData,
): ShoppingItem {
  return {
    id,
    text: data['text'] ?? '',
    added_by: data['added_by'] ?? '',
    is_bought: data['is_bought'] ?? false,
    bought_at: (data['bought_at'] as Timestamp) ?? null,
  };
}
