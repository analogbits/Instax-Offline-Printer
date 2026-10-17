import Foundation
import CoreBluetooth
import AppKit
import CoreImage

// MARK: - Constants & Protocol Types

public enum InstaxConstants {
    public static let serviceUUID = CBUUID(string: "70954782-2d83-473d-9e5f-81e1d02d5273")
    public static let writeCharUUID = CBUUID(string: "70954783-2d83-473d-9e5f-81e1d02d5273")
    public static let notifyCharUUID = CBUUID(string: "70954784-2d83-473d-9e5f-81e1d02d5273")

    public static let defaultDeviceName = "INSTAX-"
    public static let squareWidth = 800
    public static let squareHeight = 800
    public static let maxJpegBytes = 60 * 1024
    public static let defaultChunkSize = 1808
}

public enum InstaxLogger {
    public static var onLog: ((String) -> Void)?

    public static func log(_ msg: String) {
        onLog?(msg)
    }
}

public struct InstaxSID: Equatable, Hashable, CustomStringConvertible {
    public let hi: UInt8
    public let lo: UInt8

    public init(_ hi: UInt8, _ lo: UInt8) {
        self.hi = hi
        self.lo = lo
    }

    public static let supportFunctionAndVersionInfo = InstaxSID(0, 0)
    public static let deviceInfoService             = InstaxSID(0, 1)
    public static let supportFunctionInfo           = InstaxSID(0, 2)
    public static let shutDown                      = InstaxSID(1, 0)
    public static let reset                         = InstaxSID(1, 1)
    public static let autoSleepSettings             = InstaxSID(1, 2)
    public static let bleConnect                    = InstaxSID(1, 3)
    public static let printImageDownloadStart       = InstaxSID(16, 0)
    public static let printImageDownloadData        = InstaxSID(16, 1)
    public static let printImageDownloadEnd         = InstaxSID(16, 2)
    public static let printImageDownloadCancel      = InstaxSID(16, 3)
    public static let printImage                    = InstaxSID(16, 128)
    public static let rejectFilmCover               = InstaxSID(16, 129)
    public static let ledPatternSettings            = InstaxSID(48, 1)

    public var name: String {
        switch (hi, lo) {
        case (0, 0): return "SupportFunctionAndVersionInfo"
        case (0, 1): return "DeviceInfoService"
        case (0, 2): return "SupportFunctionInfo"
        case (1, 0): return "ShutDown"
        case (1, 1): return "Reset"
        case (1, 2): return "AutoSleepSettings"
        case (1, 3): return "BLEConnect"
        case (16, 0): return "PrintImageDownloadStart"
        case (16, 1): return "PrintImageDownloadData"
        case (16, 2): return "PrintImageDownloadEnd"
        case (16, 3): return "PrintImageDownloadCancel"
        case (16, 128): return "PrintImage"
        case (16, 129): return "RejectFilmCover"
        case (48, 1): return "LedPatternSettings"
        default: return "SID(\(hi),\(lo))"
        }
    }

    public var description: String {
        name
    }
}

public enum InstaxFitMode: String, CaseIterable, Identifiable {
    case crop = "crop"
    case fit = "fit"
    case stretch = "stretch"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .crop: return "Fill Square (Crop)"
        case .fit: return "Fit Entire Image"
        case .stretch: return "Stretch"
        }
    }
}

public enum InstaxPrintMode: String, CaseIterable, Identifiable {
    case rich = "rich"
    case natural = "natural"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rich: return "instax-Rich Mode (Vibrant)"
        case .natural: return "instax-Natural Mode (Classic)"
        }
    }

    public var optionByte: UInt8 {
        switch self {
        case .rich: return 0x00
        case .natural: return 0x08
        }
    }
}

public enum InstaxFilterPreset: String, CaseIterable, Identifiable {
    case none = "none"
    case monochrome = "monochrome"
    case sepia = "sepia"
    case vintageWarm = "vintage"
    case coolFade = "cool"
    case vivid = "vivid"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Original"
        case .monochrome: return "B&W Mono"
        case .sepia: return "Warm Sepia"
        case .vintageWarm: return "Vintage Film"
        case .coolFade: return "Cool Fade"
        case .vivid: return "Vivid Pop"
        }
    }
}

public enum InstaxCollageLayout: String, CaseIterable, Identifiable {
    case single = "single"
    case split2V = "split2V"
    case split2H = "split2H"
    case split3Hero = "split3Hero"
    case split3V = "split3V"
    case split3H = "split3H"
    case grid4 = "grid4"
    case strips4V = "strips4V"
    case grid6 = "grid6"
    case grid8 = "grid8"
    case grid9 = "grid9"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .single: return "Single Photo"
        case .split2V: return "2-Split (Left / Right)"
        case .split2H: return "2-Split (Top / Bottom)"
        case .split3Hero: return "3-Split (Hero Left + 2 Stacked)"
        case .split3V: return "3-Stripes (Vertical WIDE)"
        case .split3H: return "3-Split (Hero Top + 2 Bottom)"
        case .grid4: return "4-Grid (2 × 2)"
        case .strips4V: return "4-Stripes (Photo Booth WIDE)"
        case .grid6: return "6-Grid (3 × 2 WIDE)"
        case .grid8: return "8-Grid (4 × 2 WIDE)"
        case .grid9: return "9-Grid (3 × 3)"
        }
    }

    public var requiredPhotos: Int {
        switch self {
        case .single: return 1
        case .split2V, .split2H: return 2
        case .split3Hero, .split3V, .split3H: return 3
        case .grid4, .strips4V: return 4
        case .grid6: return 6
        case .grid8: return 8
        case .grid9: return 9
        }
    }

    public var icon: String {
        switch self {
        case .single: return "square"
        case .split2V: return "rectangle.split.2x1"
        case .split2H: return "rectangle.split.1x2"
        case .split3Hero: return "rectangle.split.2x2"
        case .split3V: return "rectangle.split.3x1"
        case .split3H: return "rectangle.split.1x2"
        case .grid4: return "square.grid.2x2"
        case .strips4V: return "rectangle.split.3x1"
        case .grid6: return "square.grid.3x2"
        case .grid8: return "square.grid.4x2"
        case .grid9: return "square.grid.3x3"
        }
    }

    public var shortTitle: String {
        switch self {
        case .single: return "Single"
        case .split2V: return "2-Split (V)"
        case .split2H: return "2-Split (H)"
        case .split3Hero: return "3-Split (Hero)"
        case .split3V: return "3-Stripes"
        case .split3H: return "3-Split (Top)"
        case .grid4: return "4-Grid"
        case .strips4V: return "4-Stripes"
        case .grid6: return "6-Grid"
        case .grid8: return "8-Grid"
        case .grid9: return "9-Grid"
        }
    }
}

public enum InstaxQRPosition: String, CaseIterable, Identifiable {
    case bottomRight = "bottomRight"
    case bottomLeft = "bottomLeft"
    case topRight = "topRight"
    case topLeft = "topLeft"
    case bottomCenter = "bottomCenter"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .bottomRight: return "Bottom-Right"
        case .bottomLeft: return "Bottom-Left"
        case .topRight: return "Top-Right"
        case .topLeft: return "Top-Left"
        case .bottomCenter: return "Bottom-Center"
        }
    }
}

public enum InstaxQRSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    public func pixelSize(forTargetWidth w: Int) -> CGFloat {
        switch self {
        case .small: return CGFloat(w) * 0.15
        case .medium: return CGFloat(w) * 0.20
        case .large: return CGFloat(w) * 0.26
        }
    }
}

public enum InstaxQRStyle: String, CaseIterable, Identifiable {
    case frosted = "frosted"
    case solidWhite = "solidWhite"
    case minimal = "minimal"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .frosted: return "Translucent Glass"
        case .solidWhite: return "Solid White"
        case .minimal: return "Dark Vignette"
        }
    }
}

public enum InstaxBorderColor: String, CaseIterable, Identifiable {
    case white = "white"
    case black = "black"
    case cream = "cream"
    case pastelPink = "pink"
    case pastelBlue = "blue"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .white: return "Classic White"
        case .black: return "Black Film"
        case .cream: return "Warm Cream"
        case .pastelPink: return "Pastel Pink"
        case .pastelBlue: return "Pastel Blue"
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .white: return NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .black: return NSColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        case .cream: return NSColor(srgbRed: 0.98, green: 0.96, blue: 0.90, alpha: 1.0)
        case .pastelPink: return NSColor(srgbRed: 0.98, green: 0.90, blue: 0.92, alpha: 1.0)
        case .pastelBlue: return NSColor(srgbRed: 0.90, green: 0.94, blue: 0.98, alpha: 1.0)
        }
    }
}

