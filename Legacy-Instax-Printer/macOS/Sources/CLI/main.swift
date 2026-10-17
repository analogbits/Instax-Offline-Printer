import Foundation
import AppKit

// MARK: - legacy-instax Command Line Tool (SP-1 / SP-2 / SP-3 Wi-Fi Direct)

let args = Array(CommandLine.arguments.dropFirst())

func printHelp() {
    print("""
    Legacy Instax Printer CLI v1.5.0 — Offline Wi-Fi Direct Tool for Fujifilm Instax SHARE SP-1, SP-2 & SP-3
    ======================================================================================================
    Usage:
      legacy-instax [options] [image_path]

    Options:
      --ip <address>       Printer IP address (default: 192.168.0.251)
      --port <port>        Printer TCP port (default: 8080)
      --pin <4-digits>     Printer PIN code (default: 1111)
      --model <sp1|sp2|sp3> Target printer model (default: sp2)
      --status             Query printer model, firmware, battery, and film count
      --dry-run            Test full Wi-Fi Direct image transfer with 0 film used
      --simulate           Start & connect to built-in Virtual SP-1/2/3 Simulator (127.0.0.1:18080)
      --fit                Fit image inside frame with matte borders (default: crop to fill)
      --caption <text>     Add bottom caption text
      --qr <url_or_text>   Overlay scannable QR code on print
      --help               Show this help message
    """)
}

if args.contains("--help") || args.contains("-h") {
    printHelp()
    exit(0)
}

var host = "192.168.0.251"
var port: UInt16 = 8080
var pin: UInt16 = 1111
var model: LegacyPrinterModel = .sp2
var statusOnly = false
var dryRun = false
var simulate = false
var options = LegacyPrintOptions()
var imagePath: String?

var i = 0
while i < args.count {
    let arg = args[i]
    switch arg {
    case "--ip":
        if i + 1 < args.count { host = args[i + 1]; i += 1 }
    case "--port":
        if i + 1 < args.count { port = UInt16(args[i + 1]) ?? 8080; i += 1 }
    case "--pin":
        if i + 1 < args.count { pin = UInt16(args[i + 1]) ?? 1111; i += 1 }
    case "--model":
        if i + 1 < args.count {
            let m = args[i + 1].lowercased()
            if m.contains("1") { model = .sp1 }
            else if m.contains("3") { model = .sp3 }
            else { model = .sp2 }
            i += 1
        }
    case "--status":
        statusOnly = true
    case "--dry-run":
        dryRun = true
    case "--simulate":
        simulate = true
    case "--fit":
        options.fitMode = .fit
    case "--caption":
        if i + 1 < args.count { options.captionText = args[i + 1]; i += 1 }
    case "--qr":
        if i + 1 < args.count {
            options.qrContentType = .url
            options.qrPrimaryText = args[i + 1]
            i += 1
        }
    default:
        if !arg.hasPrefix("-") {
            imagePath = arg
        }
    }
    i += 1
}

options.model = model

if simulate {
    LegacyVirtualPrinterServer.shared.simulatedModel = model
    _ = LegacyVirtualPrinterServer.shared.start(port: 18080)
    host = "127.0.0.1"
    port = 18080
    print("🟢 Started Virtual Instax SHARE \(model.rawValue) Server on 127.0.0.1:18080")
}

let manager = LegacyPrinterManager()
manager.printerIP = host
manager.printerPort = String(port)
manager.pinCode = String(pin)
manager.dryRunMode = dryRun

let sema = DispatchSemaphore(value: 0)

if statusOnly || imagePath == nil {
    var done = false
    manager.queryPrinterStatus { _ in
        print("Model:        \(manager.telemetry.modelName)")
        print("Firmware:     \(manager.telemetry.firmwareVersion)")
        print("Resolution:   \(manager.telemetry.maxWidth)×\(manager.telemetry.maxHeight)")
        print("Film Left:    \(manager.telemetry.filmRemaining)/10")
        print("Battery:      \(manager.telemetry.batteryLevel)/4")
        print("Total Prints: \(manager.telemetry.totalPrintHistory)")
        done = true
    }
    let deadline = Date(timeIntervalSinceNow: 8.0)
    while !done && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
    exit(manager.isConnected ? 0 : 1)
}

guard let path = imagePath, let nsImg = NSImage(contentsOfFile: path) else {
    print("❌ Failed to load image at path: \(imagePath ?? "")")
    exit(1)
}

guard let rendered = LegacyImageProcessor.renderPreviewAndCGImage(primaryImage: nsImg, options: options) else {
    print("❌ Failed to render image for \(model.displayName)")
    exit(1)
}

var exitSuccess = false
manager.printCGImage(rendered.cgImage, model: model) { ok in
    exitSuccess = ok
    sema.signal()
}

while sema.wait(timeout: .now() + 0.25) == .timedOut {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}

exit(exitSuccess ? 0 : 1)
