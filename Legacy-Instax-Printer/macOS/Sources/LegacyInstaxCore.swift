import Foundation
import AppKit
import CoreGraphics
import CoreImage
import Combine
import Darwin

// MARK: - Printer Models (Instax SHARE SP-1, SP-2, SP-3)

public enum LegacyPrinterModel: String, CaseIterable, Identifiable {
    case sp1 = "SP-1"
    case sp2 = "SP-2"
    case sp3 = "SP-3"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sp1: return "Instax SHARE SP-1 (Mini)"
        case .sp2: return "Instax SHARE SP-2 (Mini HD)"
        case .sp3: return "Instax SHARE SP-3 (SQUARE)"
        }
    }

    public var shortBadge: String {
        switch self {
        case .sp1: return "SP-1 • 600×800 Mini"
        case .sp2: return "SP-2 • 600×800 Mini"
        case .sp3: return "SP-3 • 800×800 Square"
        }
    }

    public var filmType: String {
        switch self {
        case .sp1, .sp2: return "Instax Mini Film"
        case .sp3: return "Instax SQUARE Film"
        }
    }

    public var width: Int {
        switch self {
        case .sp1, .sp2: return 600
        case .sp3: return 800
        }
    }

    public var height: Int {
        switch self {
        case .sp1, .sp2, .sp3: return 800
        }
    }

    public var aspectRatio: CGFloat {
        CGFloat(width) / CGFloat(height)
    }

    public var segmentSize: Int {
        60000
    }

    public var totalBytes: Int {
        width * height * 3
    }

    public var segmentCount: Int {
        totalBytes / segmentSize
    }
}

// MARK: - Creative Studio Enums

public enum LegacyFitMode: String, CaseIterable, Identifiable {
    case fill = "Crop to Fill"
    case fit = "Fit Inside (Matte)"
    public var id: String { rawValue }
}

public enum LegacyMatteColor: String, CaseIterable, Identifiable {
    case white = "Pure White"
    case black = "Carbon Black"
    case warmCream = "Vintage Cream"
    case softGrey = "Studio Grey"

    public var id: String { rawValue }

    public var cgColor: CGColor {
        switch self {
        case .white: return CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .black: return CGColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)
        case .warmCream: return CGColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1.0)
        case .softGrey: return CGColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0)
        }
    }
}

public enum LegacyPhotoFilter: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case fujiIntelligence = "Fujifilm Intelligence"
    case mono = "Monochrome"
    case sepia = "Sepia"
    case vivid = "Vivid Velvia"
    case vintage = "Classic Chrome"

    public var id: String { rawValue }
}

public enum LegacyCollageLayout: String, CaseIterable, Identifiable {
    case single = "Single Photo"
    case splitVertical = "2-Up Vertical Split"
    case splitHorizontal = "2-Up Horizontal Split"
    case grid3 = "3-Photo Collage"
    case grid4 = "4-Photo 2×2 Grid"
    case strip3 = "3-Photo Booth Strip"
    case grid6 = "6-Photo Contact Sheet"

    public var id: String { rawValue }

    public var slotCount: Int {
        switch self {
        case .single: return 1
        case .splitVertical, .splitHorizontal: return 2
        case .grid3, .strip3: return 3
        case .grid4: return 4
        case .grid6: return 6
        }
    }

    public func normalizedRects() -> [CGRect] {
        switch self {
        case .single:
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        case .splitVertical:
            return [
                CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
                CGRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
            ]
        case .splitHorizontal:
            return [
                CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5),
                CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.5)
            ]
        case .grid3:
            return [
                CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5),
                CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5)
            ]
        case .grid4:
            return [
                CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5)
            ]
        case .strip3:
            let h = 1.0 / 3.0
            return [
                CGRect(x: 0.0, y: 2.0 * h, width: 1.0, height: h),
                CGRect(x: 0.0, y: 1.0 * h, width: 1.0, height: h),
                CGRect(x: 0.0, y: 0.0, width: 1.0, height: h)
            ]
        case .grid6:
            let h = 1.0 / 3.0
            return [
                CGRect(x: 0.0, y: 2.0 * h, width: 0.5, height: h),
                CGRect(x: 0.5, y: 2.0 * h, width: 0.5, height: h),
                CGRect(x: 0.0, y: 1.0 * h, width: 0.5, height: h),
                CGRect(x: 0.5, y: 1.0 * h, width: 0.5, height: h),
                CGRect(x: 0.0, y: 0.0, width: 0.5, height: h),
                CGRect(x: 0.5, y: 0.0, width: 0.5, height: h)
            ]
        }
    }
}

public enum LegacyQRContentType: String, CaseIterable, Identifiable {
    case none = "Off"
    case url = "Website URL"
    case text = "Custom Text / Note"
    case phone = "Phone Number"
    case email = "Email Address"
    case wifi = "Wi-Fi Access"
    case location = "Map Coordinates"

    public var id: String { rawValue }
}

public enum LegacyQRCorner: String, CaseIterable, Identifiable {
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    case topRight = "Top Right"
    case topLeft = "Top Left"

    public var id: String { rawValue }
}

public struct LegacyPrintOptions {
    public var model: LegacyPrinterModel = .sp2
    public var fitMode: LegacyFitMode = .fill
    public var matteColor: LegacyMatteColor = .white
    public var filter: LegacyPhotoFilter = .normal
    public var brightness: Double = 0.0
    public var contrast: Double = 1.0
    public var saturation: Double = 1.0
    public var rotationDegrees: Int = 0
    public var zoom: CGFloat = 1.0
    public var offsetX: CGFloat = 0.0
    public var offsetY: CGFloat = 0.0
    public var captionText: String = ""
    public var includeDateStamp: Bool = false

    // Collage
    public var collageLayout: LegacyCollageLayout = .single
    public var collageImages: [NSImage] = []
    public var collageBorderSpacing: CGFloat = 8.0

    // QR Code
    public var qrContentType: LegacyQRContentType = .none
    public var qrPrimaryText: String = "https://github.com/analogbits/Instax-Offline-Printer"
    public var qrSecondaryText: String = ""
    public var qrCorner: LegacyQRCorner = .bottomRight
    public var qrSizeRatio: CGFloat = 0.18
    public var qrIncludeLabel: Bool = false
    public var qrLabelText: String = "SCAN ME"

    public init() {}

