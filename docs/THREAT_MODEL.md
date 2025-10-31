# Threat Model Document

## Document Information

**Version**: 1.0  
**Date**: 2024-12-XX  
**Status**: Draft  
**Review Schedule**: Quarterly review, update after major changes

---

## Executive Summary

Tài liệu này mô tả threat model cho nền tảng E2EE, bao gồm các threats, attack vectors, và mitigation strategies. Threat model này được sử dụng để:
- Identify security risks
- Prioritize security controls
- Guide security testing
- Inform architecture decisions

---

## System Overview

### Components

1. **Client SDKs** (iOS, Android, Desktop, IoT)
   - Key generation và storage
   - X3DH key agreement
   - Double Ratchet message encryption
   - Session management

2. **E2EE Gateway**
   - Device registration
   - Prekey bundle distribution
   - Message relay
   - Metadata storage

3. **Key Directory**
   - Prekey inventory management
   - Device key storage (public keys only)

4. **Broker** (Kafka/NATS)
   - Message queue
   - Delivery guarantee

5. **Blob Storage** (S3)
   - Encrypted backups (client-side encrypted)

### Data Flows

1. **Key Agreement Flow**:
   - Bob publishes keys → Server
   - Alice fetches prekey bundle → Server
   - Alice sends initial message → Bob (via Server)

2. **Message Exchange Flow**:
   - Alice encrypts message → Gateway → Broker → Bob
   - Bob decrypts message

3. **Device Linking Flow**:
   - Primary device generates QR → New device scans → Approval → Sync

---

## Security Assumptions

### Trusted Components

1. **Hardware Security Modules**:
   - iOS Secure Enclave (hardware-backed)
   - Android Keystore (hardware-backed when available)
   - Trusted execution environment

2. **Cryptographic Libraries**:
   - Well-audited libraries (ring, x25519-dalek, ed25519-dalek)
   - Proper random number generation

3. **Transport Layer**:
   - TLS 1.3 for all communications
   - Certificate pinning (future)

### Untrusted Components

1. **Server**:
   - Server không thể decrypt messages
   - Server không có access đến private keys
   - Server chỉ relay ciphertext và public keys

2. **Network**:
   - Network có thể bị monitored
   - Network có thể bị compromised (MITM attacks)

3. **Client Device**:
   - Device có thể bị compromised
   - Device có thể bị lost/stolen

---

## Threat Categories

### T1: Man-in-the-Middle (MITM) Attacks

**Description**: Attacker intercepts và modifies communication giữa client và server, hoặc giữa 2 clients.

**Attack Vectors**:
- Compromise network infrastructure
- DNS hijacking
- Certificate authority compromise
- Fake gateway/server

**Impact**: 
- High - Could intercept messages, impersonate users
- Could perform key exchange attacks

**Mitigation Strategies**:
1. **TLS 1.3**: Encrypt all transport layer communications
2. **Certificate Pinning**: Pin server certificates (future)
3. **Public Key Verification**: Users verify identity keys (fingerprints)
4. **Signed Prekeys**: Ed25519 signatures ensure authenticity
5. **Forward Secrecy**: Double Ratchet ensures past messages cannot be decrypted

**Risk Level**: Medium (mitigated by TLS và key verification)

---

### T2: Key Compromise

**Description**: Attacker gains access to private keys (identity key, prekeys, session keys).

**Attack Vectors**:
- Device compromise (malware, physical access)
- Keystore compromise (software bugs, side-channel attacks)
- Key extraction từ memory dumps
- Social engineering để obtain keys

**Impact**:
- Critical - Complete compromise of user's security
- Could decrypt all messages
- Could impersonate user

**Mitigation Strategies**:
1. **Hardware-Backed Keystores**: Use Secure Enclave / Android Keystore
2. **No Key Export**: Private keys never leave secure storage
3. **Key Rotation**: Rotate signed prekeys periodically
4. **One-Time Prekeys**: Consume after use, prevent replay
5. **Forward Secrecy**: Double Ratchet limits damage (only future messages)
6. **Break-in Recovery**: Past messages cannot be decrypted after compromise

**Risk Level**: High (mitigated by hardware security và forward secrecy)

---

### T3: Device Loss/Theft

**Description**: User's device bị lost hoặc stolen, attacker có physical access.

**Attack Vectors**:
- Physical theft
- Lost device
- Unauthorized access khi device unlocked

**Impact**:
- High - Access to all sessions và keys on device
- Could decrypt messages nếu device unlocked

**Mitigation Strategies**:
1. **Device Lock**: Require PIN/password/biometric
2. **Secure Enclave**: Keys stored in hardware, require authentication
3. **Remote Wipe**: Ability to revoke device và delete keys
4. **Registration Lock**: Prevent unauthorized device registration
5. **Session Timeout**: Auto-logout after inactivity
6. **No Plaintext Storage**: All sensitive data encrypted at rest

