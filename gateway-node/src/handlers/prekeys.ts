import { Request, Response, NextFunction } from 'express';
import { PreKeyBundleResponse } from '../types/device';
import { deviceStorage } from '../storage/deviceStorage';

/**
 * Get prekey bundle handler
 * GET /api/v1/devices/:device_id/prekey-bundle
 */
export async function getPrekeyBundle(
  req: Request<{ device_id: string }>,
  res: Response<PreKeyBundleResponse | { error: string }>,
  next: NextFunction
): Promise<void> {
  try {
    const { device_id } = req.params;

    if (!device_id) {
      res.status(400).json({ error: 'device_id is required' });
      return;
    }

    // Get device info
    const device = deviceStorage.getDevice(device_id);
    if (!device) {
      res.status(404).json({ error: 'Device not found' });
      return;
    }

    // Try to get a one-time prekey (preferred but optional)
    const oneTimePrekey = deviceStorage.takeOneTimePrekey(device_id);

    // Check if device has available one-time prekeys
    // If no one-time prekeys available, we can still return bundle but warn
    // According to X3DH spec, one-time prekey is optional but recommended
    if (!oneTimePrekey && !deviceStorage.hasOneTimePrekeys(device_id)) {
      // Log warning but don't fail - signed prekey can be used
      console.warn(`Device ${device_id} has no available one-time prekeys`);
    }

    // Build prekey bundle response
    const bundle: PreKeyBundleResponse = {
      identity_key: device.identity_public_key,
      signed_prekey: {
        id: device.signed_prekey.id,
        public_key: device.signed_prekey.public_key,
        signature: device.signed_prekey.signature,
        timestamp: device.signed_prekey.timestamp,
      },
    };

    // Add one-time prekey if available
    if (oneTimePrekey) {
      bundle.one_time_prekey = {
        id: oneTimePrekey.id,
        public_key: oneTimePrekey.public_key,
      };
    }

    res.json(bundle);
  } catch (error) {
    next(error);
  }
}

