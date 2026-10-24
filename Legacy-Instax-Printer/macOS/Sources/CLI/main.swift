import Foundation
import AppKit

// MARK: - legacy-instax Command Line Tool (SP-1 / SP-2 / SP-3 Wi-Fi Direct)

let args = Array(CommandLine.arguments.dropFirst())

func printHelp() {
    print("""
    Legacy Instax Printer CLI v2.1.0 — Offline Wi-Fi Direct Tool for Fujifilm Instax SHARE SP-1, SP-2 & SP-3
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
      --filter <name>      Artistic filter (Normal, Monochrome, Sepia, Vivid Velvia, Classic Chrome,
                           Solarisation, False-Colour Infrared, Cross-Processing, Duotone Cyanotype,
                           Split-Toning, 1-Bit Dithering, Chromatic Aberration, CRT Scanlines,
                           Pixel Sorting, Posterisation, Sobel Edge Detection, Binarised Stencil, Embossing)
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
    case "--filter":
        if i + 1 < args.count {
            let fArg = args[i + 1]
            let fLow = fArg.lowercased()
            let slugMap: [String: LegacyPhotoFilter] = [
                "none": .normal, "normal": .normal,
                "fuji": .fujiIntelligence, "fujifilm intelligence": .fujiIntelligence,
                "mono": .mono, "monochrome": .mono,
                "sepia": .sepia,
                "vivid": .vivid, "vivid velvia": .vivid,
                "vintage": .vintage, "classic chrome": .vintage,
                "solarize": .solarize, "solarisation": .solarize,
                "aerochrome": .aerochrome, "false-colour infrared": .aerochrome,
                "cross_process": .crossProcess, "cross-processing": .crossProcess,
                "duotone_cyan": .duotoneCyan, "duotone cyanotype": .duotoneCyan,
                "split_tone": .splitTone, "split-toning": .splitTone,
                "dither": .dither, "1-bit dithering": .dither,
                "chromatic": .chromaticAberration, "chromatic aberration": .chromaticAberration,
                "crt_scanlines": .crtScanlines, "crt scanlines": .crtScanlines,
                "pixel_sort": .pixelSort, "pixel sorting": .pixelSort,
                "posterize": .posterize, "posterisation": .posterize,
                "edge_detect": .edgeDetect, "sobel edge detection": .edgeDetect,
                "threshold": .threshold, "binarised stencil": .threshold,
                "emboss": .emboss, "embossing": .emboss
            ]
            if let mapped = slugMap[fLow] ?? LegacyPhotoFilter(rawValue: fArg) {
                options.filter = mapped
            }
            i += 1
        }
    case "--caption":
        if i + 1 < args.count { options.captionText = args[i + 1]; i += 1 }
    case "--frame-style":
        if i + 1 < args.count { options.frameStyle = args[i + 1]; i += 1 }
    case "--sticker":
        if i + 1 < args.count { options.sticker = args[i + 1]; i += 1 }
    case "--sticker-image":
        if i + 1 < args.count {
            if let customImg = NSImage(contentsOfFile: args[i + 1]) {
                options.stickerImage = customImg
            }
            i += 1
        }
    case "--sticker-pos":
        if i + 1 < args.count { options.stickerPosition = args[i + 1]; i += 1 }
    case "--sticker-scale":
        if i + 1 < args.count, let sc = Double(args[i + 1]) { options.stickerScale = sc; i += 1 }
    case "--sticker-opacity":
        if i + 1 < args.count, let op = Double(args[i + 1]) { options.stickerOpacity = op; i += 1 }
    case "--sticker-rot", "--sticker-rotation":
        if i + 1 < args.count, let rot = Double(args[i + 1]) { options.stickerRotation = rot; i += 1 }
    case "--sticker-x":
        if i + 1 < args.count, let sx = Double(args[i + 1]) {
            options.stickerX = sx
            options.stickerPosition = "custom"
            i += 1
        }
    case "--sticker-y":
        if i + 1 < args.count, let sy = Double(args[i + 1]) {
            options.stickerY = sy
            options.stickerPosition = "custom"
            i += 1
        }
    case "--banner-text":
        if i + 1 < args.count { options.bannerText = args[i + 1]; i += 1 }
    case "--banner-style":
        if i + 1 < args.count { options.bannerStyle = args[i + 1]; i += 1 }
    case "--banner-icon":
        if i + 1 < args.count { options.bannerIcon = args[i + 1]; i += 1 }
    case "--banner-color", "--banner-bg-color":
        if i + 1 < args.count { options.bannerBgColor = args[i + 1]; i += 1 }
    case "--banner-text-color":
        if i + 1 < args.count { options.bannerTextColor = args[i + 1]; i += 1 }
    case "--banner-x":
        if i + 1 < args.count, let bx = Double(args[i + 1]) { options.bannerX = bx; i += 1 }
    case "--banner-y":
        if i + 1 < args.count, let by = Double(args[i + 1]) { options.bannerY = by; i += 1 }
    case "--banner-scale":
        if i + 1 < args.count, let bsc = Double(args[i + 1]) { options.bannerScale = bsc; i += 1 }
    case "--banner-rot", "--banner-rotation":
        if i + 1 < args.count, let brot = Double(args[i + 1]) { options.bannerRotation = brot; i += 1 }
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

if statusOnly || (imagePath == nil && !dryRun) {
    var done = false
    manager.queryPrinterStatus(completion: { ok in
        if ok {
            print("Model:        \(manager.telemetry.modelName ?? "Unknown")")
            print("Firmware:     \(manager.telemetry.firmwareVersion ?? "Unknown")")
            print("Resolution:   \(manager.telemetry.maxWidth)×\(manager.telemetry.maxHeight)")
            print("Film Left:    \(manager.telemetry.filmRemaining ?? 0)/10")
            print("Battery:      \(manager.telemetry.batteryLevel ?? 0)/4")
            print("Total Prints: \(manager.telemetry.totalPrintHistory ?? 0)")
        } else {
            print("❌ \(manager.statusHeadline)")
        }
        done = true
    })
    let deadline = Date(timeIntervalSinceNow: 8.0)
    while !done && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
    exit(manager.isConnected ? 0 : 1)
}

var sourceImage: NSImage? = nil
if let path = imagePath {
    guard let loaded = NSImage(contentsOfFile: path) else {
        print("❌ Failed to load image at path: \(path)")
        exit(1)
    }
    sourceImage = loaded
}

guard let rendered = LegacyImageProcessor.renderPreviewAndCGImage(primaryImage: sourceImage, options: options) else {
    print("❌ Failed to render image for \(model.displayName)")
    exit(1)
}

var exitSuccess = false
manager.printCGImage(rendered.cgImage, model: model) { ok in
    if ok {
        print("✅ \(manager.statusHeadline)")
    } else {
        print("❌ \(manager.statusHeadline)")
    }
    exitSuccess = ok
    sema.signal()
}

while sema.wait(timeout: .now() + 0.25) == .timedOut {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}

exit(exitSuccess ? 0 : 1)
