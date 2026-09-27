import Biqli
import UIKit

final class AttributionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            try await Biqli.configure(
                appId: "biq_mapp_replace_me",
                publishableKey: "biqli_mobile_pk_replace_me"
            )
            _ = try? await Biqli.resolveAttribution()
        }

        if #available(iOS 16.0, *) {
            let control = BiqliPasteControl { result in
                // Route a successful result and validate referrals on your backend.
                print(result)
            }
            view.addSubview(control)
            control.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                control.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                control.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                control.heightAnchor.constraint(equalToConstant: 50),
            ])
        }
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        Task {
            await Biqli.handle(url: url)
            _ = try? await Biqli.resolveAttribution()
        }
    }
}