    public func encodedQRPayload() -> String? {
        let primary = qrPrimaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondary = qrSecondaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch qrContentType {
        case .none:
            return nil
        case .url, .text:
            return primary.isEmpty ? nil : primary
        case .phone:
            return primary.isEmpty ? nil : "tel:\(primary)"
        case .email:
            if primary.isEmpty { return nil }
            if secondary.isEmpty { return "mailto:\(primary)" }
            let encodedSub = secondary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? secondary
            return "mailto:\(primary)?subject=\(encodedSub)"
        case .wifi:
            if primary.isEmpty { return nil }
            let encType = secondary.isEmpty ? "nopass" : "WPA"
            return "WIFI:T:\(encType);S:\(primary);P:\(secondary);;"
        case .location:
            if primary.isEmpty { return nil }
            let lon = secondary.isEmpty ? "0.0" : secondary
            return "geo:\(primary),\(lon)"
        }
    }
}

// MARK: - Image Processor & Planar RGB Encoder

public enum LegacyImageProcessor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public static func renderPreviewAndCGImage(
        primaryImage: NSImage?,
        options: LegacyPrintOptions,
        overrideWidth: Int? = nil,
        overrideHeight: Int? = nil
    ) -> (nsImage: NSImage, cgImage: CGImage)? {
        let targetW = overrideWidth ?? options.model.width
        let targetH = overrideHeight ?? options.model.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: targetW,
            height: targetH,
            bitsPerComponent: 8,
            bytesPerRow: targetW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let canvasRect = CGRect(x: 0, y: 0, width: targetW, height: targetH)
        ctx.setFillColor(options.matteColor.cgColor)
        ctx.fill(canvasRect)

        // Assemble source images for single or multi-photo collage
        var slotImages: [NSImage] = []
        if let first = primaryImage {
            slotImages.append(first)
        }
        for extra in options.collageImages {
            slotImages.append(extra)
        }

        let rects = options.collageLayout.normalizedRects()
        let isMultiCell = rects.count > 1
        let spacing = isMultiCell ? max(0, options.collageBorderSpacing) : 0

        for (index, normRect) in rects.enumerated() {
            guard index < slotImages.count else { continue }
            let rawSlotRect = CGRect(
                x: normRect.origin.x * CGFloat(targetW),
                y: normRect.origin.y * CGFloat(targetH),
                width: normRect.size.width * CGFloat(targetW),
                height: normRect.size.height * CGFloat(targetH)
            )
            let slotRect = rawSlotRect.insetBy(dx: spacing / 2.0, dy: spacing / 2.0)
            guard slotRect.width > 4, slotRect.height > 4 else { continue }

            if let filteredCG = applyFilters(to: slotImages[index], options: options) {
                drawCGImage(
                    filteredCG,
                    in: slotRect,
                    ctx: ctx,
                    fitMode: options.fitMode,
                    zoom: index == 0 ? options.zoom : 1.0,
                    offsetX: index == 0 ? options.offsetX : 0.0,
                    offsetY: index == 0 ? options.offsetY : 0.0
                )
            }
        }

        // Outer border when collage spacing > 0
        if isMultiCell && spacing > 0 {
            ctx.saveGState()
            ctx.setStrokeColor(options.matteColor.cgColor)
            ctx.setLineWidth(spacing)
            ctx.stroke(canvasRect)
            ctx.restoreGState()
        }

        // Optional Caption & Date Stamp bar
        let hasCaption = !options.captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasCaption || options.includeDateStamp {
            drawCaptionOverlay(in: ctx, canvasW: CGFloat(targetW), canvasH: CGFloat(targetH), options: options)
        }

        // Optional QR Code Overlay
        if let qrPayload = options.encodedQRPayload(), !qrPayload.isEmpty {
            drawQROverlay(in: ctx, payload: qrPayload, canvasW: CGFloat(targetW), canvasH: CGFloat(targetH), options: options)
        }

        guard let finalCG = ctx.makeImage() else { return nil }
        let finalNS = NSImage(cgImage: finalCG, size: NSSize(width: targetW, height: targetH))
        return (finalNS, finalCG)
    }

    private static func applyFilters(to image: NSImage, options: LegacyPrintOptions) -> CGImage? {
        guard var cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Apply 90-degree step rotations if requested
        let normRot = ((options.rotationDegrees % 360) + 360) % 360
        if normRot != 0, let rotated = rotateCGImage(cgImage, degrees: normRot) {
            cgImage = rotated
        }

        var ciImage = CIImage(cgImage: cgImage)

        switch options.filter {
        case .normal:
            break
        case .fujiIntelligence:
            // Emulates Fujifilm Image Intelligence: lift shadows, crisp contrast, subtle warmth
            if let controls = CIFilter(name: "CIColorControls") {
                controls.setValue(ciImage, forKey: kCIInputImageKey)
                controls.setValue(0.04, forKey: kCIInputBrightnessKey)
                controls.setValue(1.10, forKey: kCIInputContrastKey)
                controls.setValue(1.12, forKey: kCIInputSaturationKey)
                if let out = controls.outputImage { ciImage = out }
            }
        case .mono:
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
        case .vivid:
            if let vibrance = CIFilter(name: "CIVibrance") {
                vibrance.setValue(ciImage, forKey: kCIInputImageKey)
                vibrance.setValue(0.65, forKey: "inputAmount")
                if let out = vibrance.outputImage { ciImage = out }
            }
        case .vintage:
            if let chrome = CIFilter(name: "CIPhotoEffectChrome") {
                chrome.setValue(ciImage, forKey: kCIInputImageKey)
                if let out = chrome.outputImage { ciImage = out }
            }
        }

        if options.brightness != 0.0 || options.contrast != 1.0 || options.saturation != 1.0 {
            if let controls = CIFilter(name: "CIColorControls") {
                controls.setValue(ciImage, forKey: kCIInputImageKey)
                controls.setValue(options.brightness, forKey: kCIInputBrightnessKey)
                controls.setValue(options.contrast, forKey: kCIInputContrastKey)
                controls.setValue(options.saturation, forKey: kCIInputSaturationKey)
                if let out = controls.outputImage { ciImage = out }
            }
        }

        return ciContext.createCGImage(ciImage, from: ciImage.extent) ?? cgImage
    }

    private static func rotateCGImage(_ cgImage: CGImage, degrees: Int) -> CGImage? {
        let w = cgImage.width
        let h = cgImage.height
        let swap = (degrees == 90 || degrees == 270)
        let newW = swap ? h : w
        let newH = swap ? w : h
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: newW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.translateBy(x: CGFloat(newW) / 2.0, y: CGFloat(newH) / 2.0)
        ctx.rotate(by: -CGFloat(degrees) * .pi / 180.0)
        ctx.draw(cgImage, in: CGRect(x: -CGFloat(w) / 2.0, y: -CGFloat(h) / 2.0, width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()
    }

    private static func drawCGImage(
        _ cgImage: CGImage,
        in slotRect: CGRect,
        ctx: CGContext,
        fitMode: LegacyFitMode,
        zoom: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) {
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0 else { return }

        let scaleX = slotRect.width / imgW
        let scaleY = slotRect.height / imgH
        let baseScale = (fitMode == .fill) ? max(scaleX, scaleY) : min(scaleX, scaleY)
        let finalScale = baseScale * max(0.25, min(4.0, zoom))

        let drawW = imgW * finalScale
        let drawH = imgH * finalScale
        let drawX = slotRect.midX - drawW / 2.0 + offsetX * slotRect.width * 0.5
        let drawY = slotRect.midY - drawH / 2.0 - offsetY * slotRect.height * 0.5

        ctx.saveGState()
        ctx.clip(to: slotRect)
        ctx.draw(cgImage, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
        ctx.restoreGState()
    }

    private static func drawCaptionOverlay(
        in ctx: CGContext,
        canvasW: CGFloat,
        canvasH: CGFloat,
        options: LegacyPrintOptions
    ) {
        let barH = canvasH * 0.085
        let barRect = CGRect(x: 0, y: 0, width: canvasW, height: barH)
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92))
        ctx.fill(barRect)

        var parts: [String] = []
        let cleanCap = options.captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanCap.isEmpty { parts.append(cleanCap) }
        if options.includeDateStamp {
            let df = DateFormatter()
            df.dateFormat = "yyyy.MM.dd"
            parts.append(df.string(from: Date()))
        }
        let fullText = parts.joined(separator: "  •  ")

        let nsGraphics = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphics
        let font = NSFont.monospacedSystemFont(ofSize: max(14, barH * 0.36), weight: .semibold)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
            .paragraphStyle: style
        ]
        let strSize = (fullText as NSString).size(withAttributes: attrs)
        let textRect = CGRect(
            x: 16,
            y: (barH - strSize.height) / 2.0,
            width: canvasW - 32,
            height: strSize.height + 4
        )
        (fullText as NSString).draw(in: textRect, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    private static func drawQROverlay(
        in ctx: CGContext,
        payload: String,
        canvasW: CGFloat,
        canvasH: CGFloat,
        options: LegacyPrintOptions
    ) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator"),
              let data = payload.data(using: .utf8) else { return }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputCI = filter.outputImage else { return }

        let qrSide = round(min(canvasW, canvasH) * max(0.12, min(0.32, options.qrSizeRatio)))
        let scaleX = qrSide / outputCI.extent.width
        let scaleY = qrSide / outputCI.extent.height
        let transformed = outputCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let qrCG = ciContext.createCGImage(transformed, from: transformed.extent) else { return }

        let pad: CGFloat = 10
        let labelExtra: CGFloat = options.qrIncludeLabel ? 20 : 0
        let boxW = qrSide + pad * 2
        let boxH = qrSide + pad * 2 + labelExtra
        let margin: CGFloat = 20

        let boxX: CGFloat
        let boxY: CGFloat
        switch options.qrCorner {
        case .bottomRight:
            boxX = canvasW - boxW - margin
            boxY = margin
        case .bottomLeft:
            boxX = margin
            boxY = margin
        case .topRight:
            boxX = canvasW - boxW - margin
            boxY = canvasH - boxH - margin
        case .topLeft:
            boxX = margin
            boxY = canvasH - boxH - margin
        }

        let boxRect = CGRect(x: boxX, y: boxY, width: boxW, height: boxH)
        let boxPath = CGPath(roundedRect: boxRect, cornerWidth: 10, cornerHeight: 10, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
        ctx.addPath(boxPath)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.interpolationQuality = .none
        let qrRect = CGRect(x: boxX + pad, y: boxY + pad + labelExtra, width: qrSide, height: qrSide)
        ctx.draw(qrCG, in: qrRect)
        ctx.restoreGState()

        if options.qrIncludeLabel {
            let label = options.qrLabelText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty {
                let nsGraphics = NSGraphicsContext(cgContext: ctx, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsGraphics
                let font = NSFont.systemFont(ofSize: 11, weight: .bold)
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: style
                ]
                let textRect = CGRect(x: boxX + 4, y: boxY + 4, width: boxW - 8, height: 16)
                (label as NSString).draw(in: textRect, withAttributes: attrs)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    /// Encodes a CGImage into the exact Fujifilm Instax SHARE SP-1 / SP-2 / SP-3 Column-Major Planar RGB format.
    /// - SP-1 / SP-2: 600 × 800 = 1,440,000 bytes (24 segments × 60,000 bytes)
    /// - SP-3: 800 × 800 = 1,920,000 bytes (32 segments × 60,000 bytes), rotated 90° clockwise before column encoding.
    public static func encodePlanarRGB(cgImage: CGImage, model: LegacyPrinterModel) -> Data {
        let targetW = model.width
        let targetH = model.height

        // Note: instax_api rotates SP-3 (Square 800x800) 90 degrees clockwise before column-major planar encoding
        let workingImage: CGImage
        if model == .sp3, let rotated = rotateCGImage(cgImage, degrees: 90) {
            workingImage = rotated
        } else {
            workingImage = cgImage
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 255, count: targetW * targetH * 4)
        rgba.withUnsafeMutableBytes { ptr in
            if let ctx = CGContext(
                data: ptr.baseAddress,
                width: targetW,
                height: targetH,
                bitsPerComponent: 8,
                bytesPerRow: targetW * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.interpolationQuality = .high
                ctx.draw(workingImage, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
            }
        }

        var planar = [UInt8](repeating: 0, count: targetW * targetH * 3)
        for h in 0..<targetH {
            for w in 0..<targetW {
                let pixelIdx = (h * targetW + w) * 4
                let r = rgba[pixelIdx]
                let g = rgba[pixelIdx + 1]
                let b = rgba[pixelIdx + 2]

                let colBase = w * targetH * 3
                planar[colBase + h] = r
                planar[colBase + targetH + h] = g
                planar[colBase + (targetH * 2) + h] = b
            }
        }

        return Data(planar)
    }
}

// MARK: - Instax SHARE Wi-Fi Direct TCP Packet Framing

public enum LegacyInstaxCommandType: UInt8 {
    case specifications = 0x4F   // 79
    case reset          = 0x50   // 80
    case prepImage      = 0x51   // 81
    case sendImage      = 0x52   // 82
    case triggerPrint   = 0x53   // 83 (Type 83)
    case lockState      = 0xB0   // 176
    case printerLock    = 0xB3   // 179
    case version        = 0xC0   // 192
    case printCount     = 0xC1   // 193
    case modelName      = 0xC2   // 194
    case printStatus    = 0xC3   // 195 (Type 195)
    case prePrint       = 0xC4   // 196
}

public struct LegacyInstaxResponse {
    public let mode: UInt8
    public let cmdType: UInt8
    public let length: Int
    public let sessionTime: UInt32
    public let returnCode: UInt8
    public let unknown1: UInt8
    public let ejecting: UInt8
    public let batteryLevel: Int
    public let filmRemaining: Int
    public let payload: Data

    public var isOK: Bool { returnCode == 0 }
    public var isPrinting: Bool { returnCode == 163 || returnCode == 164 }

    public var returnCodeDescription: String {
        switch returnCode {
        case 0:   return "OK (Ready)"
        case 127: return "Syntax / Parameter Error (0x7F)"
        case 160: return "Printer Busy / Processing (0xA0)"
        case 162: return "Battery Too Low to Print (0xA2)"
        case 163: return "Printing in Progress (0xA3)"
        case 164: return "Ejecting Film (0xA4)"
        case 244: return "Out of Instax Film (0xF4)"
        case 247: return "Incorrect Printer PIN Code (0xF7 — Factory Default is 1111)"
        default:  return "Status Code \(returnCode) (0x\(String(format: "%02X", returnCode)))"
        }
    }
}

public enum LegacyInstaxPacket {
    /// Builds a big-endian command packet (`0x24`) with 12-byte header, variable payload, 2-byte checksum, and `\r\n` trailer.
    public static func buildCommand(
        type: LegacyInstaxCommandType,
        sessionTime: UInt32,
        pinCode: UInt16 = 1111,
        payload: [UInt8] = []
    ) -> Data {
        let totalLength = 16 + payload.count
        var bytes = [UInt8]()
        bytes.reserveCapacity(totalLength)

        // Header (12 bytes)
        bytes.append(0x24) // Command mode = 36
        bytes.append(type.rawValue)
        bytes.append(UInt8((totalLength >> 8) & 0xFF))
        bytes.append(UInt8(totalLength & 0xFF))

        bytes.append(UInt8((sessionTime >> 24) & 0xFF))
        bytes.append(UInt8((sessionTime >> 16) & 0xFF))
        bytes.append(UInt8((sessionTime >> 8) & 0xFF))
        bytes.append(UInt8(sessionTime & 0xFF))

        bytes.append(UInt8((pinCode >> 8) & 0xFF))
        bytes.append(UInt8(pinCode & 0xFF))
        bytes.append(0x00)
        bytes.append(0x00)

        // Payload
        bytes.append(contentsOf: payload)

        // Checksum + Trailer (4 bytes)
        var sum: Int = 0
        for b in bytes { sum += Int(b) }
        let chk = (sum ^ 0xFFFF) & 0xFFFF
        bytes.append(UInt8((chk >> 8) & 0xFF))
        bytes.append(UInt8(chk & 0xFF))
        bytes.append(0x0D)
        bytes.append(0x0A)

        return Data(bytes)
    }

    /// Parses a response packet (`0x2A`) from the Instax SHARE printer.
    public static func parseResponse(_ data: Data) -> LegacyInstaxResponse? {
        guard data.count >= 16 else { return nil }
        let bytes = [UInt8](data)
        let mode = bytes[0]
        let cmdType = bytes[1]
        let length = (Int(bytes[2]) << 8) | Int(bytes[3])
        let sessionTime = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
        let returnCode = bytes[12]
        let unknown1 = bytes[13]
        let ejecting = bytes[14]
        let battAndPrints = bytes[15]
        let batteryLevel = Int((battAndPrints >> 4) & 0x07)
        let filmRemaining = Int(battAndPrints & 0x0F)

        let payloadEnd = max(16, min(bytes.count, length) - 4)
        let payload = payloadEnd > 16 ? Data(bytes[16..<payloadEnd]) : Data()

        return LegacyInstaxResponse(
            mode: mode,
            cmdType: cmdType,
            length: length,
            sessionTime: sessionTime,
            returnCode: returnCode,
            unknown1: unknown1,
            ejecting: ejecting,
            batteryLevel: batteryLevel,
            filmRemaining: filmRemaining,
            payload: payload
        )
    }
}

// MARK: - Built-In Virtual Instax SHARE Wi-Fi Simulator Server (127.0.0.1:18080)

public final class LegacyVirtualPrinterServer {
    public static let shared = LegacyVirtualPrinterServer()

    private var serverSocket: Int32 = -1
    private var isRunning = false
    public var simulatedModel: LegacyPrinterModel = .sp2
    public var simulatedFilmRemaining: Int = 8
    public var simulatedBatteryLevel: Int = 4
    public var simulatedTotalPrints: Int = 142
    public var expectedPinCode: UInt16 = 1111
    public private(set) var listenPort: UInt16 = 18080

    private var printPollCounter: Int = 0

    private init() {}

    public func start(port: UInt16 = 18080) -> Bool {
        if isRunning { return true }
        listenPort = port

        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0, Darwin.listen(sock, 16) == 0 else {
            Darwin.close(sock)
            return false
        }

        serverSocket = sock
        isRunning = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
        return true
    }

    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptLoop() {
        while isRunning && serverSocket >= 0 {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSock = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(serverSocket, $0, &clientLen)
                }
            }
            if clientSock < 0 { continue }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientSock)
            }
        }
    }

    private func handleClient(_ sock: Int32) {
        defer { Darwin.close(sock) }
        var buffer = [UInt8](repeating: 0, count: 65536)

        while isRunning {
            // Read 4-byte header first
            guard let hdr = readExact(sock: sock, count: 4, scratch: &buffer) else { break }
            let totalLen = (Int(hdr[2]) << 8) | Int(hdr[3])
            guard totalLen >= 16, totalLen <= 70000 else { break }
            guard let rest = readExact(sock: sock, count: totalLen - 4, scratch: &buffer) else { break }

            let packet = hdr + rest
            let cmdType = packet[1]
            let sessionTime = (UInt32(packet[4]) << 24) | (UInt32(packet[5]) << 16) | (UInt32(packet[6]) << 8) | UInt32(packet[7])
            let clientPin = (UInt16(packet[8]) << 8) | UInt16(packet[9])

            let pinValid = (clientPin == expectedPinCode)
            let resp = buildSimulatedResponse(cmdType: cmdType, sessionTime: sessionTime, packet: packet, pinValid: pinValid)
            _ = resp.withUnsafeBytes { ptr in
                Darwin.send(sock, ptr.baseAddress!, resp.count, 0)
            }
        }
    }

    private func readExact(sock: Int32, count: Int, scratch: inout [UInt8]) -> [UInt8]? {
        var collected = [UInt8]()
        collected.reserveCapacity(count)
        while collected.count < count {
            let toRead = min(scratch.count, count - collected.count)
            let n = Darwin.recv(sock, &scratch, toRead, 0)
            if n <= 0 { return nil }
            collected.append(contentsOf: scratch[0..<n])
        }
        return collected
    }

    private func buildSimulatedResponse(cmdType: UInt8, sessionTime: UInt32, packet: [UInt8], pinValid: Bool) -> Data {
        var returnCode: UInt8 = pinValid ? 0 : 247
        var payload = [UInt8]()

        if pinValid {
            switch cmdType {
            case LegacyInstaxCommandType.modelName.rawValue:
                payload = Array(simulatedModel.rawValue.utf8)
            case LegacyInstaxCommandType.version.rawValue:
                // unknown1(2B), firmware(2B = 0x0112 -> v1.18), hardware(2B = 0x0100)
                payload = [0x00, 0x01, 0x01, 0x12, 0x01, 0x00, 0x00, 0x00]
            case LegacyInstaxCommandType.printCount.rawValue:
                let total = UInt32(simulatedTotalPrints)
                payload = [
                    UInt8((total >> 24) & 0xFF),
                    UInt8((total >> 16) & 0xFF),
                    UInt8((total >> 8) & 0xFF),
                    UInt8(total & 0xFF),
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                ]
            case LegacyInstaxCommandType.specifications.rawValue:
                let w = UInt16(simulatedModel.width)
                let h = UInt16(simulatedModel.height)
                let msgSz = UInt16(simulatedModel.segmentSize)
                payload = [
                    UInt8((w >> 8) & 0xFF), UInt8(w & 0xFF),
                    UInt8((h >> 8) & 0xFF), UInt8(h & 0xFF),
                    0x01, 0x00,
                    0x00, 0x10,
                    0, 0, 0, 0,
                    UInt8((msgSz >> 8) & 0xFF), UInt8(msgSz & 0xFF),
                    0x00, 0x18,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                ]
            case LegacyInstaxCommandType.prePrint.rawValue:
                let cmdNo = packet.count >= 16 ? packet[15] : 1
                payload = [0x00, cmdNo, 0x00, 0x00]
            case LegacyInstaxCommandType.printerLock.rawValue:
                payload = []
            case LegacyInstaxCommandType.reset.rawValue:
                payload = []
            case LegacyInstaxCommandType.prepImage.rawValue:
                payload = [0x00, 0x1E, 0x00, 0x00]
            case LegacyInstaxCommandType.sendImage.rawValue:
                if packet.count >= 16 {
                    payload = Array(packet[12..<16])
                } else {
                    payload = [0, 0, 0, 0]
                }
            case LegacyInstaxCommandType.triggerPrint.rawValue:
                printPollCounter = 2
                if simulatedFilmRemaining > 0 {
                    simulatedFilmRemaining -= 1
                }
                simulatedTotalPrints += 1
                payload = [0, 0, 0, 0]
            case LegacyInstaxCommandType.lockState.rawValue:
                payload = [0, 0, 0, 1]
            case LegacyInstaxCommandType.printStatus.rawValue:
                if printPollCounter > 0 {
                    printPollCounter -= 1
                    returnCode = 163 // Printing
                } else {
                    returnCode = 0 // Complete
                }
                payload = [0, 0, 0, 0]
            default:
                payload = [0, 0, 0, 0]
            }
        }

        let totalLen = 20 + payload.count
        var bytes = [UInt8]()
        bytes.reserveCapacity(totalLen)
        bytes.append(0x2A) // Response mode = 42
        bytes.append(cmdType)
        bytes.append(UInt8((totalLen >> 8) & 0xFF))
        bytes.append(UInt8(totalLen & 0xFF))
        bytes.append(UInt8((sessionTime >> 24) & 0xFF))
        bytes.append(UInt8((sessionTime >> 16) & 0xFF))
        bytes.append(UInt8((sessionTime >> 8) & 0xFF))
        bytes.append(UInt8(sessionTime & 0xFF))
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        bytes.append(returnCode)
        bytes.append(0x00)
        bytes.append(0x00)
        let battAndPrints = UInt8(((simulatedBatteryLevel & 0x07) << 4) | (simulatedFilmRemaining & 0x0F))
        bytes.append(battAndPrints)
        bytes.append(contentsOf: payload)

        var sum: Int = 0
        for b in bytes { sum += Int(b) }
        let chk = (sum ^ 0xFFFF) & 0xFFFF
        bytes.append(UInt8((chk >> 8) & 0xFF))
        bytes.append(UInt8(chk & 0xFF))
        bytes.append(0x0D)
        bytes.append(0x0A)
        return Data(bytes)
    }
}

// MARK: - Synchronous POSIX TCP Session Client (With Non-Blocking Connect Timeout)

public enum LegacyTCPClientError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveTimeout
    case malformedResponse
    case printerError(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return msg
        case .sendFailed(let msg): return msg
        case .receiveTimeout: return "Timed out waiting for response from Instax SHARE printer."
        case .malformedResponse: return "Received invalid packet from Instax SHARE printer."
        case .printerError(let msg): return msg
        }
    }
}

