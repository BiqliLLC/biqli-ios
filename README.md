# Biqli iOS SDK

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://www.swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Source: [github.com/BiqliLLC/biqli-ios](https://github.com/BiqliLLC/biqli-ios)

The Swift Package supports iOS 15+, Universal Links, first-open state, exact user-initiated deferred handoff, process-safe idempotency, bounded retries, and cached install attribution. It does not use IDFA or require App Tracking Transparency.

The app-instance ID, pending opaque handoff, idempotent request, and cached result are stored in Keychain with this-device-only protection. A lightweight UserDefaults marker resets that state after an uninstall/reinstall so the new installation receives a new app-instance ID.

## Install

In Xcode, choose **File > Add Package Dependencies**, enter:

```text
https://github.com/BiqliLLC/biqli-ios.git
```

Select **Up to Next Major Version** starting from `1.0.0`, then add the `Biqli` library to your app target.

Or add the package in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/BiqliLLC/biqli-ios.git",
        from: "1.0.0"
    ),
]
```

Then add `.product(name: "Biqli", package: "biqli-ios")` to the target that uses the SDK.

## Configure

Import the package and configure it using the public Mobile App credentials from Biqli:

```swift
import Biqli

try await Biqli.configure(
    appId: "biq_mapp_xxx",
    publishableKey: "biqli_mobile_pk_xxx"
)
```

The publishable key identifies and rate-limits the app. It is not a workspace secret and grants no management or analytics access.

## Universal Links

Add `applinks:go.example.com` to the app target's Associated Domains capability. Attach the same custom domain, Apple Team ID, and bundle ID to the Mobile App in Biqli. Biqli serves the matching file at:

```text
https://go.example.com/.well-known/apple-app-site-association
```

Forward incoming Universal Links and resolve them:

```swift
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    Task {
        await Biqli.handle(url: url)
        let result = try await Biqli.resolveAttribution()
        router.open(result.link?.route)
    }
}
```

UIKit apps should forward `userActivity.webpageURL` from `application(_:continue:restorationHandler:)` or the scene equivalent.

## Deferred install handoff

iOS has no general App Store Install Referrer API. Biqli's exact self-hosted path therefore requires a user action: the Deep View copies an opaque `bqmh_...` URL, the app is installed, and the user taps a paste control after first launch.

On iOS 16+, use the included system-backed SwiftUI control:

```swift
BiqliPasteButton { result in
    switch result {
    case .success(let attribution):
        // Send attribution.attribution?.referralCode and attribution.click?.id
        // to your trusted backend before granting a reward.
        router.open(attribution.link?.route)
    case .failure(let error):
        showError(error)
    }
}
```

UIKit can add `BiqliPasteControl` directly. On iOS 15, provide your own clearly labeled user-tapped paste action and pass the resulting URL to `Biqli.resolvePastedURL(_:)`.

The SDK never polls or silently reads `UIPasteboard`. A supplied opaque handoff survives an offline attempt and keeps the same idempotency key across process recreation. Call `resolveAttribution()` on later cold launches to retry pending network work during the 24-hour first-open window.

Signed attribution receipts last 10 minutes and are returned only on the live resolver response. The cached referral result intentionally removes the receipt, so submit the live receipt to the trusted backend immediately and never treat a cached result as fresh proof.

## Consent and result handling

Set `consentRequired: true` when local policy requires consent before attribution. Calls with `consentGranted: false` stop before contacting Biqli. Do not block app startup while waiting for attribution, and never grant a referral reward solely from client-supplied data; send the click/referral to the customer's trusted backend for validation.

Probabilistic iOS matching is off by default. A customer that has completed its privacy review may explicitly set `probabilisticMatchingEnabled: true` and `attributionDomain: "go.example.com"`; the SDK then asks the resolver for a clearly labeled probabilistic result only when `consentGranted` is also true. The server requires that domain to be verified and attached to the app. Ambiguous candidates return no match.

## Sample app

Open `Sample/BiqliSample/BiqliSample.xcodeproj` in Xcode. Before running it, replace the example app ID, publishable key, domain, and test URL in `ContentView.swift`, and update the Associated Domains entry in `BiqliSample.entitlements`.

## Requirements

- iOS 15 or later
- Xcode 15 or later
- Swift 5.9 or later

## License

Copyright 2026 Biqli LLC. Licensed under the [Apache License 2.0](LICENSE).