public struct InstaxImageOptions {
    public var fitMode: InstaxFitMode = .crop
    public var backgroundColor: NSColor = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    public var zoom: Double = 1.0
    public var offsetX: Double = 0.0
    public var offsetY: Double = 0.0
    public var rotationDegrees: Int = 0
    public var brightness: Double = 0.0   // [-0.5, 0.5]
    public var contrast: Double = 1.0     // [0.5, 1.8]
    public var saturation: Double = 1.0   // [0.0, 2.0]
    public var printMode: InstaxPrintMode = .rich
    public var filter: InstaxFilterPreset = .none
    public var borderColor: InstaxBorderColor = .white
    public var captionText: String = ""
    public var showDateStamp: Bool = false
    public var collageSpacing: Double = 8.0
    public var collageLayout: InstaxCollageLayout = .single

    // Rich QR Code Overlays (Web link, text, phone number, Wi-Fi, location)
    public var qrCodeContent: String = ""
    public var qrCodePosition: InstaxQRPosition = .bottomRight
    public var qrCodeSize: InstaxQRSize = .medium
    public var qrCodeStyle: InstaxQRStyle = .frosted

    public var qrContent: String {
        get { qrCodeContent }
        set { qrCodeContent = newValue }
    }
    public var qrPosition: InstaxQRPosition {
        get { qrCodePosition }
        set { qrCodePosition = newValue }
    }
    public var qrSize: InstaxQRSize {
        get { qrCodeSize }
        set { qrCodeSize = newValue }
    }
    public var qrStyle: InstaxQRStyle {
        get { qrCodeStyle }
        set { qrCodeStyle = newValue }
    }

    public init() {}
}

public struct PrinterStatus: Codable {
    public var deviceName: String = ""
    public var identifier: String = ""
    public var manufacturer: String = ""
    public var modelNumber: String = ""
    public var firmwareVersion: String = ""
    public var width: Int = InstaxConstants.squareWidth
    public var height: Int = InstaxConstants.squareHeight
    public var chunkSize: Int = InstaxConstants.defaultChunkSize
    public var maxJpegSize: Int = InstaxConstants.maxJpegBytes
    public var supports3DLut: Bool = true
    public var batteryPercent: Int = 0
    public var batteryLevel: Int = 0
    public var isCharging: Bool = false
    public var filmRemaining: Int = 0
    public var isCoverOpen: Bool = false
    public var isBusy: Bool = false
    public var hasError: Bool = false
    public var totalPrints: Int = 0
    public var waitSeconds: Int = 15
    public var resultPrintRequest: UInt8 = 0
    public var printerErrorType: UInt32 = 0

    public var printerErrorDescription: String {
        guard hasError || resultPrintRequest == 0xF0 else { return "None" }
        if (printerErrorType & 0x20) != 0 {
            return "Film Ejection Fault / Mechanical Jam (Error 0x20): The printer was unable to cycle the film sheet. If this is a new pack, ensure the black protective plastic dark slide has ejected and the door is clicked shut."
        }
        if (printerErrorType & 0x10) != 0 {
            return "Film Cover Jammed (Error 0x10): The black protective dark slide is jammed in the ejection slot."
        }
        if (printerErrorType & 0x40) != 0 || isCoverOpen {
            return "Film Door Ajar (Error 0x40): The back film door is open or unlatched."
        }
        if (printerErrorType & 0x08) != 0 {
            return "Battery Charge Fault (Error 0x08): Insufficient power to cycle print motor."
        }
        if (printerErrorType & 0x04) != 0 {
            return "Battery Overheating (Error 0x04): Printer temperature is abnormal."
        }
        if (printerErrorType & 0x01) != 0 || (printerErrorType & 0x02) != 0 {
            return "Battery Fault: Battery cannot deliver necessary current to eject film."
        }
        if resultPrintRequest == 0xF0 {
            return "Print Request Rejected (0xF0): Internal mechanical mechanism halted operation."
        }
        if resultPrintRequest == 0x02 {
            return "No Film Remaining: The film pack is empty (0/10)."
        }
        return "Printer Hardware Error (Type: \(String(format: "0x%02X", printerErrorType)), Status: \(String(format: "0x%02X", resultPrintRequest)))"
    }

    public init() {}
}


// MARK: - Packet Framing

public struct InstaxResponse {
    public let sid: InstaxSID
    public let resultCode: UInt8
    public let payload: Data

    public var isOK: Bool { resultCode == 0 }

    public var resultDescription: String {
        switch resultCode {
        case 0: return "OK"
        case 1: return "PRINTER_BUSY"
        case 2: return "CAMERA_BUSY"
        case 127: return "PENDING_RESPONSE"
        case 128: return "SID_NOT_SUPPORTED"
        case 129: return "PARAMETER_ERROR"
        case 130: return "SEQUENCE_ERROR"
        case 144: return "LOW_POWER_ERROR"
        case 145: return "BATTERY_NO_MOUNT_ERROR"
        case 146: return "BATTERY_OVERHEAT_ERROR"
        case 176: return "COVER_OPEN_ERROR"
        case 177: return "NO_FILM_ERROR"
        case 178: return "NO_PAPER_ERROR"
        case 179: return "IMAGE_ERROR"
        case 180: return "PAPER_JAMMED_ERROR"
        case 181: return "PRINT_FAULT_ERROR"
        case 192: return "MEMORY_FULL_ERROR"
        case 194: return "NOW_PRINTING_ERROR"
        default: return "ERROR_\(resultCode)"
        }
    }
}

public enum InstaxPacket {
    /// Build an outbound packet with `0x41 0x62` ('Ab') header and 1-byte checksum.
    public static func build(sid: InstaxSID, payload: Data = Data()) -> Data {
        let totalLength = UInt16(7 + payload.count)
        var bytes = Data(capacity: Int(totalLength))
        bytes.append(0x41) // 'A'
        bytes.append(0x62) // 'b'
        bytes.append(UInt8((totalLength >> 8) & 0xFF))
        bytes.append(UInt8(totalLength & 0xFF))
        bytes.append(sid.hi)
        bytes.append(sid.lo)
        bytes.append(payload)

        var sum: Int = 0
        for b in bytes {
            sum = (sum + Int(b)) & 0xFF
        }
        let checksum = UInt8((255 - sum) & 0xFF)
        bytes.append(checksum)
        return bytes
    }

    /// Parse a complete inbound packet with `0x61 0x42` ('aB') header.
    public static func parse(_ data: Data) throws -> InstaxResponse {
        guard data.count >= 8 else {
            throw NSError(domain: "InstaxPacket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Response too short (\(data.count) bytes)"])
        }
        let b = [UInt8](data)
        guard b[0] == 0x61 && b[1] == 0x42 else {
            throw NSError(domain: "InstaxPacket", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response header"])
        }
        let expectedLen = (Int(b[2]) << 8) | Int(b[3])
        guard b.count >= expectedLen, expectedLen >= 8 else {
            throw NSError(domain: "InstaxPacket", code: 3, userInfo: [NSLocalizedDescriptionKey: "Incomplete response (\(b.count)/\(expectedLen) bytes)"])
        }
        var sum = 0
        for i in 0..<(expectedLen - 1) {
            sum = (sum + Int(b[i])) & 0xFF
        }
        let expectedChecksum = UInt8((255 - sum) & 0xFF)
        let actualChecksum = b[expectedLen - 1]
        guard expectedChecksum == actualChecksum else {
            throw NSError(domain: "InstaxPacket", code: 4, userInfo: [NSLocalizedDescriptionKey: "Checksum mismatch"])
        }
        let sid = InstaxSID(b[4], b[5])
        let resultCode = b[6]
        let payload = expectedLen > 8 ? Data(b[7..<(expectedLen - 1)]) : Data()
        return InstaxResponse(sid: sid, resultCode: resultCode, payload: payload)
    }
}

// MARK: - 800x800 Square Image Renderer & JPEG Compressor