public final class LegacyTCPSession {
    private var sock: Int32 = -1
    public let host: String
    public let port: UInt16
    public let pinCode: UInt16
    public let sessionTime: UInt32

    public init(host: String, port: UInt16, pinCode: UInt16, sessionTime: UInt32) {
        self.host = host
        self.port = port
        self.pinCode = pinCode
        self.sessionTime = sessionTime
    }

    deinit {
        close()
    }

    public func connect(timeoutSeconds: Double = 3.5) throws {
        close()
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw LegacyTCPClientError.connectionFailed("Unable to create TCP socket.")
        }

        // Prevent SIGPIPE crashes on broken pipe
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        // Set non-blocking for connect timeout
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if res < 0 && errno != EINPROGRESS {
            Darwin.close(fd)
            throw LegacyTCPClientError.connectionFailed("Cannot reach \(host):\(port). Join your printer's INSTAX-XXXXXXXX Wi-Fi network first (or enable Virtual Simulator).")
        }

        if res != 0 {
            var writeSet = fd_set()
            darwinFDZero(&writeSet)
            darwinFDSet(fd, set: &writeSet)

            let sec = Int(timeoutSeconds)
            let usec = Int32((timeoutSeconds - Double(sec)) * 1_000_000)
            var tv = timeval(tv_sec: sec, tv_usec: usec)

            let sel = Darwin.select(fd + 1, nil, &writeSet, nil, &tv)
            if sel <= 0 {
                Darwin.close(fd)
                throw LegacyTCPClientError.connectionFailed("Connection timed out to \(host):\(port). Make sure your Mac is connected to the INSTAX-XXXXXXXX Wi-Fi Direct hotspot.")
            }

            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
            if soError != 0 {
                Darwin.close(fd)
                throw LegacyTCPClientError.connectionFailed("Connection refused by \(host):\(port) (errno \(soError)).")
            }
        }