**Risk Level**: Medium (mitigated by device security features)

---

### T4: Metadata Leakage

**Description**: Attacker learns information about communication patterns without decrypting messages.

**Attack Vectors**:
- Network traffic analysis
- Server logs
- Timing analysis
- Message size analysis

**Impact**:
- Medium - Privacy violation
- Could reveal communication patterns
- Could reveal social graph

**Mitigation Strategies**:
1. **Minimize Metadata**: Store only necessary information
2. **Encrypt Metadata**: Encrypt metadata fields when possible
3. **Padding**: Add padding to messages để hide size (future)
4. **Mixnet**: Consider mixnet for high-privacy scenarios (future)
5. **No Content Logging**: Server logs không contain message content
6. **Rate Limiting**: Prevent timing attacks

**Risk Level**: Medium (partial mitigation, trade-off với functionality)

---

### T5: Prekey Exhaustion

**Description**: Attacker consumes all one-time prekeys, preventing new sessions.

**Attack Vectors**:
- Repeated prekey bundle requests
- Automated attacks to drain prekey inventory

**Impact**:
- Low-Medium - Denial of service
- Users cannot establish new sessions

**Mitigation Strategies**:
1. **Prekey Replenishment**: Auto-generate và upload new prekeys
2. **Rate Limiting**: Limit prekey bundle requests per device/IP
3. **Monitoring**: Alert when prekey inventory low
4. **Fallback**: Use signed prekey nếu no one-time prekeys available

**Risk Level**: Low (mitigated by auto-replenishment)

---

### T6: Denial of Service (DoS)

**Description**: Attacker prevents legitimate users from using service.

**Attack Vectors**:
- Overwhelm server with requests
- Consume resources (prekeys, storage)
- Network flooding

**Impact**:
- Medium - Service unavailability
- Degraded user experience

**Mitigation Strategies**:
1. **Rate Limiting**: Limit requests per device/IP
2. **Resource Limits**: Cap resource usage per user
3. **Load Balancing**: Distribute load across servers
4. **Monitoring**: Detect và mitigate attacks
5. **Graceful Degradation**: Service continues with reduced functionality

**Risk Level**: Medium (mitigated by rate limiting và monitoring)

---

### T7: Quantum Computing Attacks

**Description**: Future quantum computers could break ECC cryptography.