public enum InstaxImageRenderer {
    /// Extract a normalized, upright CGImage from an NSImage with EXIF orientation transforms applied.
    public static func getNormalizedCGImage(from sourceImage: NSImage) -> CGImage? {
        for rep in sourceImage.representations {
            if let bmp = rep as? NSBitmapImageRep, let cg = bmp.cgImage {
                return cg
            }
        }
        if let cg = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        if let tiff = sourceImage.tiffRepresentation,
           let source = CGImageSourceCreateWithData(tiff as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailWithTransform: true,
               kCGImageSourceCreateThumbnailFromImageAlways: true
           ] as CFDictionary) {
            return cg
        }
        return nil
    }

    /// Render an NSImage into an 800x800 square image with crop/fit/stretch, zoom, pan, rotation, filters, and color adjustments.
    public static func renderSquareImage(
        from sourceImage: NSImage,
        targetWidth: Int = InstaxConstants.squareWidth,
        targetHeight: Int = InstaxConstants.squareHeight,
        options: InstaxImageOptions = InstaxImageOptions()
    ) -> NSImage? {
        guard let cgSource = getNormalizedCGImage(from: sourceImage) else {
            return nil
        }

        let deg = ((options.rotationDegrees % 360) + 360) % 360
        let isNaturalMode = (options.printMode == .natural)
        let hasFilter = (options.filter != .none)
        let needsColorFilter = abs(options.brightness) > 0.001 || abs(options.contrast - 1.0) > 0.001 || abs(options.saturation - 1.0) > 0.001 || isNaturalMode || hasFilter

        let processedCG: CGImage
        if deg != 0 || needsColorFilter {
            var ciImage = CIImage(cgImage: cgSource)
            if deg == 90 {
                ciImage = ciImage.oriented(.right)
            } else if deg == 180 {
                ciImage = ciImage.oriented(.down)
            } else if deg == 270 {
                ciImage = ciImage.oriented(.left)
            }

            // Apply selected artistic filter
            switch options.filter {
            case .monochrome:
                if let mono = CIFilter(name: "CIPhotoEffectMono") {
                    mono.setValue(ciImage, forKey: kCIInputImageKey)
                    if let out = mono.outputImage { ciImage = out }
                }
            case .sepia:
                if let sepia = CIFilter(name: "CISepiaTone") {
                    sepia.setValue(ciImage, forKey: kCIInputImageKey)
                    sepia.setValue(0.85, forKey: kCIInputIntensityKey)
                    if let out = sepia.outputImage { ciImage = out }
                }
            case .vintageWarm:
                if let warm = CIFilter(name: "CIPhotoEffectInstant") {
                    warm.setValue(ciImage, forKey: kCIInputImageKey)
                    if let out = warm.outputImage { ciImage = out }
                }
            case .coolFade:
                if let fade = CIFilter(name: "CIPhotoEffectFade") {
                    fade.setValue(ciImage, forKey: kCIInputImageKey)
                    if let out = fade.outputImage { ciImage = out }
                }
            case .vivid:
                if let chrome = CIFilter(name: "CIPhotoEffectChrome") {
                    chrome.setValue(ciImage, forKey: kCIInputImageKey)
                    if let out = chrome.outputImage { ciImage = out }
                }
            case .none:
                break
            }

            // In natural mode, simulate Fujifilm's 3D-LUT analog instant film curve:
            // softer contrast, subtle warm organic highlights, and gently lifted shadow roll-off
            let effectiveBrightness = options.brightness + (isNaturalMode ? 0.03 : 0.0)
            let effectiveContrast = options.contrast * (isNaturalMode ? 0.92 : 1.0)
            let effectiveSaturation = options.saturation * (isNaturalMode ? 0.96 : 1.0)

            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(effectiveBrightness, forKey: kCIInputBrightnessKey)
                filter.setValue(effectiveContrast, forKey: kCIInputContrastKey)
                filter.setValue(effectiveSaturation, forKey: kCIInputSaturationKey)
                if let out = filter.outputImage {
                    ciImage = out
                }
            }

            if isNaturalMode, let tempFilter = CIFilter(name: "CITemperatureAndTint") {
                tempFilter.setValue(ciImage, forKey: kCIInputImageKey)
                tempFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tempFilter.setValue(CIVector(x: 6850, y: 8), forKey: "inputTargetNeutral")
                if let out = tempFilter.outputImage {
                    ciImage = out
                }
            }

            let ciContext = CIContext(options: [.useSoftwareRenderer: true])
            guard let cgOut = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }
            processedCG = cgOut
        } else {
            processedCG = cgSource
        }

        let srcW = Double(processedCG.width)
        let srcH = Double(processedCG.height)
        let dstW = Double(targetWidth)
        let dstH = Double(targetHeight)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Fill background with selected border color
        let fallbackWhite = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let bgRGB = (options.fitMode == .fit ? options.backgroundColor : options.borderColor.nsColor).usingColorSpace(.sRGB) ?? fallbackWhite
        ctx.setFillColor(red: bgRGB.redComponent, green: bgRGB.greenComponent, blue: bgRGB.blueComponent, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: dstW, height: dstH))
        ctx.interpolationQuality = .high

        let zoom = max(0.2, options.zoom)
        var drawRect: CGRect

        switch options.fitMode {
        case .stretch:
            let w = dstW * zoom
            let h = dstH * zoom
            let x = (dstW - w) / 2.0 + options.offsetX * (dstW / 2.0)
            let y = (dstH - h) / 2.0 - options.offsetY * (dstH / 2.0)
            drawRect = CGRect(x: x, y: y, width: w, height: h)

        case .fit:
            let scale = min(dstW / srcW, dstH / srcH) * zoom
            let w = srcW * scale
            let h = srcH * scale
            let x = (dstW - w) / 2.0 + options.offsetX * (dstW / 2.0)
            let y = (dstH - h) / 2.0 - options.offsetY * (dstH / 2.0)
            drawRect = CGRect(x: x, y: y, width: w, height: h)

        case .crop:
            let scale = max(dstW / srcW, dstH / srcH) * zoom
            let w = srcW * scale
            let h = srcH * scale
            let maxDX = max(dstW * 0.25, (w - dstW) / 2.0)
            let maxDY = max(dstH * 0.25, (h - dstH) / 2.0)
            let x = (dstW - w) / 2.0 + options.offsetX * maxDX
            let y = (dstH - h) / 2.0 - options.offsetY * maxDY
            drawRect = CGRect(x: x, y: y, width: w, height: h)
        }

        ctx.draw(processedCG, in: drawRect)

        // Draw optional caption or date stamp on bottom using CoreText (headless-safe)
        if !options.captionText.isEmpty || options.showDateStamp {
            let stampText: String
            if !options.captionText.isEmpty && options.showDateStamp {
                let df = DateFormatter()
                df.dateStyle = .medium
                stampText = "\(options.captionText) • \(df.string(from: Date()))"
            } else if !options.captionText.isEmpty {
                stampText = options.captionText
            } else {
                let df = DateFormatter()
                df.dateStyle = .long
                stampText = df.string(from: Date())
            }

            let ctFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 22.0, nil)
            let whiteCG = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            let ctAttrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): whiteCG
            ]
            let attrStr = NSAttributedString(string: stampText, attributes: ctAttrs)
            let ctLine = CTLineCreateWithAttributedString(attrStr)
            let lineBounds = CTLineGetBoundsWithOptions(ctLine, [])

            // Draw translucent pill behind text for contrast
            let pillRect = CGRect(x: (dstW - lineBounds.width - 24) / 2.0, y: 22, width: lineBounds.width + 24, height: lineBounds.height + 12)
            ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.55)
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            ctx.addPath(pillPath)
            ctx.fillPath()

            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.textPosition = CGPoint(x: (dstW - lineBounds.width) / 2.0, y: 28 - lineBounds.origin.y * 0.5)
            CTLineDraw(ctLine, ctx)
            ctx.restoreGState()
        }

        // Draw optional QR Code (Rich QR / Web link / Secret text / Contact)
        let trimmedQR = options.qrCodeContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQR.isEmpty {
            let qrSize = options.qrCodeSize.pixelSize(forTargetWidth: targetWidth)
            if let qrImage = generateQRCode(from: trimmedQR, size: qrSize) {
                let margin: CGFloat = max(18.0, dstW * 0.035)
                let qrRect: CGRect
                switch options.qrCodePosition {
                case .bottomRight:
                    qrRect = CGRect(x: dstW - qrSize - margin, y: margin, width: qrSize, height: qrSize)
                case .bottomLeft:
                    qrRect = CGRect(x: margin, y: margin, width: qrSize, height: qrSize)
                case .topRight:
                    qrRect = CGRect(x: dstW - qrSize - margin, y: dstH - qrSize - margin, width: qrSize, height: qrSize)
                case .topLeft:
                    qrRect = CGRect(x: margin, y: dstH - qrSize - margin, width: qrSize, height: qrSize)
                case .bottomCenter:
                    qrRect = CGRect(x: (dstW - qrSize) / 2.0, y: margin, width: qrSize, height: qrSize)
                }

                let badgePadding: CGFloat = 8.0
                let badgeRect = qrRect.insetBy(dx: -badgePadding, dy: -badgePadding)
                switch options.qrCodeStyle {
                case .frosted:
                    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                    ctx.setStrokeColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
                    ctx.setLineWidth(1.5)
                    ctx.addPath(path)
                    ctx.strokePath()
                case .solidWhite:
                    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                case .minimal:
                    ctx.setFillColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.65)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                }

                ctx.draw(qrImage, in: qrRect)
            }
        }

        guard let outCG = ctx.makeImage() else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: outCG)
        rep.size = NSSize(width: targetWidth, height: targetHeight)
        let outImg = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        outImg.addRepresentation(rep)
        return outImg
    }

    /// Generate a crisp vector QR code using macOS CoreImage CIQRCodeGenerator.
    public static func generateQRCode(from text: String, size: CGFloat) -> CGImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputCI = filter.outputImage else { return nil }

        let scale = size / outputCI.extent.size.width
        let transformed = outputCI.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ciContext = CIContext(options: [.useSoftwareRenderer: true])
        return ciContext.createCGImage(transformed, from: transformed.extent.integral)
    }

    /// Render 2 to 9 images into a collage canvas (supports Square 800x800, WIDE 1260x840, or Mini 600x800).
    public static func renderCollageSquare(
        images: [NSImage],
        layout: InstaxCollageLayout,
        targetWidth: Int = InstaxConstants.squareWidth,
        targetHeight: Int = InstaxConstants.squareHeight,
        spacing: CGFloat = 8,
        options: InstaxImageOptions = InstaxImageOptions()
    ) -> NSImage? {
        guard !images.isEmpty else { return nil }
        let dstW = CGFloat(targetWidth)
        let dstH = CGFloat(targetHeight)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Fill background with border color
        let fallbackWhite = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let bgRGB = options.borderColor.nsColor.usingColorSpace(.sRGB) ?? fallbackWhite
        ctx.setFillColor(red: bgRGB.redComponent, green: bgRGB.greenComponent, blue: bgRGB.blueComponent, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: dstW, height: dstH))
        ctx.interpolationQuality = .high

        let m = max(0.0, spacing) // Outer perimeter margin matches inner spacing
        var slots: [CGRect] = []

        switch layout {
        case .single:
            slots = [CGRect(x: m, y: m, width: dstW - 2 * m, height: dstH - 2 * m)]

        case .split2V:
            let w = (dstW - 2 * m - spacing) / 2.0
            let h = dstH - 2 * m
            slots = [
                CGRect(x: m, y: m, width: w, height: h),
                CGRect(x: m + w + spacing, y: m, width: w, height: h)
            ]

        case .split2H:
            let w = dstW - 2 * m
            let h = (dstH - 2 * m - spacing) / 2.0
            slots = [
                CGRect(x: m, y: m + h + spacing, width: w, height: h), // Top
                CGRect(x: m, y: m, width: w, height: h)                // Bottom
            ]

        case .split3Hero:
            let leftW = (dstW - 2 * m - spacing) / 2.0
            let rightW = leftW
            let rightH = (dstH - 2 * m - spacing) / 2.0
            slots = [
                CGRect(x: m, y: m, width: leftW, height: dstH - 2 * m),                          // Large Left
                CGRect(x: m + leftW + spacing, y: m + rightH + spacing, width: rightW, height: rightH), // Top Right
                CGRect(x: m + leftW + spacing, y: m, width: rightW, height: rightH)           // Bottom Right
            ]

        case .split3V:
            let w = (dstW - 2 * m - 2 * spacing) / 3.0
            let h = dstH - 2 * m
            slots = [
                CGRect(x: m, y: m, width: w, height: h),
                CGRect(x: m + w + spacing, y: m, width: w, height: h),
                CGRect(x: m + 2 * (w + spacing), y: m, width: w, height: h)
            ]

        case .split3H:
            let topH = (dstH - 2 * m - spacing) / 2.0
            let botH = topH
            let cellW = (dstW - 2 * m - spacing) / 2.0
            slots = [
                CGRect(x: m, y: m + botH + spacing, width: dstW - 2 * m, height: topH), // Large Top
                CGRect(x: m, y: m, width: cellW, height: botH),                          // Bottom Left
                CGRect(x: m + cellW + spacing, y: m, width: cellW, height: botH)          // Bottom Right
            ]

        case .grid4:
            let cellW = (dstW - 2 * m - spacing) / 2.0
            let cellH = (dstH - 2 * m - spacing) / 2.0
            slots = [
                CGRect(x: m, y: m + cellH + spacing, width: cellW, height: cellH),                 // Top Left
                CGRect(x: m + cellW + spacing, y: m + cellH + spacing, width: cellW, height: cellH),   // Top Right
                CGRect(x: m, y: m, width: cellW, height: cellH),                                   // Bottom Left
                CGRect(x: m + cellW + spacing, y: m, width: cellW, height: cellH)                  // Bottom Right
            ]

        case .strips4V:
            let w = (dstW - 2 * m - 3 * spacing) / 4.0
            let h = dstH - 2 * m
            for col in 0..<4 {
                slots.append(CGRect(x: m + CGFloat(col) * (w + spacing), y: m, width: w, height: h))
            }

        case .grid6:
            let cellW = (dstW - 2 * m - 2 * spacing) / 3.0
            let cellH = (dstH - 2 * m - spacing) / 2.0
            // Row 1 (Top)
            for col in 0..<3 {
                slots.append(CGRect(x: m + CGFloat(col) * (cellW + spacing), y: m + cellH + spacing, width: cellW, height: cellH))
            }
            // Row 2 (Bottom)
            for col in 0..<3 {
                slots.append(CGRect(x: m + CGFloat(col) * (cellW + spacing), y: m, width: cellW, height: cellH))
            }

        case .grid8:
            let cellW = (dstW - 2 * m - 3 * spacing) / 4.0
            let cellH = (dstH - 2 * m - spacing) / 2.0
            // Row 1 (Top)
            for col in 0..<4 {
                slots.append(CGRect(x: m + CGFloat(col) * (cellW + spacing), y: m + cellH + spacing, width: cellW, height: cellH))
            }
            // Row 2 (Bottom)
            for col in 0..<4 {
                slots.append(CGRect(x: m + CGFloat(col) * (cellW + spacing), y: m, width: cellW, height: cellH))
            }

        case .grid9:
            let cellW = (dstW - 2 * m - 2 * spacing) / 3.0
            let cellH = (dstH - 2 * m - 2 * spacing) / 3.0
            for row in (0..<3).reversed() {
                for col in 0..<3 {
                    slots.append(CGRect(x: m + CGFloat(col) * (cellW + spacing), y: m + CGFloat(row) * (cellH + spacing), width: cellW, height: cellH))
                }
            }
        }

        var slotOptions = options
        slotOptions.qrCodeContent = ""
        slotOptions.captionText = ""
        slotOptions.showDateStamp = false

        for (idx, slot) in slots.enumerated() {
            let img = images[idx % images.count]
            if let renderedSlot = renderSquareImage(from: img, targetWidth: Int(slot.width), targetHeight: Int(slot.height), options: slotOptions),
               let cg = getNormalizedCGImage(from: renderedSlot) {
                ctx.draw(cg, in: slot)
            }
        }

        // Draw optional QR Code (Rich QR / Web link / Secret text / Contact) once on full collage
        let trimmedQR = options.qrCodeContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQR.isEmpty {
            let qrSize = options.qrCodeSize.pixelSize(forTargetWidth: targetWidth)
            if let qrImage = generateQRCode(from: trimmedQR, size: qrSize) {
                let margin: CGFloat = max(18.0, dstW * 0.035)
                let qrRect: CGRect
                switch options.qrCodePosition {
                case .bottomRight:
                    qrRect = CGRect(x: dstW - qrSize - margin, y: margin, width: qrSize, height: qrSize)
                case .bottomLeft:
                    qrRect = CGRect(x: margin, y: margin, width: qrSize, height: qrSize)
                case .topRight:
                    qrRect = CGRect(x: dstW - qrSize - margin, y: dstH - qrSize - margin, width: qrSize, height: qrSize)
                case .topLeft:
                    qrRect = CGRect(x: margin, y: dstH - qrSize - margin, width: qrSize, height: qrSize)
                case .bottomCenter:
                    qrRect = CGRect(x: (dstW - qrSize) / 2.0, y: margin, width: qrSize, height: qrSize)
                }

                let badgePadding: CGFloat = 8.0
                let badgeRect = qrRect.insetBy(dx: -badgePadding, dy: -badgePadding)
                switch options.qrCodeStyle {
                case .frosted:
                    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                    ctx.setStrokeColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
                    ctx.setLineWidth(1.5)
                    ctx.addPath(path)
                    ctx.strokePath()
                case .solidWhite:
                    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                case .minimal:
                    ctx.setFillColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.65)
                    let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                }

                ctx.draw(qrImage, in: qrRect)
            }
        }

        guard let outCG = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: outCG)
        rep.size = NSSize(width: targetWidth, height: targetHeight)
        let outImg = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        outImg.addRepresentation(rep)
        return outImg
    }

    /// Compress an 800x800 NSImage into a JPEG guaranteed to be <= `maxBytes` (default 60 KB).
    public static func compressToJPEG(
        _ image: NSImage,
        maxBytes: Int = InstaxConstants.maxJpegBytes
    ) -> (data: Data, quality: Double)? {
        guard let cgImage = getNormalizedCGImage(from: image) else {
            return nil
        }

        // Re-draw into a clean DeviceRGB bitmap so NSBitmapImageRep does not embed a ~4 KB ICC color profile
        let w = cgImage.width
        let h = cgImage.height
        var activeCG = cgImage
        if let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) {
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            if let stripped = ctx.makeImage() {
                activeCG = stripped
            }
        }

        let bitmapRep = NSBitmapImageRep(cgImage: activeCG)
        var bestCandidate: (data: Data, quality: Double)? = nil

        for qInt in stride(from: 94, through: 4, by: -4) {
            let quality = Double(qInt) / 100.0
            if let jpegData = bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: NSNumber(value: quality), .progressive: NSNumber(value: false)]
            ) {
                if bestCandidate == nil || jpegData.count < bestCandidate!.data.count {
                    bestCandidate = (jpegData, quality)
                }
                if jpegData.count <= maxBytes {
                    InstaxLogger.log("[IMG] JPEG encoded: \(jpegData.count) bytes (quality: \(qInt)%, target budget: \(maxBytes / 1024) KB)")
                    return (jpegData, quality)
                }
            }
        }

        // If an extremely noisy / high-frequency image still exceeds maxBytes at 4% quality,
        // apply a subtle high-frequency smoothing pass (imperceptible on physical Instax film)
        let ciCtx = CIContext(options: [.useSoftwareRenderer: true])
        for blurRadius in [0.9, 1.6, 2.4] {
            let ciInput = CIImage(cgImage: activeCG).clampedToExtent()
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(ciInput, forKey: kCIInputImageKey)
                blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
                if let outCI = blur.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: w, height: h)),
                   let blurredCG = ciCtx.createCGImage(outCI, from: CGRect(x: 0, y: 0, width: w, height: h)) {
                    let blurRep = NSBitmapImageRep(cgImage: blurredCG)
                    for qInt in stride(from: 70, through: 6, by: -8) {
                        let quality = Double(qInt) / 100.0
                        if let jpegData = blurRep.representation(
                            using: .jpeg,
                            properties: [.compressionFactor: NSNumber(value: quality), .progressive: NSNumber(value: false)]
                        ) {
                            if bestCandidate == nil || jpegData.count < bestCandidate!.data.count {
                                bestCandidate = (jpegData, quality)
                            }
                            if jpegData.count <= maxBytes {
                                InstaxLogger.log("[IMG] JPEG encoded (smoothed r=\(blurRadius)): \(jpegData.count) bytes (quality: \(qInt)%, target budget: \(maxBytes / 1024) KB)")
                                return (jpegData, quality)
                            }
                        }
                    }
                }
            }
        }

        if let fallback = bestCandidate {
            InstaxLogger.log("[IMG] JPEG fallback encoded: \(fallback.data.count) bytes")
            return fallback
        }
        return nil
    }
}