        // Restore blocking mode with 6-second send/recv timeouts
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        var rcvTimeout = timeval(tv_sec: 6, tv_usec: 0)
        var sndTimeout = timeval(tv_sec: 6, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &rcvTimeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &sndTimeout, socklen_t(MemoryLayout<timeval>.size))

        self.sock = fd
    }

    public func close() {
        if sock >= 0 {
            Darwin.close(sock)
            sock = -1
        }
    }

    public func sendAndReceive(type: LegacyInstaxCommandType, payload: [UInt8] = []) throws -> LegacyInstaxResponse {
        guard sock >= 0 else {
            throw LegacyTCPClientError.connectionFailed("Socket is not connected.")
        }
        let cmdData = LegacyInstaxPacket.buildCommand(type: type, sessionTime: sessionTime, pinCode: pinCode, payload: payload)

        try cmdData.withUnsafeBytes { ptr in
            var sent = 0
            let total = cmdData.count
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            while sent < total {
                let n = Darwin.send(sock, base.advanced(by: sent), total - sent, 0)
                if n <= 0 {
                    throw LegacyTCPClientError.sendFailed("Failed while sending command 0x\(String(format: "%02X", type.rawValue)).")
                }
                sent += n
            }
        }

        let hdr = try readExact(count: 4)
        let totalLen = (Int(hdr[2]) << 8) | Int(hdr[3])
        guard totalLen >= 16, totalLen <= 65536 else {
            throw LegacyTCPClientError.malformedResponse
        }
        let body = try readExact(count: totalLen - 4)
        let fullData = Data(hdr + body)
        guard let parsed = LegacyInstaxPacket.parseResponse(fullData) else {
            throw LegacyTCPClientError.malformedResponse
        }
        return parsed
    }

    private func readExact(count: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 4096)
        var out = [UInt8]()
        out.reserveCapacity(count)
        while out.count < count {
            let chunk = min(buf.count, count - out.count)
            let n = Darwin.recv(sock, &buf, chunk, 0)
            if n <= 0 {
                throw LegacyTCPClientError.receiveTimeout
            }
            out.append(contentsOf: buf[0..<n])
        }
        return out
    }

    private func darwinFDZero(_ set: inout fd_set) {
        set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private func darwinFDSet(_ fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd / 32)
        let bitOffset = Int(fd % 32)
        let mask = Int32(1 << bitOffset)
        withUnsafeMutablePointer(to: &set.fds_bits) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: Int32.self)
            raw[intOffset] |= mask
        }
    }
}

