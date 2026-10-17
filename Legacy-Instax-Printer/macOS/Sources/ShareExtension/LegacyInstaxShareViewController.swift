import Cocoa
import UniformTypeIdentifiers

@objc(LegacyInstaxShareViewController)
public final class LegacyInstaxShareViewController: NSViewController {
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, _ in
                    if let url = data as? URL,
                       let encoded = url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let schemeURL = URL(string: "legacy-instax-printer://open?file=\(encoded)") {
                        NSWorkspace.shared.open(schemeURL)
                    }
                    DispatchQueue.main.async {
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                }
                return
            }
        }
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
