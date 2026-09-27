# Changelog

## 1.0.0 - 2026-09-27

- Add Universal Link capture and exact mobile-open resolution.
- Add user-initiated iOS deferred handoff through UIKit and SwiftUI paste controls.
- Add persisted first-open state, pending handoff/request recovery, idempotent retries, and result caching.
- Protect persisted SDK state in Keychain, reset it after reinstall, and keep short-lived receipts out of the long-lived result cache.
- Bind opt-in probabilistic matching to a configured verified custom domain.
- Add consent gating and an SDK privacy manifest.
