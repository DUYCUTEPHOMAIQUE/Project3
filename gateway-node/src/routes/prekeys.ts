import { Router } from 'express';
import { getPrekeyBundle } from '../handlers/prekeys';

const router = Router();

/**
 * GET /api/v1/devices/:device_id/prekey-bundle
 * Get prekey bundle for a device (used by Alice to initiate X3DH)
 */
router.get('/devices/:device_id/prekey-bundle', getPrekeyBundle);

export default router;

