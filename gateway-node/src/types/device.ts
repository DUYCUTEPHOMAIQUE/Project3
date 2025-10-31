// Device registration types

export interface DeviceRegistrationRequest {
  device_id: string;
  user_id?: string; // Optional user identifier
  identity_public_key: string; // Hex-encoded X25519 public key (64 chars)
  signed_prekey: {
    id: number;
    public_key: string; // Hex-encoded X25519 public key (64 chars)
    signature: string; // Hex-encoded Ed25519 signature (128 chars)
    timestamp: number; // Unix timestamp
  };
  prekeys: Array<{
    id: number;
    public_key: string; // Hex-encoded X25519 public key (64 chars)
  }>;
}

export interface DeviceRegistrationResponse {
  device_id: string;
  registration_token: string;
  timestamp: number;
}

export interface DeviceInfo {
  device_id: string;
  user_id?: string;
  identity_public_key: string;
  signed_prekey: {
    id: number;
    public_key: string;
    signature: string;
    timestamp: number;
  };
  one_time_prekeys: Map<number, string>; // Map<prekey_id, public_key>
  registered_at: number;
}

export interface PreKeyBundleResponse {
  identity_key: string;
  signed_prekey: {
    id: number;
    public_key: string;
    signature: string;
    timestamp: number;
  };
  one_time_prekey?: {
    id: number;
    public_key: string;
  };
}

