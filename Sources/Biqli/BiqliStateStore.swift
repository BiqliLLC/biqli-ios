import Foundation

final class BiqliStateStore: @unchecked Sendable {
    private let store: BiqliSecureStore
    private let reinstallMarker: String
    private let defaults = UserDefaults.standard

    init(appId: String) {
        let safeAppId = appId
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        store = BiqliSecureStore(namespace: safeAppId)
        reinstallMarker = "li.biq.sdk.\(safeAppId).initialized"

        // UserDefaults is removed on uninstall while Keychain may survive. Resetting
        // on a missing marker gives a reinstall a new app instance and attribution.
        if !defaults.bool(forKey: reinstallMarker) {
            store.removeAll()
            defaults.set(true, forKey: reinstallMarker)
        }
    }

    func appInstanceId() throws -> String {
        if let existing = string(for: Keys.appInstance) { return existing }
        let value = "install_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        try set(value, for: Keys.appInstance)
        return value
    }

    func isFirstOpenPending() throws -> Bool {
        if string(for: Keys.completed) == "1" { return false }
        let started = string(for: Keys.firstAttempt).flatMap(TimeInterval.init)
        if let started, Date().timeIntervalSince1970 - started >= 24 * 60 * 60 {
            try set("1", for: Keys.completed)
            return false
        }
        if started == nil {
            try set(String(Date().timeIntervalSince1970), for: Keys.firstAttempt)
        }
        return true
    }

    func completeFirstOpen(with result: BiqliAttributionResult) throws {
        let cacheable = BiqliAttributionResult(
            open: result.open,
            click: result.click,
            link: result.link,
            attribution: result.attribution,
            attributionReceipt: nil,
            requestId: result.requestId
        )
        try set(JSONEncoder().encode(cacheable), for: Keys.result)
        try set("1", for: Keys.completed)
        store.remove(Keys.pendingToken)
    }

    func cachedFirstResult() -> BiqliAttributionResult? {
        guard let data = store.data(for: Keys.result) else { return nil }
        return try? JSONDecoder().decode(BiqliAttributionResult.self, from: data)
    }

    func savePendingDeepLink(_ url: URL) {
        try? set(url.absoluteString, for: Keys.pendingDeepLink)
    }

    func pendingDeepLink() -> URL? {
        string(for: Keys.pendingDeepLink).flatMap(URL.init(string:))
    }

    func clearPendingDeepLink(matching url: URL?) {
        guard url == nil || pendingDeepLink()?.absoluteString == url?.absoluteString else {
            return
        }
        store.remove(Keys.pendingDeepLink)
    }

    func savePendingHandoffToken(_ token: String) throws {
        try set(token, for: Keys.pendingToken)
    }

    func pendingHandoffToken() -> String? {
        string(for: Keys.pendingToken)
    }

    func clearPendingHandoffToken() {
        store.remove(Keys.pendingToken)
    }

    func savePendingRequest(_ pending: PendingMobileOpenRequest) throws {
        try set(JSONEncoder().encode(pending), for: Keys.pendingRequest)
    }

    func pendingRequest() -> PendingMobileOpenRequest? {
        guard let data = store.data(for: Keys.pendingRequest) else { return nil }
        return try? JSONDecoder().decode(PendingMobileOpenRequest.self, from: data)
    }

    func clearPendingRequest(eventId: String? = nil) {
        if let eventId, pendingRequest()?.request.eventId != eventId { return }
        store.remove(Keys.pendingRequest)
    }

    private func string(for key: String) -> String? {
        store.data(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func set(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw BiqliError.secureStorageUnavailable
        }
        try set(data, for: key)
    }

    private func set(_ data: Data, for key: String) throws {
        guard store.set(data, for: key) else {
            throw BiqliError.secureStorageUnavailable
        }
    }

    private enum Keys {
        static let appInstance = "app-instance-id"
        static let completed = "first-open-completed"
        static let firstAttempt = "first-open-started-at"
        static let result = "first-attribution-result"
        static let pendingDeepLink = "pending-deep-link"
        static let pendingToken = "pending-handoff-token"
        static let pendingRequest = "pending-open-request"
    }
}
