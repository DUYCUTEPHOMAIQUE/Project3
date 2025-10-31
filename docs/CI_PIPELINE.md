# CI Pipeline Configuration

## Overview
CI pipeline được thiết lập với GitHub Actions để tự động hóa:
- Lint checks (rustfmt, clippy)
- Unit tests
- Build artifacts cho multiple platforms
- Security checks

## Workflows

### Main CI Workflow (`.github/workflows/ci.yml`)

**Jobs:**

1. **rust-core**: Lint & Test cho Rust core library
   - Check formatting với `cargo fmt`
   - Run clippy với `-D warnings`
   - Run unit tests
   - Build release version

2. **rust-build-artifacts**: Build artifacts cho multiple platforms
   - x86_64-unknown-linux-gnu
   - x86_64-apple-darwin
   - x86_64-pc-windows-msvc
   - aarch64-apple-darwin
   - aarch64-unknown-linux-gnu

3. **node-gateway**: Lint & Test cho Node.js gateway
   - ESLint checks
   - Jest tests
   - TypeScript build

4. **security**: Security checks
   - cargo audit để check vulnerabilities

5. **integration-tests**: Integration tests (sẽ implement trong Phase 1)

## Triggers

- Push to `main` hoặc `develop` branches
- Pull requests targeting `main` hoặc `develop`

## Caching

- Cargo registry và git dependencies được cache
- Node.js dependencies được cache

## Future Enhancements

- Code coverage reports
- Release automation
- Docker image builds
- iOS/Android build jobs (khi có bindings)

