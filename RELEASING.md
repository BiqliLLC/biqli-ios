# Releasing the Biqli iOS SDK

Published versions are immutable. Never move or reuse a release tag.

## Before tagging

1. Set `BiqliClient.sdkVersion` to the release version.
2. Add the dated release entry to `CHANGELOG.md`.
3. Confirm `README.md` uses the same minimum supported version and installation version.
4. Confirm the repository contains no credentials, generated build products, signing files, or issued handoff tokens.
5. Run the package tests and both simulator and device builds from a clean checkout.
6. Verify that the privacy manifest is present in the built product.

## Validate on macOS

```bash
swift package dump-package >/dev/null
swift test

xcodebuild \
  -scheme Biqli \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode \
  build

xcodebuild \
  -scheme Biqli \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -derivedDataPath .build/device-release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Publish

Commit the exact validated source to `main`, push it, then create and push a bare semantic-version tag:

```bash
git tag -a 1.0.0 -m "Biqli iOS SDK 1.0.0"
git push origin main
git push origin 1.0.0
```

Consumers install the SDK from:

```text
https://github.com/BiqliLLC/biqli-ios.git
```

After publishing, validate resolution from a separate clean Swift package or Xcode project using the public URL and the exact released version.
