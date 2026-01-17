import 'dart:io';
import 'device_service.dart';
import 'token_storage.dart';

/// Manages device registration and ensures device is registered for chat
class DeviceManager {
  final DeviceService _deviceService;
  final TokenStorage _tokenStorage;

  DeviceManager({
    DeviceService? deviceService,
    TokenStorage? tokenStorage,
  })  : _deviceService = deviceService ?? DeviceService(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// Ensure device is registered for the current user
  /// Returns true if device is ready, false otherwise
  Future<bool> ensureDeviceRegistered() async {
    final userId = await _tokenStorage.getUserID();
    if (userId == null || userId.isEmpty) {
      return false;
    }

    // Generate device ID based on user ID and platform
    final deviceId = _generateDeviceId(userId);
    
    // Check if device already exists
    final exists = await _deviceService.deviceExists(deviceId);
    if (exists) {
      // Check if identity key is stored (required for session creation)
      final identityKey = await _tokenStorage.getIdentityKeyPair();
      if (identityKey == null || identityKey.isEmpty) {
        print('[DeviceManager] ⚠️  Device exists but identity key missing, deleting and re-registering...');
        // Device exists but identity key missing - need to delete and re-register
        // This can happen if identity key was cleared but device still registered
        // We can't recover the old identity key (it's private), so we must delete and re-register
        final deleted = await _deviceService.deleteDevice(deviceId);
        if (!deleted) {
          print('[DeviceManager] ❌ Failed to delete existing device');
          return false;
        }
        print('[DeviceManager] ✅ Deleted existing device, now re-registering...');
        final registered = await _deviceService.generateAndRegisterDevice(deviceId);
        return registered != null;
      }
      print('[DeviceManager] ✅ Device exists and identity key is stored');
      return true;
    }

    // Register device
    print('[DeviceManager] 🔐 Registering new device...');
    final registered = await _deviceService.generateAndRegisterDevice(deviceId);
    if (registered != null) {
      // Verify identity key was saved
      final identityKey = await _tokenStorage.getIdentityKeyPair();
      if (identityKey == null || identityKey.isEmpty) {
        print('[DeviceManager] ❌ Device registered but identity key not saved!');
        return false;
      }
      print('[DeviceManager] ✅ Device registered and identity key saved');
    }
    return registered != null;
  }

  /// Generate device ID for current user
  String _generateDeviceId(String userId) {
    final platform = Platform.operatingSystem;
    return '$userId-$platform';
  }

  /// Get current device ID
  Future<String?> getCurrentDeviceId() async {
    final userId = await _tokenStorage.getUserID();
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return _generateDeviceId(userId);
  }
}
