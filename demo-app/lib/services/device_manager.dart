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
      return true;
    }

    // Register device
    final registered = await _deviceService.generateAndRegisterDevice(deviceId);
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
