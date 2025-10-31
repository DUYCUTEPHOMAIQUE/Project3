// In-memory message queues per device

export interface QueuedMessage {
  id: string;
  recipient_device_id: string;
  sender_device_id?: string;
  message_type?: string;
  ciphertext: string; // Opaque to the server
  timestamp: number;
}

class MessageStorage {
  private queues: Map<string, QueuedMessage[]> = new Map();

  enqueue(recipientDeviceId: string, msg: Omit<QueuedMessage, 'id' | 'timestamp'>): QueuedMessage {
    const full: QueuedMessage = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`,
      timestamp: Date.now(),
      recipient_device_id: recipientDeviceId,
      sender_device_id: msg.sender_device_id,
      message_type: msg.message_type,
      ciphertext: msg.ciphertext,
    };

    const q = this.queues.get(recipientDeviceId) || [];
    q.push(full);
    this.queues.set(recipientDeviceId, q);
    return full;
  }

  dequeueAll(recipientDeviceId: string): QueuedMessage[] {
    const q = this.queues.get(recipientDeviceId) || [];
    this.queues.set(recipientDeviceId, []);
    return q;
  }

  peek(recipientDeviceId: string): QueuedMessage[] {
    return [...(this.queues.get(recipientDeviceId) || [])];
  }
}

export const messageStorage = new MessageStorage();


