import Foundation

public enum Biqli {
    public static func configure(
        appId: String,
        publishableKey: String,
        apiBaseURL: URL = URL(string: "https://biq.li/api/v1")!,
        consentRequired: Bool = false,
        probabilisticMatchingEnabled: Bool = false,
        attributionDomain: String? = nil,
        diagnosticsEnabled: Bool = false,
        diagnosticHandler: (@Sendable (BiqliDiagnostic) -> Void)? = nil
    ) async throws {
        try await BiqliClient.shared.configure(
            .init(
                appId: appId,
                publishableKey: publishableKey,
                apiBaseURL: apiBaseURL,
                consentRequired: consentRequired,
                probabilisticMatchingEnabled: probabilisticMatchingEnabled,
                attributionDomain: attributionDomain,
                diagnosticsEnabled: diagnosticsEnabled,
                diagnosticHandler: diagnosticHandler
            )
        )
    }

    /// Call from the Universal Link lifecycle callback. This never reads the pasteboard.
    public static func handle(url: URL) async {
        await BiqliClient.shared.handle(url: url)
    }

    /// Resolve the pending Universal Link, or a URL explicitly supplied by the app.
    public static func resolveAttribution(
        deepLink: URL? = nil,
        consentGranted: Bool = true
    ) async throws -> BiqliAttributionResult {
        try await BiqliClient.shared.resolve(
            deepLink: deepLink,
            handoffURL: nil,
            consentGranted: consentGranted
        )
    }

    /// Pass the URL obtained from a user-initiated UIPasteControl action.
    /// The SDK intentionally does not poll UIPasteboard.
    public static func resolvePastedURL(
        _ url: URL,
        consentGranted: Bool = true
    ) async throws -> BiqliAttributionResult {
        try await BiqliClient.shared.resolve(
            deepLink: nil,
            handoffURL: url,
            consentGranted: consentGranted
        )
    }
}

public struct BiqliConfiguration: Sendable {
    public let appId: String
    public let publishableKey: String
    public let apiBaseURL: URL
    public let consentRequired: Bool
    public let probabilisticMatchingEnabled: Bool
    public let attributionDomain: String?
    public let diagnosticsEnabled: Bool
    public let diagnosticHandler: (@Sendable (BiqliDiagnostic) -> Void)?
}

public enum BiqliDiagnostic: String, Sendable {
    case appLinkCaptured
    case resolverRetry
    case resolverMatched
    case resolverNoMatch
}

public enum BiqliError: Error, Equatable {
    case notConfigured
    case consentRequired
    case invalidConfiguration
    case invalidHandoffURL
    case invalidResponse
    case secureStorageUnavailable
    case http(status: Int, code: String?)
    case transport
}
