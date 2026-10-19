import Foundation
import AppKit
import CoreBluetooth

// MARK: - Helper Utilities

func parseHexColor(_ hex: String) -> NSColor {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let val = UInt32(s, radix: 16) else {
        return NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    }
    let r = CGFloat((val >> 16) & 0xFF) / 255.0
    let g = CGFloat((val >> 8) & 0xFF) / 255.0
    let b = CGFloat(val & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
}

func printUsage() {
    let usage = """
    instax-square — Desktop CLI for Fujifilm Instax SQUARE Link (\(InstaxConstants.defaultDeviceName))

    USAGE:
      instax-square scan [--timeout <seconds>]
      instax-square status [--device <name>] [--json]
      instax-square ping [--device <name>]
      instax-square eject-cover [--device <name>]
      instax-square led [--off] [--device <name>]
      instax-square preview <image_path> -o <out.jpg> [--model square|wide|mini] [IMAGE_OPTIONS]
      instax-square print <image1> [image2 ...] [--device <name>] [--dry-run] [--model auto|square|wide|mini] [--mode none|rich|natural] [IMAGE_OPTIONS]

    OPTIONS:
      --dry-run                       Simulate full transmission & buffer validation (0 film used)
      --model <auto|square|wide|mini> Target printer format (default: auto)
      --device, -d <name>             Printer Bluetooth name or prefix (e.g. INSTAX-2, INSTAX-5)
      --mode, -m <none|rich|natural>  Film rendering profile (default: none / neutral pass-through)

    IMAGE OPTIONS:
      --fit <crop|fit|stretch>   How to fit image into print canvas (default: crop)
      --bg <#RRGGBB>             Background color for 'fit' mode (default: #FFFFFF)
      --zoom <float>             Zoom multiplier (default: 1.0)
      --offset-x <float>         Horizontal pan in [-1.0, 1.0] (default: 0.0)
      --offset-y <float>         Vertical pan in [-1.0, 1.0] (default: 0.0)
      --rotate <0|90|180|270>    Clockwise rotation in degrees (default: 0)
      --brightness <float>       Brightness adjustment in [-0.5, 0.5] (default: 0.0)
      --contrast <float>         Contrast multiplier in [0.5, 1.8] (default: 1.0)
      --saturation <float>       Saturation multiplier in [0.0, 2.0] (default: 1.0)

    RICH QR CODE & OVERLAYS:
      --qr <text|url>            Embed high-resolution scannable QR badge onto print
      --qr-pos <pos>             bottomRight (default), bottomLeft, topRight, topLeft, bottomCenter
      --qr-size <size>           small, medium (default), large
      --qr-style <style>         frosted (default), solidWhite, minimal
      --caption <text>           Optional text caption printed below QR badge
      --caption-color <#RRGGBB>  Caption color (default: #111111)

    COLLAGE OPTIONS:
      --collage <layout>         Create multi-photo collage: split2V, split2H, split3Hero,
                                 split3V, split3H, grid4, strips4V, grid6, grid8, grid9
      --collage-spacing <px>     Border spacing between photos (default: 16)

    EXAMPLES:
      instax-square scan
      instax-square status
      instax-square preview photo.jpg -o preview.jpg --qr "https://example.com" --qr-pos bottomRight
      instax-square preview p1.jpg p2.jpg p3.jpg -o collage.jpg --collage split3V --model wide
      instax-square print photo.jpg --qr "https://analogbits.io" --mode rich
    """
    print(usage)
}

// MARK: - Argument Parsing & Execution

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args.contains("-h") || args.contains("--help") {
    printUsage()
    exit(0)
}

let command = args[0].lowercased()
var deviceTarget = InstaxConstants.defaultDeviceName
var scanTimeout: TimeInterval = 4.0
var outputJSON = false
var ledOff = false
var outputPath: String?
var inputImagePaths: [String] = []
var printMode: InstaxPrintMode = .none
var imgOptions = InstaxImageOptions()
var targetModel: String = "auto"
var isDryRun: Bool = false

var collageLayout: InstaxCollageLayout? = nil
var collageSpacing: CGFloat = 16.0

var i = 1
while i < args.count {
    let arg = args[i]
    switch arg {
    case "--dry-run":
        isDryRun = true
    case "--model":
        i += 1
        if i < args.count { targetModel = args[i].lowercased() }
    case "--device", "-d":
        i += 1
        if i < args.count { deviceTarget = args[i] }
    case "--timeout", "-t":
        i += 1
        if i < args.count, let v = Double(args[i]) { scanTimeout = v }
    case "--json":
        outputJSON = true
    case "--off", "--stop", "off", "stop":
        ledOff = true
    case "-o", "--output":
        i += 1
        if i < args.count { outputPath = args[i] }
    case "--mode", "-m":
        i += 1
        if i < args.count {
            let mStr = args[i].lowercased()
            if mStr == "none" || mStr == "neutral" || mStr == "standard" {
                printMode = .none
            } else if let m = InstaxPrintMode(rawValue: mStr) {
                printMode = m
            }
        }
    case "--fit", "-f":
        i += 1
        if i < args.count, let f = InstaxFitMode(rawValue: args[i].lowercased()) {
            imgOptions.fitMode = f
        }
    case "--bg":
        i += 1
        if i < args.count { imgOptions.backgroundColor = parseHexColor(args[i]) }
    case "--zoom":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.zoom = v }
    case "--offset-x":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.offsetX = v }
    case "--offset-y":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.offsetY = v }
    case "--rotate", "-r":
        i += 1
        if i < args.count, let v = Int(args[i]) { imgOptions.rotationDegrees = v }
    case "--brightness":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.brightness = v }
    case "--contrast":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.contrast = v }
    case "--saturation":
        i += 1
        if i < args.count, let v = Double(args[i]) { imgOptions.saturation = v }
    case "--qr":
        i += 1
        if i < args.count { imgOptions.qrContent = args[i] }
    case "--qr-pos":
        i += 1
        if i < args.count, let p = InstaxQRPosition(rawValue: args[i]) { imgOptions.qrPosition = p }
    case "--qr-size":
        i += 1
        if i < args.count, let s = InstaxQRSize(rawValue: args[i].lowercased()) { imgOptions.qrSize = s }
    case "--qr-style":
        i += 1
        if i < args.count, let st = InstaxQRStyle(rawValue: args[i].lowercased()) { imgOptions.qrStyle = st }
    case "--caption":
        i += 1
        if i < args.count { imgOptions.captionText = args[i] }
    case "--border":
        i += 1
        if i < args.count, let b = InstaxBorderColor(rawValue: args[i].lowercased()) { imgOptions.borderColor = b }
    case "--collage":
        i += 1
        if i < args.count, let lay = InstaxCollageLayout(rawValue: args[i]) { collageLayout = lay }
    case "--collage-spacing":
        i += 1
        if i < args.count, let sp = Double(args[i]) { collageSpacing = CGFloat(sp) }
    case "--frame-style":
        i += 1
        if i < args.count { imgOptions.frameStyle = args[i] }
    case "--sticker":
        i += 1
        if i < args.count { imgOptions.sticker = args[i] }
    case "--sticker-image":
        i += 1
        if i < args.count {
            if let customImg = NSImage(contentsOfFile: args[i]) {
                imgOptions.stickerImage = customImg
            }
        }
    case "--sticker-pos":
        i += 1
        if i < args.count { imgOptions.stickerPosition = args[i] }
    case "--sticker-scale":
        i += 1
        if i < args.count, let sc = Double(args[i]) { imgOptions.stickerScale = sc }
    case "--sticker-opacity":
        i += 1
        if i < args.count, let op = Double(args[i]) { imgOptions.stickerOpacity = op }
    case "--sticker-rot", "--sticker-rotation":
        i += 1
        if i < args.count, let rot = Double(args[i]) { imgOptions.stickerRotation = rot }
    case "--sticker-x":
        i += 1
        if i < args.count, let sx = Double(args[i]) {
            imgOptions.stickerX = sx
            imgOptions.stickerPosition = "custom"
        }
    case "--sticker-y":
        i += 1
        if i < args.count, let sy = Double(args[i]) {
            imgOptions.stickerY = sy
            imgOptions.stickerPosition = "custom"
        }
    case "--banner-text":
        i += 1
        if i < args.count { imgOptions.bannerText = args[i] }
    case "--banner-style":
        i += 1
        if i < args.count { imgOptions.bannerStyle = args[i] }
    case "--banner-icon":
        i += 1
        if i < args.count { imgOptions.bannerIcon = args[i] }
    case "--banner-color", "--banner-bg-color":
        i += 1
        if i < args.count { imgOptions.bannerBgColor = args[i] }
    case "--banner-text-color":
        i += 1
        if i < args.count { imgOptions.bannerTextColor = args[i] }
    case "--banner-x":
        i += 1
        if i < args.count, let bx = Double(args[i]) { imgOptions.bannerX = bx }
    case "--banner-y":
        i += 1
        if i < args.count, let by = Double(args[i]) { imgOptions.bannerY = by }
    case "--banner-scale":
        i += 1
        if i < args.count, let bsc = Double(args[i]) { imgOptions.bannerScale = bsc }
    case "--banner-rot", "--banner-rotation":
        i += 1
        if i < args.count, let brot = Double(args[i]) { imgOptions.bannerRotation = brot }
    default:
        if !arg.hasPrefix("-") {
            inputImagePaths.append(arg)
        }
    }
    i += 1
}

