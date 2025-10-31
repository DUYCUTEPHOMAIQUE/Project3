import { Router } from 'express';
import { registerDevice } from '../handlers/register';

const router = Router();

/**
 * POST /api/v1/devices/register
 * Register a new device with identity key, signed prekey, and one-time prekeys
 */
router.post('/devices/register', registerDevice);

export default router;

