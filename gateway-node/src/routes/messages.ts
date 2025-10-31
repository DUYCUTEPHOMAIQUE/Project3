import { Router } from 'express';
import { postMessage, getMessages } from '../handlers/messages';

const router = Router();

/**
 * POST /api/v1/messages
 * Body: { recipient_device_id, sender_device_id?, message_type?, ciphertext }
 */
router.post('/messages', postMessage);

/**
 * GET /api/v1/devices/:device_id/messages
 * Returns and removes queued messages for the device
 */
router.get('/devices/:device_id/messages', getMessages);

export default router;


