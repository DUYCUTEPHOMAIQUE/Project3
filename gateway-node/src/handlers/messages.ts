import { Request, Response, NextFunction } from 'express';
import { messageStorage } from '../storage/messageStorage';

export interface SendMessageRequest {
  recipient_device_id: string;
  sender_device_id?: string;
  message_type?: string;
  ciphertext: string; // base64 or hex; server is agnostic
}

export async function postMessage(
  req: Request<{}, any, SendMessageRequest>,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { recipient_device_id, sender_device_id, message_type, ciphertext } = req.body || {};

    if (!recipient_device_id || typeof recipient_device_id !== 'string') {
      res.status(400).json({ error: 'recipient_device_id is required' });
      return;
    }
    if (!ciphertext || typeof ciphertext !== 'string') {
      res.status(400).json({ error: 'ciphertext is required' });
      return;
    }

    const saved = messageStorage.enqueue(recipient_device_id, {
      recipient_device_id,
      sender_device_id,
      message_type,
      ciphertext,
    });

    res.status(202).json({ id: saved.id, timestamp: saved.timestamp });
  } catch (err) {
    next(err);
  }
}

export async function getMessages(
  req: Request<{ device_id: string }>,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { device_id } = req.params;
    if (!device_id) {
      res.status(400).json({ error: 'device_id is required' });
      return;
    }

    // Return and remove queued messages
    const messages = messageStorage.dequeueAll(device_id);
    res.json({ device_id, messages });
  } catch (err) {
    next(err);
  }
}


