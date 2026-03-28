import { Timestamp } from 'firebase-admin/firestore';

/**
 * A swap request between two flat members.
 * Stored at flats/{flatId}/swapRequests/{requestId}.
 */
export enum SwapRequestStatus {
  Pending = 'pending',
  Accepted = 'accepted',
  Declined = 'declined',
}

export interface SwapRequest {
  id: string;
  requester_uid: string;
  target_task_id: string;
  requester_task_id: string;
  status: SwapRequestStatus;
  created_at: Timestamp;
}

export type SwapRequestData = Omit<SwapRequest, 'id'>;

export function swapRequestFromFirestore(
  id: string,
  data: FirebaseFirestore.DocumentData,
): SwapRequest {
  return {
    id,
    requester_uid: data['requester_uid'] ?? '',
    target_task_id: data['target_task_id'] ?? '',
    requester_task_id: data['requester_task_id'] ?? '',
    status: (data['status'] as SwapRequestStatus) ?? SwapRequestStatus.Pending,
    created_at: data['created_at'] as Timestamp,
  };
}
