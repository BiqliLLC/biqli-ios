import Biqli
import SwiftUI

struct ContentView: View {
    private static let appId = "biq_mapp_replace_me"
    private static let publishableKey = "biqli_mobile_pk_replace_me"
    private static let attributionDomain = "go.example.com"
    private static let testAppLink = "https://go.example.com/example"

    @State private var status = "Configuring Biqli…"
    @State private var match = "none"
    @State private var referral = "none"
    @State private var route = "none"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biqli iOS Sample")
                .font(.title2.bold())

            Group {
                Text("Status: \(status)")
                Text("Match: \(match)")
                Text("Referral: \(referral)")
                Text("Route: \(route)")
            }
            .font(.system(.body, design: .monospaced))

            Button("Resolve Attribution") {
                Task { await resolveAttribution() }
            }
            .buttonStyle(.borderedProminent)

            Button("Resolve Test App Link") {
                Task { await resolveTestAppLink() }
            }
            .buttonStyle(.bordered)

            if #available(iOS 16.0, *) {
                BiqliPasteButton { result in
                    apply(result)
                }
            }

            Text("Domain: \(Self.attributionDomain)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task { await configure() }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            Task {
                await Biqli.handle(url: url)
                await resolveAttribution()
            }
        }
    }

    @MainActor
    private func configure() async {
        do {
            try await Biqli.configure(
                appId: Self.appId,
                publishableKey: Self.publishableKey,
                diagnosticsEnabled: true,
                diagnosticHandler: { event in
                    print("[Biqli sample] \(event.rawValue)")
                }
            )
            status = "Ready"
        } catch {
            status = "Configuration failed: \(String(describing: error))"
        }
    }

    @MainActor
    private func resolveAttribution() async {
        status = "Resolving…"
        do {
            apply(.success(try await Biqli.resolveAttribution()))
        } catch let error as BiqliError {
            apply(.failure(error))
        } catch {
            status = "Failed: \(String(describing: error))"
        }
    }

    @MainActor
    private func resolveTestAppLink() async {
        guard let url = URL(string: Self.testAppLink) else {
            status = "Invalid test URL"
            return
        }
        status = "Resolving App Link…"
        do {
            apply(.success(try await Biqli.resolveAttribution(deepLink: url)))
        } catch let error as BiqliError {
            apply(.failure(error))
        } catch {
            status = "Failed: \(String(describing: error))"
        }
    }

    @MainActor
    private func apply(_ result: Result<BiqliAttributionResult, BiqliError>) {
        switch result {
        case .success(let attribution):
            status = "Resolved"
            match = attribution.open.matchedBy.rawValue
            referral = attribution.attribution?.referralCode ?? "none"
            route = attribution.link?.route ?? "none"
        case .failure(let error):
            status = "Failed: \(String(describing: error))"
        }
    }
}

#Preview {
    ContentView()
}
