import Foundation
import UIKit
import UniformTypeIdentifiers

@available(iOS 16.0, *)
@MainActor
public final class BiqliPasteControl: UIPasteControl {
    public typealias Completion = (Result<BiqliAttributionResult, BiqliError>) -> Void

    private let receiver: PasteReceiver

    public init(
        consentGranted: Bool = true,
        completion: @escaping Completion
    ) {
        let receiver = PasteReceiver(consentGranted: consentGranted, completion: completion)
        self.receiver = receiver

        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconAndLabel
        configuration.cornerStyle = .capsule
        super.init(configuration: configuration)
        target = receiver
        accessibilityLabel = "Paste app link"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(consentGranted:completion:)")
    }
}

@available(iOS 16.0, *)
@MainActor
private final class PasteReceiver: UIResponder {
    override var pasteConfiguration: UIPasteConfiguration? {
        get {
            UIPasteConfiguration(
                acceptableTypeIdentifiers: BiqliPasteItemLoader.acceptedContentTypes.map(\.identifier)
            )
        }
        set {}
    }

    private let consentGranted: Bool
    private let completion: BiqliPasteControl.Completion

    init(
        consentGranted: Bool,
        completion: @escaping BiqliPasteControl.Completion
    ) {
        self.consentGranted = consentGranted
        self.completion = completion
        super.init()
    }

    override func paste(itemProviders: [NSItemProvider]) {
        BiqliPasteItemLoader.loadURL(from: itemProviders) { [weak self] url in
            self?.resolve(url)
        }
    }

    nonisolated private func resolve(_ url: URL?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let url else {
                completion(.failure(.invalidHandoffURL))
                return
            }
            do {
                completion(.success(try await Biqli.resolvePastedURL(
                    url,
                    consentGranted: consentGranted
                )))
            } catch let error as BiqliError {
                completion(.failure(error))
            } catch {
                completion(.failure(.transport))
            }
        }
    }

}

enum BiqliPasteItemLoader {
    static let acceptedContentTypes: [UTType] = [
        .utf8PlainText,
        .plainText,
        .url,
    ]

    private static let maximumByteCount = 4_096

    static func loadURL(
        from providers: [NSItemProvider],
        completion: @escaping (URL?) -> Void
    ) {
        let candidates = acceptedContentTypes.flatMap { contentType in
            providers.compactMap { provider in
                provider.hasItemConformingToTypeIdentifier(contentType.identifier)
                    ? (provider, contentType)
                    : nil
            }
        }
        loadURL(from: candidates[...], completion: completion)
    }

    private static func loadURL(
        from candidates: ArraySlice<(NSItemProvider, UTType)>,
        completion: @escaping (URL?) -> Void
    ) {
        guard let (provider, contentType) = candidates.first else {
            completion(nil)
            return
        }

        provider.loadDataRepresentation(
            forTypeIdentifier: contentType.identifier
        ) { data, error in
            if error == nil, let data, let url = Self.url(from: data) {
                completion(url)
                return
            }
            Self.loadURL(from: candidates.dropFirst(), completion: completion)
        }
    }

    static func url(from data: Data) -> URL? {
        guard !data.isEmpty, data.count <= maximumByteCount else { return nil }

        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
        guard let text else { return nil }

        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "\u{0000}\u{FEFF}")
            )
        )
        guard !trimmed.isEmpty else { return nil }

        return URL(string: trimmed)
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, *)
public struct BiqliPasteButton: UIViewRepresentable {
    private let consentGranted: Bool
    private let completion: BiqliPasteControl.Completion

    public init(
        consentGranted: Bool = true,
        completion: @escaping BiqliPasteControl.Completion
    ) {
        self.consentGranted = consentGranted
        self.completion = completion
    }

    public func makeUIView(context: Context) -> BiqliPasteControl {
        BiqliPasteControl(consentGranted: consentGranted, completion: completion)
    }

    public func updateUIView(_ uiView: BiqliPasteControl, context: Context) {}

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: BiqliPasteControl,
        context: Context
    ) -> CGSize? {
        uiView.intrinsicContentSize
    }
}
#endif