// MARK: - High-Level Printer Manager (ObservableObject for SwiftUI + CLI)

public struct LegacyPrinterTelemetry {
    public var modelName: String = "SP-2"
    public var firmwareVersion: String = "v1.18"
    public var batteryLevel: Int = 4     // 0..4
    public var filmRemaining: Int = 10   // 0..10
    public var totalPrintHistory: Int = 0
    public var maxWidth: Int = 600
    public var maxHeight: Int = 800
}

public final class LegacyPrinterManager: ObservableObject {
    @Published public var printerIP: String = "192.168.0.251"
    @Published public var printerPort: String = "8080"
    @Published public var pinCode: String = "1111"
    @Published public var useVirtualSimulator: Bool = false {
        didSet {
            if useVirtualSimulator {
                _ = LegacyVirtualPrinterServer.shared.start(port: 18080)
                printerIP = "127.0.0.1"
                printerPort = "18080"
                appendLog("🟢 Built-in Virtual Instax SHARE Simulator started at 127.0.0.1:18080")
            } else {
                printerIP = "192.168.0.251"
                printerPort = "8080"
                appendLog("📡 Switched target to physical Instax SHARE Wi-Fi Direct (192.168.0.251:8080)")
            }
        }
    }
    @Published public var dryRunMode: Bool = false

