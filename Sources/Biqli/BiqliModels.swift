import Foundation

public struct BiqliAttributionResult: Codable, Sendable, Equatable {
    public let open: Open
    public let click: Click?
    public let link: Link?
    public let attribution: Attribution?
    public let attributionReceipt: String?
    public let requestId: String

    public struct Open: Codable, Sendable, Equatable {
        public let id: String
        public let firstOpen: Bool
        public let matchedBy: MatchType
        public let confidence: Confidence
    }

    public struct Click: Codable, Sendable, Equatable {
        public let id: String
    }

    public struct Link: Codable, Sendable, Equatable {
        public let id: String
        public let shortUrl: String
        public let route: String
    }

    public struct Attribution: Codable, Sendable, Equatable {
        public let referralCode: String?
        public let metadata: JSONValue
        public let dynamic: [String: String]
    }

    public enum MatchType: String, Codable, Sendable {
        case exactAppLink = "exact_app_link"
        case exactInstallReferrer = "exact_install_referrer"
        case exactHandoff = "exact_handoff"
        case probabilistic
        case none
    }

    public enum Confidence: String, Codable, Sendable {
        case exact
        case probabilistic
        case none
    }
}

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct MobileOpenRequest: Codable, Equatable {
    let eventId: String
    let appId: String
    let appInstanceId: String
    let platform = "ios"
    let firstOpen: Bool
    let probabilisticAllowed: Bool
    let handoffToken: String?
    let deepLink: String?
    let domain: String?
    let appVersion: String?
    let osVersion: String
    let sdkVersion: String
    let occurredAt: String
}

struct PendingMobileOpenRequest: Codable, Equatable {
    let request: MobileOpenRequest
    let requestId: String
}

struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable { let code: String?; let message: String? }
    let error: APIError?
}
