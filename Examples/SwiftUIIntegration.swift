import Biqli
import SwiftUI

struct AttributionView: View {
    @State private var message = "Waiting for a link"

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
            if #available(iOS 16.0, *) {
                BiqliPasteButton { result in
                    switch result {
                    case .success(let value):
                        message = "Referral: \(value.attribution?.referralCode ?? "none")"
                    case .failure(let error):
                        message = error.localizedDescription
                    }
                }
                .frame(height: 50)
            } else {
                Text("Add a user-tapped paste button for iOS 15.")
            }
        }
        .task {
            try? await Biqli.configure(
                appId: "biq_mapp_replace_me",
                publishableKey: "biqli_mobile_pk_replace_me"
            )
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            Task {
                await Biqli.handle(url: url)
                if let result = try? await Biqli.resolveAttribution() {
                    message = "Route: \(result.link?.route ?? "none")"
                }
            }
        }
    }
}