Task {
    do {
        switch command {
        case "scan":
            print("Scanning for Instax Bluetooth printers (\(Int(scanTimeout))s)...")
            let ble = InstaxBLEController()
            let printers = try await ble.scanForPrinters(duration: scanTimeout)
            if outputJSON {
                let items = printers.map { ["name": $0.name, "id": $0.id, "rssi": "\($0.rssi)"] }
                let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else if printers.isEmpty {
                print("No Instax printers discovered.")
                print("Tip: Make sure your Instax SQUARE Link is powered ON and tap 'Disconnect' in the iPhone app.")
            } else {
                print("Found \(printers.count) Instax printer(s):")
                for p in printers {
                    print("  • \(p.name)  [UUID: \(p.id), RSSI: \(p.rssi) dBm]")
                }
            }
            exit(0)

        case "status":
            let ble = InstaxBLEController()
            if !outputJSON {
                print("Connecting to \(deviceTarget)...")
            }
            try await ble.connect(targetNameOrPrefix: deviceTarget, timeout: 8.0)
            let status = try await ble.fetchStatus()
            ble.disconnect()

            if outputJSON {
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try enc.encode(status)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                let chargeText = status.isCharging ? "Charging ⚡️" : "On Battery"
                print("""
                ──────────────────────────────────────────────────
                Instax Printer Status (\(status.deviceName))
                ──────────────────────────────────────────────────
                  Manufacturer : \(status.manufacturer.isEmpty ? "FUJIFILM" : status.manufacturer)
                  Model        : \(status.modelNumber.isEmpty ? "INSTAX SQUARE Link" : status.modelNumber)
                  Firmware     : \(status.firmwareVersion.isEmpty ? "N/A" : status.firmwareVersion)
                  Resolution   : \(status.width) × \(status.height) px (Max JPEG: \(status.maxJpegSize / 1024) KB, Chunk: \(status.chunkSize) B)
                  Film Left    : \(status.filmRemaining) / 10
                  Battery      : \(status.batteryPercent)% (Level \(status.batteryLevel)/4 — \(chargeText))
                  Back Cover   : \(status.isCoverOpen ? "OPEN ⚠️" : "Closed ✓")
                  Error State  : \(status.hasError ? status.printerErrorDescription : "None ✓")
                  Total Prints : \(status.totalPrints)
                ──────────────────────────────────────────────────
                """)
            }
            exit(0)

        case "ping":
            let ble = InstaxBLEController()
            print("Connecting to \(deviceTarget)...")
            try await ble.connect(targetNameOrPrefix: deviceTarget, timeout: 8.0)
            let status = try await ble.fetchStatus()
            let chargeText = status.isCharging ? "Charging ⚡️" : "Discharging"
            print("""
            ✓ Connected to \(status.deviceName)
              Model        : \(status.modelNumber)
              Firmware     : \(status.firmwareVersion)
              Resolution   : \(status.width) × \(status.height) px (MTU: \(status.chunkSize > 0 ? status.chunkSize : 1808)B)
              Film Left    : \(status.filmRemaining)/10
              Battery      : \(status.batteryPercent)% (Level \(status.batteryLevel)/4 — \(chargeText))
              Error State  : \(status.hasError ? status.printerErrorDescription : "None ✓")
            """)
            print("Pulsing rainbow LED on printer body...")
            try await ble.flashRainbowLED()
            ble.disconnect()
            print("✓ Ping & hardware communication test OK!")
            exit(0)

        case "eject-cover", "eject":
            let ble = InstaxBLEController()
            print("Connecting to \(deviceTarget)...")
            try await ble.connect(targetNameOrPrefix: deviceTarget, timeout: 8.0)
            print("Sending REJECT_FILM_COVER to eject black plastic dark slide...")
            try await ble.ejectFilmCover()
            ble.disconnect()
            print("Done! Check that the protective black plastic sheet has cleared the slot.")
            exit(0)

        case "led":

            let ble = InstaxBLEController()
            print("Connecting to \(deviceTarget)...")
            try await ble.connect(targetNameOrPrefix: deviceTarget, timeout: 8.0)
            if ledOff {
                print("Stopping LED animation and restoring normal status LED...")
                try await ble.stopLED()
            } else {
                print("Flashing front LED rainbow pattern once (then auto-stopping)...")
                try await ble.flashRainbowLED()
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            ble.disconnect()
            print("Done!")
            exit(0)

        case "preview":
            let outPath = outputPath ?? "instax_preview.jpg"
            let targetW: Int
            let targetH: Int
            let maxB: Int
            switch targetModel {
            case "wide": targetW = 1260; targetH = 840; maxB = 200 * 1024
            case "mini": targetW = 600; targetH = 800; maxB = 54 * 1024
            default:     targetW = 800; targetH = 800; maxB = 60 * 1024
            }

            let rendered: NSImage?
            if let layout = collageLayout {
                let images = inputImagePaths.compactMap { NSImage(contentsOfFile: $0) }
                guard !images.isEmpty else {
                    fputs("Error: Could not load any images for collage preview.\n", stderr)
                    exit(1)
                }
                print("Rendering \(layout.title) collage from \(images.count) photo(s)...")
                rendered = InstaxImageRenderer.renderCollageSquare(
                    images: images,
                    layout: layout,
                    targetWidth: targetW,
                    targetHeight: targetH,
                    spacing: collageSpacing,
                    options: imgOptions
                )
            } else {
                guard let inPath = inputImagePaths.first else {
                    fputs("Error: Missing input image path for 'preview'.\n", stderr)
                    exit(1)
                }
                guard let srcImg = NSImage(contentsOfFile: inPath) else {
                    fputs("Error: Could not open image at '\(inPath)'.\n", stderr)
                    exit(1)
                }
                rendered = InstaxImageRenderer.renderSquareImage(from: srcImg, targetWidth: targetW, targetHeight: targetH, options: imgOptions)
            }

            guard let finalImg = rendered,
                  let compressed = InstaxImageRenderer.compressToJPEG(finalImg, maxBytes: maxB) else {
                fputs("Error: Failed to render Instax preview JPEG.\n", stderr)
                exit(1)
            }
            try compressed.data.write(to: URL(fileURLWithPath: outPath))
            print("Saved \(targetW)×\(targetH) preview (\(String(format: "%.1f", Double(compressed.data.count) / 1024.0)) KB, quality \(Int(compressed.quality * 100))%) to: \(outPath)")
            exit(0)

        case "print":
            guard !inputImagePaths.isEmpty else {
                fputs("Error: Provide one or more image paths to 'print'.\n", stderr)
                exit(1)
            }

            let ble = InstaxBLEController()
            print("Connecting to \(deviceTarget)...")
            try await ble.connect(targetNameOrPrefix: deviceTarget, timeout: 8.0)

            let initialStatus = try await ble.fetchStatus()
            if initialStatus.hasError {
                fputs("⚠️ Notice: Printer reports hardware flag 0xF4. If LED is flashing orange, ensure battery is charged (>20%) and film door/cover is clear.\n", stderr)
            }
            if initialStatus.batteryPercent <= 20 {
                fputs("⚠️ Notice: Battery is low (\(initialStatus.batteryPercent)%). The printer motor requires sufficient charge to eject physical film.\n", stderr)
            }

            // Determine dimensions based on model flag or connected hardware
            let targetW: Int
            let targetH: Int
            let maxB: Int
            switch targetModel {
            case "wide":
                targetW = 1260; targetH = 840; maxB = 200 * 1024
            case "mini":
                targetW = 600; targetH = 800; maxB = 54 * 1024
            case "square":
                targetW = 800; targetH = 800; maxB = 60 * 1024
            default: // "auto"
                targetW = initialStatus.width > 0 ? initialStatus.width : 800
                targetH = initialStatus.height > 0 ? initialStatus.height : 800
                if targetW == 600 || targetH == 600 {
                    maxB = 54 * 1024
                } else if targetW == 1260 || targetH == 1260 {
                    maxB = 200 * 1024
                } else {
                    maxB = 60 * 1024
                }
            }

            print("Target format: \(targetW) × \(targetH) px (max \(maxB / 1024) KB)")

            // Prepare jobs
            var preparedJobs: [(path: String, jpeg: Data, quality: Double)] = []

            if let layout = collageLayout {
                let images = inputImagePaths.compactMap { NSImage(contentsOfFile: $0) }
                guard !images.isEmpty else {
                    fputs("Error: Could not load any images for collage print.\n", stderr)
                    exit(1)
                }
                guard let rendered = InstaxImageRenderer.renderCollageSquare(
                    images: images,
                    layout: layout,
                    targetWidth: targetW,
                    targetHeight: targetH,
                    spacing: collageSpacing,
                    options: imgOptions
                ), let compressed = InstaxImageRenderer.compressToJPEG(rendered, maxBytes: maxB) else {
                    fputs("Error: Failed to render \(targetW)×\(targetH) collage JPEG.\n", stderr)
                    exit(1)
                }
                let collageTitle = "Collage-\(layout.rawValue)-\(images.count)photos.jpg"
                preparedJobs.append((collageTitle, compressed.data, compressed.quality))
            } else {
                for inPath in inputImagePaths {
                    let fileURL = URL(fileURLWithPath: inPath)
                    var srcImg = NSImage(contentsOfFile: inPath)
                    var loadedCG: CGImage? = nil
                    if let cgSrc = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                       let cg = CGImageSourceCreateImageAtIndex(cgSrc, 0, nil) {
                        loadedCG = cg
                        if srcImg == nil {
                            let rep = NSBitmapImageRep(cgImage: cg)
                            let img = NSImage(size: NSSize(width: cg.width, height: cg.height))
                            img.addRepresentation(rep)
                            srcImg = img
                        }
                    }
                    guard let validImg = srcImg else {
                        fputs("Error: Could not open image at '\(inPath)'.\n", stderr)
                        exit(1)
                    }

                    // Fast-path: if input is already an exact targetW×targetH JPEG <= maxB (e.g. from Local Wi-Fi Bridge), use it directly
                    if imgOptions.fitMode == .stretch,
                       imgOptions.qrCodeContent.isEmpty,
                       imgOptions.captionText.isEmpty,
                       imgOptions.rotationDegrees == 0,
                       let cg = loadedCG,
                       cg.width == targetW,
                       cg.height == targetH,
                       let rawData = try? Data(contentsOf: fileURL),
                       rawData.count >= 2,
                       rawData[0] == 0xFF, rawData[1] == 0xD8,
                       rawData.count <= maxB {
                        preparedJobs.append((inPath, rawData, 0.92))
                        continue
                    }

                    guard let rendered = InstaxImageRenderer.renderSquareImage(from: validImg, targetWidth: targetW, targetHeight: targetH, options: imgOptions),
                          let compressed = InstaxImageRenderer.compressToJPEG(rendered, maxBytes: maxB) else {
                        fputs("Error: Failed to render \(targetW)x\(targetH) JPEG for '\(inPath)'.\n", stderr)
                        exit(1)
                    }
                    preparedJobs.append((inPath, compressed.data, compressed.quality))
                }
            }

            if initialStatus.filmRemaining < preparedJobs.count {
                fputs("⚠️ Warning: Job has \(preparedJobs.count) print(s), but printer has \(initialStatus.filmRemaining)/10 film remaining.\n", stderr)
            }

            for (idx, job) in preparedJobs.enumerated() {
                let fileName = URL(fileURLWithPath: job.path).lastPathComponent
                let action = isDryRun ? "Simulating transfer for" : "Printing"
                print("\n[\(idx + 1)/\(preparedJobs.count)] \(action) '\(fileName)' (\(String(format: "%.1f", Double(job.jpeg.count) / 1024.0)) KB, Q\(Int(job.quality * 100)))...")
                let finalStatus = try await ble.printJPEG(job.jpeg, mode: printMode, dryRun: isDryRun) { stage, fraction in
                    let pct = Int((fraction * 100.0).rounded())
                    print(String(format: "  [%3d%%] %@", pct, stage))
                }
                if isDryRun {
                    print("  ✓ [DRY RUN SUCCESS] '\(fileName)' 100% verified by printer ASIC! Film remaining: \(finalStatus.filmRemaining)/10 (0 film used)")
                } else {
                    print("  ✓ Printed '\(fileName)'! Film remaining: \(finalStatus.filmRemaining)/10")
                }
                if idx + 1 < preparedJobs.count {
                    print("  Waiting 3s before next print in bulk queue...")
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }

            ble.disconnect()
            let completeMsg = isDryRun ? "🎉 Dry run complete (0 film used)!" : "🎉 Bulk print complete (\(preparedJobs.count) photo(s))!"
            print("\n\(completeMsg)")
            exit(0)

        default:
            fputs("Unknown command '\(command)'. Run 'instax-square --help' for usage.\n", stderr)
            exit(1)
        }
    } catch {
        fputs("❌ Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

RunLoop.main.run()
