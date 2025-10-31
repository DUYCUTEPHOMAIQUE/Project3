// In-memory storage for devices and prekeys
// TODO: Migrate to Postgres in Phase 3

import { DeviceInfo } from '../types/device';

class DeviceStorage {
  private devices: Map<string, DeviceInfo> = new Map();
  private deviceTokens: Map<string, string> = new Map(); // Map<device_id, token>

  /**
   * Register a new device
   */
  registerDevice(deviceInfo: DeviceInfo, token: string): void {
    this.devices.set(deviceInfo.device_id, deviceInfo);
    this.deviceTokens.set(deviceInfo.device_id, token);
  }

  /**
   * Get device info by device_id
   */
  getDevice(deviceId: string): DeviceInfo | undefined {
    return this.devices.get(deviceId);
  }

  /**
   * Verify registration token
   */
  verifyToken(deviceId: string, token: string): boolean {
    const storedToken = this.deviceTokens.get(deviceId);
    return storedToken === token;
  }

  /**
   * Get a one-time prekey for a device and remove it
   */
  takeOneTimePrekey(deviceId: string): { id: number; public_key: string } | null {
    const device = this.devices.get(deviceId);
    if (!device) {
      return null;
    }

    // Get first available one-time prekey
    const entries = Array.from(device.one_time_prekeys.entries());
    if (entries.length === 0) {
      return null;
    }

    const [id, public_key] = entries[0];
    device.one_time_prekeys.delete(id);

    return { id, public_key };
  }

  /**
   * Check if device has available one-time prekeys
   */
  hasOneTimePrekeys(deviceId: string): boolean {
    const device = this.devices.get(deviceId);
    if (!device) {
      return false;
    }
    return device.one_time_prekeys.size > 0;
  }

  /**
   * Get all devices for a user (if user_id is provided)
   */
  getUserDevices(userId?: string): DeviceInfo[] {
    if (!userId) {
      return Array.from(this.devices.values());
    }
    return Array.from(this.devices.values()).filter(
      (device) => device.user_id === userId
    );
  }

  /**
   * Delete a device
   */
  deleteDevice(deviceId: string): boolean {
    const deleted = this.devices.delete(deviceId);
    this.deviceTokens.delete(deviceId);
    return deleted;
  }

  /**
   * Get all devices (for debugging/admin)
   */
  getAllDevices(): DeviceInfo[] {
    return Array.from(this.devices.values());
  }
}

// Singleton instance
export const deviceStorage = new DeviceStorage();