    @Published public var isConnected: Bool = false
    @Published public var isBusy: Bool = false
    @Published public var statusHeadline: String = "Ready to connect over Wi-Fi Direct (192.168.0.251:8080)"
    @Published public var progressValue: Double = 0.0
    @Published public var telemetry = LegacyPrinterTelemetry()
    @Published public var detectedWiFiSSID: String = "Checking Wi-Fi..."
    @Published public var logs: [String] = []

    public init() {
        refreshWiFiEnvironment()
    }

    public func appendLog(_ message: String) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let line = "[\(df.string(from: Date()))] \(message)"
        if Thread.isMainThread {
            logs.append(line)
            if logs.count > 250 { logs.removeFirst(logs.count - 250) }
        } else {
            DispatchQueue.main.async {
                self.logs.append(line)
                if self.logs.count > 250 { self.logs.removeFirst(self.logs.count - 250) }
            }
        }
    }

    public func refreshWiFiEnvironment() {
        DispatchQueue.global(qos: .utility).async {
            var ssid = "Wi-Fi Active"
            // Check local IP on 192.168.0.x subnet
            var onInstaxSubnet = false
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0, let first = ifaddr {
                var ptr: UnsafeMutablePointer<ifaddrs>? = first
                while let cur = ptr {
                    let addr = cur.pointee.ifa_addr
                    if let addr = addr, addr.pointee.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(cString: hostname)
                            if ip.hasPrefix("192.168.0.") {
                                onInstaxSubnet = true
                                ssid = "Instax Subnet (\(ip))"
                            }
                        }
                    }
                    ptr = cur.pointee.ifa_next
                }
                freeifaddrs(ifaddr)
            }
            DispatchQueue.main.async {
                if self.useVirtualSimulator {
                    self.detectedWiFiSSID = "Virtual SP-1/2/3 Simulator (127.0.0.1:18080)"
                } else if onInstaxSubnet {
                    self.detectedWiFiSSID = "Connected to \(ssid)"
                } else {
                    self.detectedWiFiSSID = "Join 'INSTAX-XXXXXXXX' in macOS Wi-Fi Menu"
                }
            }
        }
    }

    /// Queries the printer's Model Name (0xC2), Version (0xC0), Specifications (0x4F), and Print Count (0xC1).
    public func queryPrinterStatus(onModelDetected: ((LegacyPrinterModel) -> Void)? = nil) {
        guard !isBusy else { return }
        isBusy = true
        refreshWiFiEnvironment()

        let host = printerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = UInt16(printerPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8080
        let pin = UInt16(pinCode.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1111
        let sessionTime = UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 * 1000))

        appendLog("🔍 Connecting to \(host):\(port) (PIN: \(pin))...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                try session.connect(timeoutSeconds: 3.5)
                defer { session.close() }

                let modelResp = try session.sendAndReceive(type: .modelName)
                if !modelResp.isOK {
                    throw LegacyTCPClientError.printerError(modelResp.returnCodeDescription)
                }
                let rawName = String(data: modelResp.payload, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines)) ?? "SP-2"

                let verResp = try session.sendAndReceive(type: .version)
                var fwString = "v1.0"
                if verResp.payload.count >= 4 {
                    let fwHi = verResp.payload[2]
                    let fwLo = verResp.payload[3]
                    fwString = String(format: "v%d.%02d", fwHi, fwLo)
                }

                let specResp = try session.sendAndReceive(type: .specifications)
                var maxW = 600
                var maxH = 800
                if specResp.payload.count >= 4 {
                    maxW = (Int(specResp.payload[0]) << 8) | Int(specResp.payload[1])
                    maxH = (Int(specResp.payload[2]) << 8) | Int(specResp.payload[3])
                }

                let countResp = try session.sendAndReceive(type: .printCount)
                var totalPrints = 0
                if countResp.payload.count >= 4 {
                    totalPrints = (Int(countResp.payload[0]) << 24) | (Int(countResp.payload[1]) << 16) | (Int(countResp.payload[2]) << 8) | Int(countResp.payload[3])
                }

                let detectedModel: LegacyPrinterModel
                if rawName.uppercased().contains("SP-3") || (maxW == 800 && maxH == 800) {
                    detectedModel = .sp3
                } else if rawName.uppercased().contains("SP-1") {
                    detectedModel = .sp1
                } else {
                    detectedModel = .sp2
                }

                DispatchQueue.main.async {
                    self.telemetry = LegacyPrinterTelemetry(
                        modelName: rawName.isEmpty ? detectedModel.rawValue : rawName,
                        firmwareVersion: fwString,
                        batteryLevel: modelResp.batteryLevel,
                        filmRemaining: modelResp.filmRemaining,
                        totalPrintHistory: totalPrints,
                        maxWidth: maxW,
                        maxHeight: maxH
                    )
                    self.isConnected = true
                    self.isBusy = false
                    self.statusHeadline = "Connected to \(self.telemetry.modelName) • \(self.telemetry.filmRemaining)/10 Film Left • Battery \(self.telemetry.batteryLevel)/4"
                    self.appendLog("✅ Connected: \(self.telemetry.modelName) (\(fwString)) | Resolution: \(maxW)×\(maxH) | Film: \(self.telemetry.filmRemaining)/10 | Total Prints: \(totalPrints)")
                    onModelDetected?(detectedModel)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isBusy = false
                    self.statusHeadline = error.localizedDescription
                    self.appendLog("❌ Connection Error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Executes the complete 5-Phase Instax SHARE Wi-Fi Direct TCP Print Sequence (or 0-Film Dry Run Test).
    public func printCGImage(
        _ cgImage: CGImage,
        model: LegacyPrinterModel,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isBusy else { return }
        isBusy = true
        progressValue = 0.02

        let host = printerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = UInt16(printerPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8080
        let pin = UInt16(pinCode.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1111
        let isDryRun = dryRunMode
        let sessionTime = UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 * 1000))

        appendLog(isDryRun
            ? "🧪 Starting DRY RUN (0-Film Test) for \(model.displayName) to \(host):\(port)..."
            : "🖨️ Starting Wi-Fi Direct Print for \(model.displayName) to \(host):\(port)...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Encode Column-Major Planar RGB
                let planarData = LegacyImageProcessor.encodePlanarRGB(cgImage: cgImage, model: model)
                let totalBytes = planarData.count
                let segmentSize = model.segmentSize
                let numSegments = totalBytes / segmentSize

                self.appendLog("📐 Encoded Planar RGB payload: \(totalBytes) bytes (\(numSegments) segments × \(segmentSize) B)")

                // PHASE 1: Pre-Print Commands 1..8
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 1/5: Negotiating Pre-Print Handshake (1..8)..."
                    self.progressValue = 0.08
                }
                do {
                    let s1 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s1.connect()
                    defer { s1.close() }
                    for cmdNum in 1...8 {
                        let resp = try s1.sendAndReceive(type: .prePrint, payload: [0x00, 0x00, 0x00, UInt8(cmdNum)])
                        if !resp.isOK {
                            throw LegacyTCPClientError.printerError("PrePrint[\(cmdNum)] rejected: \(resp.returnCodeDescription)")
                        }
                    }
                }
                self.appendLog("✓ Phase 1 complete: PrePrint 1..8 acknowledged.")
                Thread.sleep(forTimeInterval: 0.35)

                // PHASE 2: Lock Printer
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 2/5: Locking Instax SHARE Print Engine..."
                    self.progressValue = 0.15
                }
                do {
                    let s2 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s2.connect()
                    defer { s2.close() }
                    let resp = try s2.sendAndReceive(type: .printerLock, payload: [0x01, 0x00, 0x00, 0x00])
                    if !resp.isOK {
                        throw LegacyTCPClientError.printerError("Lock Printer rejected: \(resp.returnCodeDescription)")
                    }
                }
                self.appendLog("✓ Phase 2 complete: Printer locked for exclusive transfer.")
                Thread.sleep(forTimeInterval: 0.35)

                // PHASE 3: Reset Printer Buffer
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 3/5: Resetting Printer Image Buffer..."
                    self.progressValue = 0.22
                }
                do {
                    let s3 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s3.connect()
                    defer { s3.close() }
                    let resp = try s3.sendAndReceive(type: .reset)
                    if !resp.isOK {
                        throw LegacyTCPClientError.printerError("Reset Buffer rejected: \(resp.returnCodeDescription)")
                    }
                }
                self.appendLog("✓ Phase 3 complete: Printer buffer cleared.")
                Thread.sleep(forTimeInterval: 0.35)

                // PHASE 4: PrepImage + SendImage Segments (0..<numSegments) + TriggerPrint
                do {
                    let s4 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s4.connect()
                    defer { s4.close() }

                    let lenU32 = UInt32(totalBytes)
                    let prepPayload: [UInt8] = [
                        0x10, 0x00,
                        UInt8((lenU32 >> 24) & 0xFF),
                        UInt8((lenU32 >> 16) & 0xFF),
                        UInt8((lenU32 >> 8) & 0xFF),
                        UInt8(lenU32 & 0xFF),
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    ]
                    let prepResp = try s4.sendAndReceive(type: .prepImage, payload: prepPayload)
                    if !prepResp.isOK {
                        throw LegacyTCPClientError.printerError("PrepImage rejected: \(prepResp.returnCodeDescription)")
                    }

                    let allBytes = [UInt8](planarData)
                    for seg in 0..<numSegments {
                        let start = seg * segmentSize
                        let end = start + segmentSize
                        var segPayload = [UInt8]()
                        segPayload.reserveCapacity(4 + segmentSize)
                        let seq = UInt32(seg)
                        segPayload.append(UInt8((seq >> 24) & 0xFF))
                        segPayload.append(UInt8((seq >> 16) & 0xFF))
                        segPayload.append(UInt8((seq >> 8) & 0xFF))
                        segPayload.append(UInt8(seq & 0xFF))
                        segPayload.append(contentsOf: allBytes[start..<end])

                        let segResp = try s4.sendAndReceive(type: .sendImage, payload: segPayload)
                        if !segResp.isOK {
                            throw LegacyTCPClientError.printerError("Segment \(seg + 1)/\(numSegments) failed: \(segResp.returnCodeDescription)")
                        }

                        let frac = 0.25 + (Double(seg + 1) / Double(numSegments)) * 0.60
                        DispatchQueue.main.async {
                            self.progressValue = frac
                            self.statusHeadline = "Phase 4/5: Transmitting Planar RGB Segment \(seg + 1)/\(numSegments)..."
                        }
                    }

                    if isDryRun {
                        self.appendLog("🧪 DRY RUN: All \(numSegments) segments (\(totalBytes) B) verified by printer RAM! Skipping Type 83 (0x53) print trigger so 0 film is used.")
                    } else {
                        let trigResp = try s4.sendAndReceive(type: .triggerPrint)
                        if !trigResp.isOK && !trigResp.isPrinting {
                            throw LegacyTCPClientError.printerError("Print Trigger (0x53) failed: \(trigResp.returnCodeDescription)")
                        }
                        self.appendLog("✓ Phase 4 complete: All \(numSegments) segments sent & physical print triggered!")
                    }
                }
                Thread.sleep(forTimeInterval: 0.35)

                // PHASE 5: Final Status Poll (or Dry Run Buffer Reset)
                if isDryRun {
                    let s5 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s5.connect()
                    defer { s5.close() }
                    _ = try? s5.sendAndReceive(type: .reset)
                    let finalInfo = try s5.sendAndReceive(type: .modelName)
                    DispatchQueue.main.async {
                        self.telemetry.batteryLevel = finalInfo.batteryLevel
                        self.telemetry.filmRemaining = finalInfo.filmRemaining
                        self.progressValue = 1.0
                        self.isBusy = false
                        self.isConnected = true
                        self.statusHeadline = "✅ Dry Run Passed! 100% of \(totalBytes / 1000) KB Verified (0 Film Used)"
                        self.appendLog("🎉 DRY RUN COMPLETE: Connection, PIN, and \(numSegments) segments verified with 0 film used.")
                        completion?(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusHeadline = "Phase 5/5: Developing & Ejecting Instax Film..."
                        self.progressValue = 0.90
                    }
                    let s5 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s5.connect()
                    defer { s5.close() }
                    _ = try? s5.sendAndReceive(type: .lockState)
                    _ = try? s5.sendAndReceive(type: .version)
                    let infoResp = try s5.sendAndReceive(type: .modelName)

                    var finalFilm = infoResp.filmRemaining
                    var finalBatt = infoResp.batteryLevel
                    for _ in 0..<30 {
                        let poll = try s5.sendAndReceive(type: .printStatus)
                        finalFilm = poll.filmRemaining
                        finalBatt = poll.batteryLevel
                        if poll.isOK { break }
                        Thread.sleep(forTimeInterval: 0.5)
                    }

                    DispatchQueue.main.async {
                        self.telemetry.filmRemaining = finalFilm
                        self.telemetry.batteryLevel = finalBatt
                        self.telemetry.totalPrintHistory += 1
                        self.progressValue = 1.0
                        self.isBusy = false
                        self.isConnected = true
                        self.statusHeadline = "✅ Print Complete! (\(finalFilm)/10 Film Remaining)"
                        self.appendLog("🎉 Print finished! Remaining film: \(finalFilm)/10 | Battery: \(finalBatt)/4")
                        completion?(true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.progressValue = 0.0
                    self.statusHeadline = "❌ \(error.localizedDescription)"
                    self.appendLog("❌ Print Aborted: \(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }
}
