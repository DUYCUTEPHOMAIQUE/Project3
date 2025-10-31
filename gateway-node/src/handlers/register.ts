import { Request, Response, NextFunction } from 'express';
import { DeviceRegistrationRequest, DeviceRegistrationResponse } from '../types/device';
import { deviceStorage } from '../storage/deviceStorage';
import crypto from 'crypto';

/**
 * Generate a registration token for a device
 */
function generateRegistrationToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Validate device registration request
 */
function validateRegistrationRequest(req: DeviceRegistrationRequest): string | null {
  if (!req.device_id || typeof req.device_id !== 'string') {
    return 'device_id is required and must be a string';
  }

  if (!req.identity_public_key || typeof req.identity_public_key !== 'string') {
    return 'identity_public_key is required and must be a string';
  }

  // Validate hex format (64 chars for 32 bytes)
  if (!/^[0-9a-f]{64}$/i.test(req.identity_public_key)) {
    return 'identity_public_key must be a valid hex string (64 characters)';
  }

  if (!req.signed_prekey) {
    return 'signed_prekey is required';
  }

  if (typeof req.signed_prekey.id !== 'number') {
    return 'signed_prekey.id must be a number';
  }

  if (!req.signed_prekey.public_key || typeof req.signed_prekey.public_key !== 'string') {
    return 'signed_prekey.public_key is required and must be a string';
  }

  if (!/^[0-9a-f]{64}$/i.test(req.signed_prekey.public_key)) {
    return 'signed_prekey.public_key must be a valid hex string (64 characters)';
  }

  if (!req.signed_prekey.signature || typeof req.signed_prekey.signature !== 'string') {
    return 'signed_prekey.signature is required and must be a string';
  }

  if (!/^[0-9a-f]{128}$/i.test(req.signed_prekey.signature)) {
    return 'signed_prekey.signature must be a valid hex string (128 characters)';
  }

  if (!req.prekeys || !Array.isArray(req.prekeys)) {
    return 'prekeys is required and must be an array';
  }

  if (req.prekeys.length === 0) {
    return 'prekeys must contain at least one prekey';
  }

  // Validate each prekey
  for (const prekey of req.prekeys) {
    if (typeof prekey.id !== 'number') {
      return 'Each prekey.id must be a number';
    }
    if (!prekey.public_key || typeof prekey.public_key !== 'string') {
      return 'Each prekey.public_key is required and must be a string';
    }
    if (!/^[0-9a-f]{64}$/i.test(prekey.public_key)) {
      return 'Each prekey.public_key must be a valid hex string (64 characters)';
    }
  }

  return null;
}

/**
 * Register device handler
 */
export async function registerDevice(
  req: Request<{}, DeviceRegistrationResponse, DeviceRegistrationRequest>,
  res: Response<DeviceRegistrationResponse | { error: string }>,
  next: NextFunction
): Promise<void> {
  try {
    // Validate request
    const validationError = validateRegistrationRequest(req.body);
    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }

    const { device_id, user_id, identity_public_key, signed_prekey, prekeys } = req.body;

    // Check if device already exists
    const existingDevice = deviceStorage.getDevice(device_id);
    if (existingDevice) {
      res.status(409).json({ error: 'Device already registered' });
      return;
    }

    // Convert prekeys array to Map
    const oneTimePrekeysMap = new Map<number, string>();
    for (const prekey of prekeys) {
      oneTimePrekeysMap.set(prekey.id, prekey.public_key);
    }

    // Create device info
    const deviceInfo = {
      device_id,
      user_id,
      identity_public_key,
      signed_prekey: {
        id: signed_prekey.id,
        public_key: signed_prekey.public_key,
        signature: signed_prekey.signature,
        timestamp: signed_prekey.timestamp,
      },
      one_time_prekeys: oneTimePrekeysMap,
      registered_at: Date.now(),
    };

    // Generate registration token
    const registrationToken = generateRegistrationToken();

    // Store device
    deviceStorage.registerDevice(deviceInfo, registrationToken);

    // Return response
    const response: DeviceRegistrationResponse = {
      device_id,
      registration_token: registrationToken,
      timestamp: Date.now(),
    };

    res.status(201).json(response);
  } catch (error) {
    next(error);
  }
}