// MARK: - BLE Service & Print Engine

public struct DiscoveredPrinter: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let rssi: Int
    public let peripheral: CBPeripheral

    public static func == (lhs: DiscoveredPrinter, rhs: DiscoveredPrinter) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.rssi == rhs.rssi
    }
}

public final class InstaxBLEController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private let queue = DispatchQueue(label: "com.instax.square.ble", qos: .userInitiated)

    public var onStateUpdate: ((CBManagerState) -> Void)?
    public var onPrintersDiscovered: (([DiscoveredPrinter]) -> Void)?
    public var onConnectionChanged: ((Bool, String?) -> Void)?
    public var onLog: ((String) -> Void)?

    private var discovered: [String: DiscoveredPrinter] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?

    private var rxBuffer = Data()
    private var pendingSID: InstaxSID?
    private var responseCont: CheckedContinuation<InstaxResponse, Error>?
    private var connectCont: CheckedContinuation<Void, Error>?
    private var stateReadyCont: CheckedContinuation<Void, Error>?

    public override init() {
        super.init()
        self.central = CBCentralManager(delegate: self, queue: queue)
    }

    private func log(_ msg: String) {
        onLog?(msg)
        InstaxLogger.log(msg)
    }

    public var isConnected: Bool {
        queue.sync {
            connectedPeripheral?.state == .connected && writeChar != nil && notifyChar != nil
        }
    }

    public var connectedName: String? {
        queue.sync {
            connectedPeripheral?.name
        }
    }

    public var mtuWriteSize: Int {
        queue.sync {
            guard let p = connectedPeripheral else { return 182 }
            return max(20, p.maximumWriteValueLength(for: .withoutResponse))
        }
    }

    // MARK: Async Bluetooth Operations

    public func waitUntilPoweredOn(timeout: TimeInterval = 6.0) async throws {
        log("Bluetooth: Checking adapter state...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.queue.async {
                        switch self.central.state {
                        case .poweredOn:
                            cont.resume()
                        case .unauthorized:
                            cont.resume(throwing: NSError(domain: "InstaxBLE", code: 10, userInfo: [
                                NSLocalizedDescriptionKey: "Bluetooth permission denied. Enable Bluetooth access for Terminal / Instax Printer in System Settings -> Privacy & Security -> Bluetooth."
                            ]))
                        case .poweredOff:
                            cont.resume(throwing: NSError(domain: "InstaxBLE", code: 11, userInfo: [
                                NSLocalizedDescriptionKey: "Mac Bluetooth is turned OFF."
                            ]))
                        case .unsupported:
                            cont.resume(throwing: NSError(domain: "InstaxBLE", code: 13, userInfo: [
                                NSLocalizedDescriptionKey: "Bluetooth Low Energy is unsupported or blocked in this environment."
                            ]))
                        default:
                            self.stateReadyCont = cont
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.queue.async {
                    if let c = self.stateReadyCont {
                        self.stateReadyCont = nil
                        c.resume(throwing: NSError(domain: "InstaxBLE", code: 12, userInfo: [
                            NSLocalizedDescriptionKey: "Timed out waiting for Mac Bluetooth (state=\(self.central.state.rawValue))."
                        ]))
                    }
                }
                throw CancellationError()
            }
            _ = try await group.next()!
            group.cancelAll()
        }
    }

    public func scanForPrinters(duration: TimeInterval = 4.0) async throws -> [DiscoveredPrinter] {
        try await waitUntilPoweredOn()
        queue.async {
            self.discovered.removeAll()
            self.central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        return queue.sync {
            self.central.stopScan()
            return Array(self.discovered.values).sorted { $0.rssi > $1.rssi }
        }
    }

    public func startBackgroundScan() {
        queue.async {
            guard self.central.state == .poweredOn else { return }
            self.central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    public func stopBackgroundScan() {
        queue.async {
            if self.central.isScanning {
                self.central.stopScan()
            }
        }
    }

    public func connect(targetNameOrPrefix: String = InstaxConstants.defaultDeviceName, timeout: TimeInterval = 8.0) async throws {
        if isConnected { return }
        try await waitUntilPoweredOn()

        let startTime = Date()
        queue.async {
            self.central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }

        var matched: DiscoveredPrinter?
        let needle = targetNameOrPrefix.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        while Date().timeIntervalSince(startTime) < timeout {
            let list = queue.sync { Array(self.discovered.values).sorted { $0.rssi > $1.rssi } }
            if let exact = list.first(where: {
                $0.name.uppercased().hasPrefix(needle) || $0.name.uppercased().contains(needle) || $0.id.uppercased() == needle
            }) {
                matched = exact
                break
            }
            if needle.isEmpty || needle == "INSTAX" || needle == "INSTAX-" || needle == "AUTO", let anyInstax = list.first {
                matched = anyInstax
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        queue.async { self.central.stopScan() }

        guard let target = matched else {
            let foundNames = queue.sync { self.discovered.values.map { $0.name }.joined(separator: ", ") }
            let hint = foundNames.isEmpty ? "none found" : foundNames
            throw NSError(domain: "InstaxBLE", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "Could not find '\(targetNameOrPrefix)' over Bluetooth (discovered: \(hint)). Make sure your printer is powered ON and Bluetooth is turned OFF on your phone/tablet (Instax printers can only pair with one device at a time)."
            ])
        }

        try await connect(to: target.peripheral, timeout: timeout)
    }

    public func connect(to peripheral: CBPeripheral, timeout: TimeInterval = 8.0) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.queue.async {
                        self.connectCont = cont
                        self.connectedPeripheral = peripheral
                        peripheral.delegate = self
                        self.central.connect(peripheral, options: nil)
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.queue.async {
                    if let c = self.connectCont {
                        self.connectCont = nil
                        c.resume(throwing: NSError(domain: "InstaxBLE", code: 21, userInfo: [
                            NSLocalizedDescriptionKey: "Timed out connecting to \(peripheral.name ?? "printer")."
                        ]))
                    }
                }
                throw CancellationError()
            }
            _ = try await group.next()!
            group.cancelAll()
        }
    }

    public func disconnect() {
        queue.async {
            if let p = self.connectedPeripheral {
                self.central.cancelPeripheralConnection(p)
            }
            self.connectedPeripheral = nil
            self.writeChar = nil
            self.notifyChar = nil
        }
    }

    public func sendCommand(
        sid: InstaxSID,
        payload: Data = Data(),
        timeout: TimeInterval = 12.0
    ) async throws -> InstaxResponse {
        let packet = InstaxPacket.build(sid: sid, payload: payload)
        let mtu = mtuWriteSize
        let hexSample = packet.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
        log("[TX] -> \(sid.name) (\(packet.count)B) [\(hexSample)\(packet.count > 16 ? "..." : "")]")

        return try await withThrowingTaskGroup(of: InstaxResponse.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<InstaxResponse, Error>) in
                    self.queue.async {
                        guard let peripheral = self.connectedPeripheral,
                              peripheral.state == .connected,
                              let writeChar = self.writeChar else {
                            cont.resume(throwing: NSError(domain: "InstaxBLE", code: 30, userInfo: [
                                NSLocalizedDescriptionKey: "Printer is not connected."
                            ]))
                            return
                        }
                        self.rxBuffer.removeAll()
                        self.pendingSID = sid
                        self.responseCont = cont

                        // Split packet into MTU-sized fragments and write with .withoutResponse
                        // (Matches ImageRequest.sendData + BTDataService.writeData in Fujifilm's macOS driver)
                        let total = packet.count
                        var offset = 0
                        var chunkIndex = 0
                        while offset < total {
                            let end = min(offset + mtu, total)
                            let slice = packet.subdata(in: offset..<end)
                            let delayMs = chunkIndex * 6
                            self.queue.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                                peripheral.writeValue(slice, for: writeChar, type: .withoutResponse)
                            }
                            offset = end
                            chunkIndex += 1
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.queue.async {
                    if let c = self.responseCont {
                        self.responseCont = nil
                        self.pendingSID = nil
                        c.resume(throwing: NSError(domain: "InstaxBLE", code: 31, userInfo: [
                            NSLocalizedDescriptionKey: "Timed out waiting for response to SID \(sid)."
                        ]))
                    }
                }
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: High-Level Printer Queries & Printing

    public func fetchStatus() async throws -> PrinterStatus {
        var status = PrinterStatus()
        status.deviceName = connectedName ?? InstaxConstants.defaultDeviceName
        status.identifier = queue.sync { connectedPeripheral?.identifier.uuidString ?? "" }

        // 1. Manufacturer
        if let r = try? await sendCommand(sid: .deviceInfoService, payload: Data([0x00]), timeout: 5.0),
           r.isOK, r.payload.count > 1 {
            status.manufacturer = String(data: r.payload.dropFirst(), encoding: .ascii)?
                .trimmingCharacters(in: CharacterSet.controlCharacters.union(.whitespaces)) ?? ""
        }

        // 2. Model Number
        if let r = try? await sendCommand(sid: .deviceInfoService, payload: Data([0x01]), timeout: 5.0),
           r.isOK, r.payload.count > 1 {
            status.modelNumber = String(data: r.payload.dropFirst(), encoding: .ascii)?
                .trimmingCharacters(in: CharacterSet.controlCharacters.union(.whitespaces)) ?? ""
        }

        // 3. Firmware Revision
        if let r = try? await sendCommand(sid: .deviceInfoService, payload: Data([0x04]), timeout: 5.0),
           r.isOK, r.payload.count > 1 {
            status.firmwareVersion = String(data: r.payload.dropFirst(), encoding: .ascii)?
                .trimmingCharacters(in: CharacterSet.controlCharacters.union(.whitespaces)) ?? ""
        }

        // 4. Image Support Info (0x00)
        let imgInfo = try await sendCommand(sid: .supportFunctionInfo, payload: Data([0x00]), timeout: 6.0)
        if imgInfo.isOK && imgInfo.payload.count >= 7 {
            let b = [UInt8](imgInfo.payload)
            let w = (Int(b[1]) << 8) | Int(b[2])
            let h = (Int(b[3]) << 8) | Int(b[4])
            if w > 0 && h > 0 {
                status.width = w
                status.height = h
            }
            let pktSz = (Int(b[5]) << 8) | Int(b[6])
            if pktSz >= 128 && pktSz <= 4096 {
                status.chunkSize = pktSz
            }
            let picOpt = b[6]
            status.supports3DLut = ((picOpt >> 3) & 0x01) == 1
            if b.count >= 11 {
                let maxJpeg = (Int(b[7]) << 24) | (Int(b[8]) << 16) | (Int(b[9]) << 8) | Int(b[10])
                if maxJpeg >= 10_000 && maxJpeg <= 500_000 {
                    status.maxJpegSize = maxJpeg
                }
            }
        }

        // 5. Battery Info (0x01) - exact bit layout from InstaxPrinterInfo.updateBatteryInfo (0x100052594)
        let battInfo = try await sendCommand(sid: .supportFunctionInfo, payload: Data([0x01]), timeout: 6.0)
        if battInfo.isOK && battInfo.payload.count >= 2 {
            let b = [UInt8](battInfo.payload)
            status.batteryLevel = min(4, Int(b[1] & 0x07))
            status.isCharging = ((b[1] >> 3) & 0x01) == 1
            if b.count >= 3 {
                let pct = Int(b[2])
                status.batteryPercent = pct > 94 ? 100 : pct
            }
        }

        // 6. Printer Function Info (0x02) - exact bit layout from InstaxPrinterInfo.updatePrinterInfo (0x1000522c0)
        let prtInfo = try await sendCommand(sid: .supportFunctionInfo, payload: Data([0x02]), timeout: 6.0)
        if prtInfo.isOK && prtInfo.payload.count >= 2 {
            let b = [UInt8](prtInfo.payload)
            status.filmRemaining = Int(b[1] & 0x0F)
            if b.count >= 3 {
                status.isCoverOpen = (b[2] & 0x01) == 1
                status.isBusy = ((b[2] >> 1) & 0x01) == 1
                status.hasError = ((b[2] >> 2) & 0x01) == 1
            }
            if b.count >= 4 {
                status.resultPrintRequest = b[3]
            }
            if b.count >= 5 {
                status.waitSeconds = Int(b[4]) + 3
            }
            if b.count >= 9 {
                status.printerErrorType = UInt32(b[5]) | (UInt32(b[6]) << 8) | (UInt32(b[7]) << 16) | (UInt32(b[8]) << 24)
            }
        }

        // 7. Print History Info (0x03)
        if let histInfo = try? await sendCommand(sid: .supportFunctionInfo, payload: Data([0x03]), timeout: 5.0),
           histInfo.isOK && histInfo.payload.count >= 5 {
            let b = [UInt8](histInfo.payload)
            status.totalPrints = (Int(b[1]) << 24) | (Int(b[2]) << 16) | (Int(b[3]) << 8) | Int(b[4])
        }

        log("[STATUS] Hardware Status: \(status.deviceName) — Battery: \(status.batteryPercent)% (Lvl \(status.batteryLevel), \(status.isCharging ? "Charging" : "Discharging")), Film: \(status.filmRemaining)/10, Res: \(status.width)×\(status.height), MaxJPEG: \(status.maxJpegSize)B, Chunk: \(status.chunkSize)B, 3D-LUT: \(status.supports3DLut), Cover: \(status.isCoverOpen ? "OPEN" : "Closed"), Error: \(status.hasError ? status.printerErrorDescription : "None")")


        return status
    }

    /// Play a single brief rainbow flash on the front LED and automatically restore normal status LED.
    /// Layout for LED_PATTERN_SETTINGS (48, 1):
    /// `[when (0x00 = now), color_count, speed, repeat (0x00 = play once, 0xFF = loop forever), (B, G, R) * color_count]`
    public func flashRainbowLED() async throws {
        let payload = Data([
            0x00, // when = 0 (now)
            0x06, // color_count = 6
            0x0F, // speed = 15 (~150ms per step)
            0x00, // repeat = 0 (play ONCE — do NOT loop!)
            0x00, 0x00, 0xFF, // Red (BGR)
            0x00, 0x7F, 0xFF, // Orange (BGR)
            0x00, 0xFF, 0xFF, // Yellow (BGR)
            0x00, 0xFF, 0x00, // Green (BGR)
            0xFF, 0x00, 0x00, // Blue (BGR)
            0xFF, 0x00, 0x8B  // Violet (BGR)
        ])
        _ = try await sendCommand(sid: .ledPatternSettings, payload: payload, timeout: 5.0)
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        try? await stopLED()
    }

    /// Immediately stop any looping LED pattern and restore normal status LED behavior.
    public func stopLED() async throws {
        // Send 1 frame of [B=0, G=0, R=0] with repeat = 0 (play once) to stop any active LED loop
        let stopPayload = Data([
            0x00, // when = 0 (now)
            0x01, // color_count = 1
            0x05, // speed = 5
            0x00, // repeat = 0 (play once & clear)
            0x00, 0x00, 0x00 // Black/Off (BGR)
        ])
        _ = try await sendCommand(sid: .ledPatternSettings, payload: stopPayload, timeout: 5.0)
    }

    /// Sends REJECT_FILM_COVER (SID 16, 129) to eject the protective black plastic sheet from a newly loaded film pack.
    public func ejectFilmCover() async throws {
        log("[PRINTER] Sending REJECT_FILM_COVER hardware command (SID 16, 129)...")
        let resp = try await sendCommand(sid: .rejectFilmCover, payload: Data(), timeout: 15.0)
        guard resp.isOK else {
            log("[ERR] REJECT_FILM_COVER rejected: \(resp.resultDescription)")
            throw NSError(domain: "InstaxPrint", code: 47, userInfo: [
                NSLocalizedDescriptionKey: "Failed to eject film cover: \(resp.resultDescription)"
            ])
        }
        log("[PRINTER] REJECT_FILM_COVER command accepted. Waiting 8s for motor to cycle dark slide...")
        try await Task.sleep(nanoseconds: 8_000_000_000)
        let st = try await fetchStatus()
        log("[PRINTER] Film cover ejection cycle complete. Status: Film \(st.filmRemaining)/10, Error: \(st.hasError ? st.printerErrorDescription : "None")")
    }


    public func printJPEG(
        _ jpegData: Data,
        mode: InstaxPrintMode = .rich,
        dryRun: Bool = false,
        progress: ((String, Double) -> Void)? = nil
    ) async throws -> PrinterStatus {
        progress?("Checking printer status...", 0.03)
        let status = try await fetchStatus()

        if status.isCoverOpen {
            throw NSError(domain: "InstaxPrint", code: 40, userInfo: [
                NSLocalizedDescriptionKey: "Printer film door is open. Please close the back cover."
            ])
        }
        if !dryRun && status.filmRemaining <= 0 {
            throw NSError(domain: "InstaxPrint", code: 41, userInfo: [
                NSLocalizedDescriptionKey: "No film remaining (0/10) in printer."
            ])
        }
        if dryRun && status.filmRemaining <= 0 {
            log("[DRY-RUN] Film count is 0/10. Dry run mode active: testing full data transmission without film.")
        }
        if status.batteryPercent < 6 && status.batteryLevel == 0 && !status.isCharging {
            throw NSError(domain: "InstaxPrint", code: 42, userInfo: [
                NSLocalizedDescriptionKey: "Battery is too low (\(status.batteryPercent)%) to print."
            ])
        }

        let totalBytes = jpegData.count
        let optionByte: UInt8 = (mode == .natural && status.supports3DLut) ? 0x08 : 0x00
        var frameSize = status.chunkSize > 0 ? status.chunkSize : InstaxConstants.defaultChunkSize

        progress?("Starting image download (\(totalBytes / 1024) KB)...", 0.06)
        let totalSizeU32 = UInt32(totalBytes)
        var startPayload = Data([0x02, optionByte, 0x00, 0x00])
        startPayload.append(UInt8((totalSizeU32 >> 24) & 0xFF))
        startPayload.append(UInt8((totalSizeU32 >> 16) & 0xFF))
        startPayload.append(UInt8((totalSizeU32 >> 8) & 0xFF))
        startPayload.append(UInt8(totalSizeU32 & 0xFF))

        let startResp = try await sendCommand(sid: .printImageDownloadStart, payload: startPayload, timeout: 12.0)
        guard startResp.isOK else {
            throw NSError(domain: "InstaxPrint", code: 43, userInfo: [
                NSLocalizedDescriptionKey: "PRINT_IMAGE_DOWNLOAD_START rejected: \(startResp.resultDescription)"
            ])
        }

        // Read printer's preferred packetLength from response payload[0..<4] if present
        if startResp.payload.count >= 4 {
            let b = [UInt8](startResp.payload)
            let reported = (Int(b[0]) << 24) | (Int(b[1]) << 16) | (Int(b[2]) << 8) | Int(b[3])
            if reported >= 128 && reported <= 4096 {
                frameSize = reported
            }
        }

        let totalFrames = (totalBytes + frameSize - 1) / frameSize
        let runKind = dryRun ? " [DRY-RUN]" : ""
        log("[PRINT]\(runKind) Image download start: \(totalBytes)B JPEG raw (declared size: \(totalBytes)B, \(totalFrames) chunks @ \(frameSize)B fixed BLE frame, mode: \(mode.rawValue))")
        do {
            for seq in 0..<totalFrames {
                let startIdx = seq * frameSize
                let endIdx = min(startIdx + frameSize, totalBytes)
                var chunk = jpegData.subdata(in: startIdx..<endIdx)

                // The printer BLE receiver requires every PRINT_IMAGE_DOWNLOAD_DATA packet
                // to match the negotiated frameSize (900B payload = 911B packet).
                // Trailing zeroes on the last chunk are ignored by the printer's JPEG decoder
                // because DOWNLOAD_START already set the exact unpadded byte size.
                if chunk.count < frameSize {
                    chunk.append(Data(repeating: 0, count: frameSize - chunk.count))
                }

                let seqU32 = UInt32(seq)
                var dataPayload = Data(capacity: 4 + frameSize)
                dataPayload.append(UInt8((seqU32 >> 24) & 0xFF))
                dataPayload.append(UInt8((seqU32 >> 16) & 0xFF))
                dataPayload.append(UInt8((seqU32 >> 8) & 0xFF))
                dataPayload.append(UInt8(seqU32 & 0xFF))
                dataPayload.append(chunk)

                let pct = 0.08 + (Double(seq + 1) / Double(totalFrames)) * 0.76
                let dryTag = dryRun ? "[Dry Run] " : ""
                progress?("\(dryTag)Uploading packet \(seq + 1)/\(totalFrames)...", pct)

                let dataResp = try await sendCommand(sid: .printImageDownloadData, payload: dataPayload, timeout: 15.0)
                guard dataResp.isOK else {
                    log("[ERR] Chunk \(seq + 1)/\(totalFrames) failed: \(dataResp.resultDescription)")
                    throw NSError(domain: "InstaxPrint", code: 44, userInfo: [
                        NSLocalizedDescriptionKey: "Packet \(seq + 1)/\(totalFrames) rejected: \(dataResp.resultDescription)"
                    ])
                }
                if seq == 0 || seq == totalFrames - 1 || (seq + 1) % 10 == 0 {
                    log("[PRINT]\(runKind) Upload chunk \(seq + 1)/\(totalFrames) (\(chunk.count)B) confirmed OK")
                }
            }
        } catch {
            log("[ERR] Print transmission aborted: \(error.localizedDescription)")
            _ = try? await sendCommand(sid: .printImageDownloadCancel, payload: Data(), timeout: 3.0)
            throw error
        }

        progress?("Finalizing image transfer...", 0.87)
        let endResp = try await sendCommand(sid: .printImageDownloadEnd, payload: Data(), timeout: 10.0)
        guard endResp.isOK else {
            log("[ERR] PRINT_IMAGE_DOWNLOAD_END rejected: \(endResp.resultDescription)")
            throw NSError(domain: "InstaxPrint", code: 45, userInfo: [
                NSLocalizedDescriptionKey: "PRINT_IMAGE_DOWNLOAD_END rejected: \(endResp.resultDescription)"
            ])
        }

        // Brief delay for firmware image buffer validation
        try? await Task.sleep(nanoseconds: 300_000_000)

        if let stCheck = try? await fetchStatus(), stCheck.hasError && !status.hasError {
            log("[WARN] Printer reported status flag after download: \(stCheck.printerErrorDescription)")
        }

        if dryRun {
            log("[DRY-RUN] ✅ Test run complete! All \(totalFrames) chunks received and verified by printer ASIC in RAM.")
            log("[DRY-RUN] Releasing image buffer via PRINT_IMAGE_DOWNLOAD_CANCEL (0 film used).")
            progress?("Dry run verified! 100% data delivered. (0 film used)", 1.0)
            _ = try? await sendCommand(sid: .printImageDownloadCancel, payload: Data(), timeout: 4.0)
            try? await Task.sleep(nanoseconds: 500_000_000)
            let finalStatus = (try? await fetchStatus()) ?? status
            log("[DRY-RUN] Printer idle status confirmed. Film count: \(finalStatus.filmRemaining)/10.")
            return finalStatus
        }

        progress?("Triggering physical print...", 0.92)
        log("[PRINT] Firing PRINT_IMAGE hardware command...")
        let prtResp = try await sendCommand(sid: .printImage, payload: Data(), timeout: 15.0)
        guard prtResp.isOK else {
            log("[ERR] PRINT_IMAGE failed: \(prtResp.resultDescription)")
            throw NSError(domain: "InstaxPrint", code: 46, userInfo: [
                NSLocalizedDescriptionKey: "PRINT_IMAGE failed: \(prtResp.resultDescription)"
            ])
        }

        var waitSecs = status.waitSeconds
        if let firstByte = prtResp.payload.first, firstByte > 0 {
            waitSecs = Int(firstByte) + 3
        }

        let printerKind = status.width == 1260 ? "Instax WIDE" : (status.width == 600 ? "Instax Mini" : "Instax SQUARE")
        log("[PRINT] Hardware print in progress. Ejecting film, pausing for \(waitSecs)s...")
        progress?("Ejecting \(printerKind) film (\(waitSecs)s)...", 0.96)
        try await Task.sleep(nanoseconds: UInt64(max(waitSecs, 15)) * 1_000_000_000)

        // Poll printer status to confirm print completed
        var updatedStatus = status
        for _ in 0..<3 {
            if let st = try? await fetchStatus() {
                updatedStatus = st
                if !st.isBusy { break }
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        if updatedStatus.resultPrintRequest == 0xF0 && updatedStatus.filmRemaining == status.filmRemaining {
            log("[ERR] Hardware error after print: \(updatedStatus.printerErrorDescription)")
            throw NSError(domain: "InstaxPrint", code: 50, userInfo: [
                NSLocalizedDescriptionKey: "Print failed: \(updatedStatus.printerErrorDescription)"
            ])
        }

        log("[PRINT] Print successful! Remaining film: \(updatedStatus.filmRemaining)/10")
        progress?("Print complete! (\(updatedStatus.filmRemaining)/10 film remaining)", 1.0)
        return updatedStatus
    }


    // MARK: CBCentralManagerDelegate & CBPeripheralDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateUpdate?(central.state)
        if central.state == .poweredOn, let c = stateReadyCont {
            stateReadyCont = nil
            c.resume()
        } else if central.state == .unauthorized, let c = stateReadyCont {
            stateReadyCont = nil
            c.resume(throwing: NSError(domain: "InstaxBLE", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "Bluetooth permission denied. Enable Bluetooth access in System Settings -> Privacy & Security -> Bluetooth."
            ]))
        } else if central.state == .poweredOff, let c = stateReadyCont {
            stateReadyCont = nil
            c.resume(throwing: NSError(domain: "InstaxBLE", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "Mac Bluetooth is powered off."
            ]))
        } else if central.state == .unsupported, let c = stateReadyCont {
            stateReadyCont = nil
            c.resume(throwing: NSError(domain: "InstaxBLE", code: 13, userInfo: [
                NSLocalizedDescriptionKey: "Bluetooth Low Energy is unsupported or blocked in this environment."
            ]))
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let isInstax = localName.uppercased().hasPrefix("INSTAX") || serviceUUIDs.contains(InstaxConstants.serviceUUID)

        guard isInstax else { return }
        let displayName = localName.isEmpty ? (peripheral.name ?? "INSTAX Printer") : localName
        let item = DiscoveredPrinter(
            id: peripheral.identifier.uuidString,
            name: displayName,
            rssi: RSSI.intValue,
            peripheral: peripheral
        )
        discovered[item.id] = item
        let list = Array(discovered.values).sorted { $0.rssi > $1.rssi }
        onPrintersDiscovered?(list)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected to \(peripheral.name ?? "printer"), discovering GATT services...")
        peripheral.discoverServices([InstaxConstants.serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let c = connectCont {
            connectCont = nil
            c.resume(throwing: error ?? NSError(domain: "InstaxBLE", code: 22, userInfo: [
                NSLocalizedDescriptionKey: "Failed to connect to printer."
            ]))
        }
        onConnectionChanged?(false, nil)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeChar = nil
        notifyChar = nil
        if let c = responseCont {
            responseCont = nil
            pendingSID = nil
            c.resume(throwing: NSError(domain: "InstaxBLE", code: 23, userInfo: [
                NSLocalizedDescriptionKey: "Printer disconnected unexpectedly."
            ]))
        }
        onConnectionChanged?(false, nil)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            if let c = connectCont {
                connectCont = nil
                c.resume(throwing: error)
            }
            return
        }
        guard let services = peripheral.services else { return }
        for svc in services where svc.uuid == InstaxConstants.serviceUUID {
            peripheral.discoverCharacteristics(
                [InstaxConstants.writeCharUUID, InstaxConstants.notifyCharUUID],
                for: svc
            )
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            if let c = connectCont {
                connectCont = nil
                c.resume(throwing: error)
            }
            return
        }
        guard let chars = service.characteristics else { return }
        for ch in chars {
            if ch.uuid == InstaxConstants.writeCharUUID {
                writeChar = ch
            } else if ch.uuid == InstaxConstants.notifyCharUUID {
                notifyChar = ch
                peripheral.setNotifyValue(true, for: ch)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            if let c = connectCont {
                connectCont = nil
                c.resume(throwing: error)
            }
            return
        }
        if characteristic.uuid == InstaxConstants.notifyCharUUID && writeChar != nil {
            if let c = connectCont {
                connectCont = nil
                c.resume()
            }
            onConnectionChanged?(true, peripheral.name ?? InstaxConstants.defaultDeviceName)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == InstaxConstants.notifyCharUUID,
              let value = characteristic.value else { return }

        rxBuffer.append(value)

        while rxBuffer.count >= 4 {
            let b = [UInt8](rxBuffer)
            if b[0] != 0x61 || b[1] != 0x42 {
                // Re-sync to 'aB' header
                if let idx = rxBuffer.range(of: Data([0x61, 0x42]))?.lowerBound {
                    rxBuffer.removeSubrange(0..<idx)
                    if rxBuffer.count < 4 { return }
                } else {
                    rxBuffer.removeAll()
                    return
                }
            }
            let hdr = [UInt8](rxBuffer.prefix(4))
            let pktSize = (Int(hdr[2]) << 8) | Int(hdr[3])
            if pktSize < 8 || pktSize > 4096 {
                rxBuffer.removeFirst(2)
                continue
            }
            if rxBuffer.count < pktSize {
                return
            }
            let rawPkt = rxBuffer.subdata(in: 0..<pktSize)
            rxBuffer.removeSubrange(0..<pktSize)

            if let resp = try? InstaxPacket.parse(rawPkt) {
                let payloadSample = resp.payload.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
                log("[RX] <- \(resp.sid.name) [Code: 0x\(String(format: "%02X", resp.resultCode))] (\(resp.payload.count)B) [\(payloadSample)\(resp.payload.count > 16 ? "..." : "")]")
                if let expected = pendingSID, resp.sid == expected, let cont = responseCont {
                    pendingSID = nil
                    responseCont = nil
                    cont.resume(returning: resp)
                }
            }
        }
    }
}
