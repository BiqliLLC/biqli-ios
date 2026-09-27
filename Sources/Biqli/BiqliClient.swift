import Foundation
import UIKit

actor BiqliClient {
    static let shared = BiqliClient()
    static let sdkVersion = "1.0.0"

    private var configuration: BiqliConfiguration?
    private var pendingDeepLink: URL?
    private var state: BiqliStateStore?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(_ configuration: BiqliConfiguration) throws {
        guard
            Self.matches(configuration.appId, pattern: #"^biq_mapp_[0-9A-HJKMNP-TV-Z]{26}$"#),
            Self.matches(configuration.publishableKey, pattern: #"^biqli_mobile_pk_[A-Za-z0-9_-]{64}$"#),
            configuration.apiBaseURL.scheme == "https",
            configuration.apiBaseURL.host != nil,
            configuration.apiBaseURL.user == nil,
            configuration.apiBaseURL.password == nil,
            configuration.apiBaseURL.port == nil || configuration.apiBaseURL.port == 443,
            configuration.apiBaseURL.query == nil,
            configuration.apiBaseURL.fragment == nil,
            !configuration.probabilisticMatchingEnabled ||
                Self.isHostname(configuration.attributionDomain)
        else { throw BiqliError.invalidConfiguration }
        self.configuration = configuration
        self.state = BiqliStateStore(appId: configuration.appId)
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "https" else { return }
        pendingDeepLink = url
        state?.savePendingDeepLink(url)
        diagnostic(.appLinkCaptured)
    }

    func resolve(
        deepLink: URL?,
        handoffURL: URL?,
        consentGranted: Bool
    ) async throws -> BiqliAttributionResult {
        guard let configuration, let state else { throw BiqliError.notConfigured }
        if configuration.consentRequired && !consentGranted {
            throw BiqliError.consentRequired
        }

        if let deepLink { handle(url: deepLink) }
        let selectedDeepLink = deepLink ?? pendingDeepLink ?? state.pendingDeepLink()
        let suppliedHandoffToken = try handoffURL.map(extractHandoffToken)
        if let suppliedHandoffToken {
            try state.savePendingHandoffToken(suppliedHandoffToken)
        }
        let handoffToken = suppliedHandoffToken ?? state.pendingHandoffToken()

        if let pending = state.pendingRequest() {
            let hasNewInput =
                (suppliedHandoffToken != nil && suppliedHandoffToken != pending.request.handoffToken) ||
                (deepLink != nil && deepLink?.absoluteString != pending.request.deepLink)
            if !hasNewInput {
                return try await finish(
                    pending: pending,
                    configuration: configuration,
                    state: state
                )
            }
            state.clearPendingRequest()
        }

        let firstOpen = try state.isFirstOpenPending()
        if !firstOpen && selectedDeepLink == nil && handoffToken == nil,
           let cached = state.cachedFirstResult() {
            return cached
        }
        let eventId = "open_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let requestId = "req_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let payload = MobileOpenRequest(
            eventId: eventId,
            appId: configuration.appId,
            appInstanceId: try state.appInstanceId(),
            firstOpen: firstOpen,
            probabilisticAllowed: configuration.probabilisticMatchingEnabled && consentGranted,
            handoffToken: handoffToken,
            deepLink: selectedDeepLink?.absoluteString,
            domain: selectedDeepLink?.host ?? configuration.attributionDomain,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: UIDevice.current.systemVersion,
            sdkVersion: Self.sdkVersion,
            occurredAt: ISO8601DateFormatter().string(from: Date())
        )
        let pending = PendingMobileOpenRequest(request: payload, requestId: requestId)
        try state.savePendingRequest(pending)
        return try await finish(pending: pending, configuration: configuration, state: state)
    }

    private func finish(
        pending: PendingMobileOpenRequest,
        configuration: BiqliConfiguration,
        state: BiqliStateStore
    ) async throws -> BiqliAttributionResult {
        do {
            let result = try await send(
                pending.request,
                configuration: configuration,
                requestId: pending.requestId,
                idempotencyKey: pending.request.eventId
            )
            state.clearPendingRequest(eventId: pending.request.eventId)
            state.clearPendingDeepLink(matching: pending.request.deepLink.flatMap(URL.init(string:)))
            if pending.request.handoffToken != nil && result.open.matchedBy == .none {
                state.clearPendingHandoffToken()
            }
            pendingDeepLink = nil
            if result.open.matchedBy != .none {
                try state.completeFirstOpen(with: result)
            }
            diagnostic(
                result.open.matchedBy == .none ? .resolverNoMatch : .resolverMatched
            )
            return result
        } catch let error as BiqliError {
            if case .http(let status, let code) = error,
               status < 500,
               status != 408,
               status != 425,
               status != 429 {
                state.clearPendingRequest(eventId: pending.request.eventId)
                if pending.request.handoffToken != nil && code == "resource_not_found" {
                    state.clearPendingHandoffToken()
                }
                if code == "handoff_mismatch" {
                    state.clearPendingDeepLink(
                        matching: pending.request.deepLink.flatMap(URL.init(string:))
                    )
                    pendingDeepLink = nil
                }
            }
            throw error
        }
    }

    private func send(
        _ payload: MobileOpenRequest,
        configuration: BiqliConfiguration,
        requestId: String,
        idempotencyKey: String
    ) async throws -> BiqliAttributionResult {
        let endpoint = configuration.apiBaseURL.appendingPathComponent("track/open")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("ios", forHTTPHeaderField: "X-Biq-SDK")
        request.setValue(Self.sdkVersion, forHTTPHeaderField: "X-Biq-SDK-Version")
        request.setValue(requestId, forHTTPHeaderField: "X-Biq-Request-Id")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw BiqliError.invalidResponse
                }
                if (200..<300).contains(http.statusCode) {
                    guard data.count <= 65_536 else { throw BiqliError.invalidResponse }
                    return try JSONDecoder().decode(BiqliAttributionResult.self, from: data)
                }
                let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
                if http.statusCode == 429 || http.statusCode >= 500 {
                    throw RetryableError.server
                }
                throw BiqliError.http(status: http.statusCode, code: apiError?.error?.code)
            } catch let error as BiqliError {
                throw error
            } catch {
                lastError = error
                if attempt < 2 {
                    diagnostic(.resolverRetry)
                    let base = UInt64(400_000_000 * (attempt + 1))
                    let jitter = UInt64.random(in: 0...250_000_000)
                    try await Task.sleep(nanoseconds: base + jitter)
                }
            }
        }
        if configuration.diagnosticsEnabled {
            print("[Biqli] attribution request failed: \(type(of: lastError as Any))")
        }
        throw BiqliError.transport
    }

    private func diagnostic(_ event: BiqliDiagnostic) {
        guard configuration?.diagnosticsEnabled == true else { return }
        configuration?.diagnosticHandler?(event)
    }

    private func extractHandoffToken(from url: URL) throws -> String {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            let token = components.queryItems?.first(where: {
                $0.name == "biqli_token"
            })?.value,
            token.hasPrefix("bqmh_"),
            token.count == 48
        else { throw BiqliError.invalidHandoffURL }
        return token
    }

    private static func isHostname(_ value: String?) -> Bool {
        guard let value else { return false }
        let host = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard host.count <= 253, host.contains(".") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return host.split(separator: ".").allSatisfy { label in
            guard
                !label.isEmpty,
                label.count <= 63,
                label.first != "-",
                label.last != "-"
            else { return false }
            return label.unicodeScalars.allSatisfy(allowed.contains)
        }
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private enum RetryableError: Error { case server }
}