**Attack Vectors**:
- Quantum algorithm (Shor's algorithm) breaks X25519
- Could decrypt historical messages

**Impact**:
- Future threat - Critical if realized

**Mitigation Strategies**:
1. **PQXDH**: Post-quantum X3DH (future enhancement)
2. **Hybrid Keys**: Combine ECC và post-quantum KEM
3. **Key Rotation**: Rotate keys regularly
4. **Forward Secrecy**: Limits damage to future messages

**Risk Level**: Low (future threat, mitigated by PQXDH plan)

---

### T8: Side-Channel Attacks

**Description**: Attacker learns keys through timing, power consumption, or other side channels.

**Attack Vectors**:
- Timing attacks on crypto operations
- Power analysis
- Cache attacks
- Spectre/Meltdown vulnerabilities

**Impact**:
- High - Could reveal private keys

**Mitigation Strategies**:
1. **Constant-Time Operations**: Use constant-time crypto implementations
2. **Hardware Security**: Use hardware-backed keystores
3. **Library Selection**: Use well-audited libraries (ring)
4. **Code Audits**: Regular security audits

**Risk Level**: Medium (mitigated by using proven libraries)

---

### T9: Social Engineering

**Description**: Attacker tricks user into revealing keys or compromising security.

**Attack Vectors**:
- Phishing attacks
- Fake apps
- Malicious QR codes
- Social engineering để obtain backup passwords

**Impact**:
- High - Could lead to complete compromise

**Mitigation Strategies**:
1. **User Education**: Clear warnings về security
2. **Device Verification**: Users verify device fingerprints
3. **QR Code Verification**: Visual verification of QR codes
4. **Backup Password**: Strong backup password requirements
5. **App Verification**: Code signing và app store verification

**Risk Level**: Medium (mitigated by user education và verification)

---

### T10: Implementation Bugs

**Description**: Bugs trong code implementation có thể lead to vulnerabilities.

**Attack Vectors**:
- Memory safety bugs
- Logic errors
- Race conditions
- Incorrect crypto usage

**Impact**:
- Critical - Could lead to any other threat

**Mitigation Strategies**:
1. **Memory Safety**: Use Rust (memory-safe language)
2. **Code Review**: Security-focused code review
3. **Testing**: Comprehensive unit và integration tests
4. **Fuzz Testing**: Fuzz testing for crypto code
5. **Static Analysis**: Automated static analysis tools
6. **Security Audits**: Third-party security audits

**Risk Level**: High (mitigated by safe language và testing)

---

## Threat Matrix

| Threat | Likelihood | Impact | Risk Level | Mitigation Status |
|--------|-----------|--------|------------|-------------------|
| T1: MITM | Medium | High | Medium | ✅ Mitigated |
| T2: Key Compromise | Low | Critical | High | ✅ Mitigated |
| T3: Device Loss | Medium | High | Medium | ✅ Mitigated |
| T4: Metadata Leakage | High | Medium | Medium | ⚠️ Partial |
| T5: Prekey Exhaustion | Low | Low-Medium | Low | ✅ Mitigated |
| T6: DoS | Medium | Medium | Medium | ✅ Mitigated |
| T7: Quantum Attacks | Low (future) | Critical | Low | 📋 Planned |
| T8: Side-Channel | Low | High | Medium | ✅ Mitigated |
| T9: Social Engineering | Medium | High | Medium | ⚠️ Partial |
| T10: Implementation Bugs | Medium | Critical | High | ✅ Mitigated |

---

## Attack Scenarios

### Scenario 1: Compromised Server

**Attack**: Attacker gains control of server infrastructure.

**What Attacker Can Do**:
- Read metadata (who talks to whom)
- Modify prekey bundles (but signatures prevent this)
- Drop messages (DoS)
- Cannot decrypt messages (keys are client-side)

**Mitigation**:
- Signed prekeys prevent tampering
- Server cannot decrypt (no private keys)
- Messages encrypted end-to-end

**Risk**: Low-Medium (privacy impact, but messages secure)

---

### Scenario 2: Compromised Client Device

**Attack**: Malware trên user's device.

**What Attacker Can Do**:
- Read all messages khi device unlocked
- Access session keys
- Could send messages as user
- Cannot decrypt past messages (forward secrecy)

**Mitigation**:
- Forward secrecy protects past messages
- Break-in recovery limits damage
- Device security (lock screen, biometrics)
- Device revocation

**Risk**: Medium (current sessions compromised, past messages safe)

---

### Scenario 3: Network Surveillance

**Attack**: Government or ISP monitors network traffic.

**What Attacker Can Do**:
- See metadata (who talks to whom, when)
- See message sizes
- Cannot decrypt messages
- Could perform timing analysis

**Mitigation**:
- TLS encrypts transport
- End-to-end encryption
- Forward secrecy
- Metadata minimization

**Risk**: Medium (metadata leakage, but content secure)

---

## Security Requirements

### Must Have (Critical)

1. ✅ Forward secrecy (Double Ratchet)
2. ✅ Break-in recovery (Double Ratchet)
3. ✅ Hardware-backed keystores
4. ✅ TLS 1.3 for all communications
5. ✅ Signed prekeys (Ed25519)
6. ✅ No private key export
7. ✅ Secure random number generation

### Should Have (Important)

1. ⚠️ Certificate pinning (future)
2. ⚠️ Message padding (future)
3. ✅ Prekey auto-replenishment
4. ✅ Rate limiting
5. ✅ Device revocation
6. ✅ Session timeout

### Nice to Have (Enhancement)

1. 📋 PQXDH (post-quantum)
2. 📋 Mixnet support
3. 📋 Advanced metadata protection

---

## Incident Response Plan

### Security Incident Types

1. **Key Compromise**: User reports compromised device
2. **Server Breach**: Server infrastructure compromised
3. **Crypto Vulnerability**: Discovery of crypto vulnerability
4. **Implementation Bug**: Critical bug discovered

### Response Procedures

1. **Immediate Actions**:
   - Assess impact và scope
   - Notify affected users
   - Revoke compromised keys/devices
   - Patch vulnerabilities

2. **Investigation**:
   - Analyze attack vector
   - Review logs và audit trails
   - Identify root cause

3. **Remediation**:
   - Deploy fixes
   - Update threat model
   - Enhance security controls

4. **Communication**:
   - Transparent communication với users
   - Security advisory
   - Lessons learned

---

## Review and Updates

- **Quarterly Review**: Review threat model quarterly
- **After Major Changes**: Update after architecture changes
- **After Security Incidents**: Update based on lessons learned
- **Annual Audit**: Comprehensive review annually

---

## References

- Signal Protocol Security Analysis
- X3DH Key Agreement Protocol
- Double Ratchet Algorithm Security
- NIST Cybersecurity Framework
- OWASP Threat Modeling Guide

