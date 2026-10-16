import AppKit
import UniformTypeIdentifiers

@objc(InstaxShareViewController)
final class InstaxShareViewController: NSViewController {
    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 160))
        let label = NSTextField(labelWithString: "Sending to Instax Printer...")
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 70, width: 240, height: 24)
        v.addSubview(label)

        let spinner = NSProgressIndicator(frame: NSRect(x: 124, y: 100, width: 32, height: 32))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        v.addSubview(spinner)

        self.view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processItems()
    }

    private func processItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancel()
            return
        }

        var urls: [URL] = []
        let group = DispatchGroup()

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        defer { group.leave() }
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            urls.append(url)
                        } else if let url = item as? URL {
                            urls.append(url)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                        defer { group.leave() }
                        if let url = item as? URL {
                            urls.append(url)
                        } else if let data = item as? Data {
                            let tmpURL = URL(fileURLWithPath: "/tmp/instax_share_\(UUID().uuidString).jpg")
                            try? data.write(to: tmpURL)
                            urls.append(tmpURL)
                        } else if let img = item as? NSImage {
                            let tmpURL = URL(fileURLWithPath: "/tmp/instax_share_\(UUID().uuidString).jpg")
                            if let tiff = img.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let jpg = rep.representation(using: .jpeg, properties: [:]) {
                                try? jpg.write(to: tmpURL)
                                urls.append(tmpURL)
                            }
                        }
                    }
                } else if provider.canLoadObject(ofClass: NSImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: NSImage.self) { obj, _ in
                        defer { group.leave() }
                        if let img = obj as? NSImage {
                            let tmpURL = URL(fileURLWithPath: "/tmp/instax_share_\(UUID().uuidString).jpg")
                            if let tiff = img.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let jpg = rep.representation(using: .jpeg, properties: [:]) {
                                try? jpg.write(to: tmpURL)
                                urls.append(tmpURL)
                            }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.handoffToApp(urls: urls)
        }
    }

    private func handoffToApp(urls: [URL]) {
        let appBundleID = "com.analogbits.instax.printer"
        let desktopAppURL = URL(fileURLWithPath: "/Users/michaelfitzgerald/Desktop/Instax Printer.app")
        let appsAppURL = URL(fileURLWithPath: "/Applications/Instax Printer.app")
        
        var targetURL = appsAppURL
        if let appFromLS = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appBundleID) {
            targetURL = appFromLS
        } else if FileManager.default.fileExists(atPath: desktopAppURL.path) {
            targetURL = desktopAppURL
        }

        let conf = NSWorkspace.OpenConfiguration()
        conf.activates = true

        if urls.isEmpty {
            NSWorkspace.shared.openApplication(at: targetURL, configuration: conf) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        } else {
            NSWorkspace.shared.open(urls, withApplicationAt: targetURL, configuration: conf) { [weak self] _, error in
                if error != nil {
                    for u in urls {
                        NSWorkspace.shared.open(u)
                    }
                }
                DispatchQueue.main.async {
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "InstaxShare", code: -1, userInfo: nil))
    }
}
