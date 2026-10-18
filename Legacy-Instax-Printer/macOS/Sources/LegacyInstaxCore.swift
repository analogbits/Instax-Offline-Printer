import Foundation
import AppKit
import CoreGraphics
import CoreImage
import Combine
import CoreWLAN
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

    /// Portrait canvas width shown in the UI and reported as `maxWidth` by SpecificationsCommand (0x4F)
    public var width: Int {
        switch self {
        case .sp1, .sp2: return 600
        case .sp3: return 800
        }
    }

    /// Portrait canvas height shown in the UI and reported as `maxHeight` by SpecificationsCommand (0x4F)
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

// MARK: - Wi-Fi & Subnet Discovery Item

public struct LegacyWiFiDiscoveryItem: Identifiable, Hashable {
    public enum Kind: String, Hashable {
        case instaxWiFiSSID
        case currentWiFiSSID
        case reachablePrinterEndpoint
        case defaultPrinterEndpoint
        case virtualSimulator
    }

    public let id: String
    public let title: String
    public let ssid: String?
    public let host: String
    public let port: UInt16
    public let kind: Kind

    public init(id: String, title: String, ssid: String?, host: String, port: UInt16, kind: Kind) {
        self.id = id
        self.title = title
        self.ssid = ssid
        self.host = host
        self.port = port
        self.kind = kind
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

    // Analog Creative FX (Ported from PolaroidEngine)
    public var warmth: Double = 0.0
    public var vignette: Double = 0.0
    public var lightLeak: String = "none"
    public var leakPlacement: String = "auto"
    public var leakIntensity: Double = 0.70
    public var filmGrain: Double = 0.0
    public var analogWear: Double = 0.0
    public var showVintageDate: Bool = false
    public var vintageDateText: String = ""
    public var vintageDateColor: String = "amber"
    public var vintageDatePlacement: String = "bottomRight"

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

// MARK: - Image Processor & Bit-Exact Instax SHARE Planar RGB Encoder

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

        if isMultiCell && spacing > 0 {
            ctx.saveGState()
            ctx.setStrokeColor(options.matteColor.cgColor)
            ctx.setLineWidth(spacing)
            ctx.stroke(canvasRect)
            ctx.restoreGState()
        }

        // Analog Creative FX Pipeline (Ported from PolaroidEngine)
        applyAnalogWarmth(ctx: ctx, rect: canvasRect, warmth: options.warmth)
        drawLensVignette(ctx: ctx, rect: canvasRect, intensity: options.vignette)
        drawLightLeakEffect(ctx: ctx, rect: canvasRect, type: options.lightLeak, placement: options.leakPlacement, intensity: options.leakIntensity)
        drawTactileFilmGrain(ctx: ctx, rect: canvasRect, intensity: options.filmGrain)
        drawAnalogWear(ctx: ctx, rect: canvasRect, intensity: options.analogWear)
        if options.showVintageDate {
            drawVintageDateStamp(ctx: ctx, rect: canvasRect, text: options.vintageDateText, colorName: options.vintageDateColor, placement: options.vintageDatePlacement)
        }

        let hasCaption = !options.captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasCaption || options.includeDateStamp {
            drawCaptionOverlay(in: ctx, canvasW: CGFloat(targetW), canvasH: CGFloat(targetH), options: options)
        }

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

        let normRot = ((options.rotationDegrees % 360) + 360) % 360
        if normRot != 0, let rotated = rotateCGImage(cgImage, degrees: normRot) {
            cgImage = rotated
        }

        var ciImage = CIImage(cgImage: cgImage)

        switch options.filter {
        case .normal:
            break
        case .fujiIntelligence:
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

    public static func rotateCGImage(_ cgImage: CGImage, degrees: Int) -> CGImage? {
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

        let ctFont = CTFontCreateWithName("Menlo-Bold" as CFString, max(14, barH * 0.36), nil)
        let darkCG = CGColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): darkCG
        ]
        let attrStr = NSAttributedString(string: fullText, attributes: attrs)
        let ctLine = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(ctLine, [])
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(
            x: max(16, (canvasW - bounds.width) / 2.0),
            y: (barH - bounds.height) / 2.0 - bounds.origin.y * 0.5
        )
        CTLineDraw(ctLine, ctx)
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
                ctx.saveGState()
                let ctFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 11.0, nil)
                let blackCG = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0)
                let attrs: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): blackCG
                ]
                let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attrs))
                let bounds = CTLineGetBoundsWithOptions(ctLine, [])
                ctx.textMatrix = .identity
                ctx.textPosition = CGPoint(x: boxX + max(4, (boxW - bounds.width) / 2.0), y: boxY + 6)
                CTLineDraw(ctLine, ctx)
                ctx.restoreGState()
            }
        }
    }

    // MARK: - Analog Creative FX Methods

    public static func applyAnalogWarmth(ctx: CGContext, rect: CGRect, warmth: Double) {
        guard abs(warmth) >= 0.01 else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setBlendMode(.softLight)
        if warmth > 0 {
            let alpha = min(1.0, warmth * 0.65)
            ctx.setFillColor(red: 1.0, green: 175.0 / 255.0, blue: 45.0 / 255.0, alpha: CGFloat(alpha))
            ctx.fill(rect)
        } else {
            let alpha = min(1.0, (-warmth) * 0.65)
            ctx.setFillColor(red: 45.0 / 255.0, green: 135.0 / 255.0, blue: 1.0, alpha: CGFloat(alpha))
            ctx.fill(rect)
        }
        if warmth > 0.4 {
            ctx.setBlendMode(.multiply)
            let alpha = (warmth - 0.4) * 0.30
            ctx.setFillColor(red: 1.0, green: 240.0 / 255.0, blue: 210.0 / 255.0, alpha: CGFloat(alpha))
            ctx.fill(rect)
        }
        ctx.restoreGState()
    }

    public static func drawLensVignette(ctx: CGContext, rect: CGRect, intensity: Double) {
        guard intensity > 0.01 else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        let cx = rect.midX
        let cy = rect.midY
        let maxR = hypot(rect.width, rect.height) / 2.0
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors: [CGColor] = [
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(intensity * 0.30)),
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(intensity * 0.90))
        ]
        let locations: [CGFloat] = [0.0, 0.65, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: cx, y: cy), startRadius: maxR * 0.32, endCenter: CGPoint(x: cx, y: cy), endRadius: maxR, options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
    }

    public static func drawLightLeakEffect(ctx: CGContext, rect: CGRect, type: String, placement: String, intensity: Double, seed: Int = 12345) {
        guard type != "none" && intensity > 0.01 else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setBlendMode(.screen)
        ctx.setAlpha(CGFloat(min(1.0, intensity)))

        var p = placement
        if p.isEmpty || p == "auto" {
            if type == "burn" {
                p = (seed % 2 == 0) ? "left" : "right"
            } else if type == "sunburst" {
                p = (seed % 2 == 0) ? "topRight" : "topLeft"
            } else if type == "sunset" {
                p = "bottomLeft"
            } else if type == "rainbow" {
                p = (seed % 2 == 0) ? "right" : "diagonal"
            } else {
                p = "left"
            }
        }

        let c1: CGColor
        let c2: CGColor
        let c3: CGColor
        if type == "sunburst" {
            c1 = CGColor(srgbRed: 1.0, green: 250.0 / 255.0, blue: 215.0 / 255.0, alpha: 1.0)
            c2 = CGColor(srgbRed: 1.0, green: 175.0 / 255.0, blue: 45.0 / 255.0, alpha: 0.75)
            c3 = CGColor(srgbRed: 240.0 / 255.0, green: 70.0 / 255.0, blue: 38.0 / 255.0, alpha: 0.30)
        } else if type == "sunset" {
            c1 = CGColor(srgbRed: 1.0, green: 115.0 / 255.0, blue: 45.0 / 255.0, alpha: 0.95)
            c2 = CGColor(srgbRed: 1.0, green: 190.0 / 255.0, blue: 75.0 / 255.0, alpha: 0.60)
            c3 = CGColor(srgbRed: 190.0 / 255.0, green: 38.0 / 255.0, blue: 115.0 / 255.0, alpha: 0.25)
        } else {
            c1 = CGColor(srgbRed: 1.0, green: 45.0 / 255.0, blue: 15.0 / 255.0, alpha: 0.95)
            c2 = CGColor(srgbRed: 1.0, green: 140.0 / 255.0, blue: 30.0 / 255.0, alpha: 0.65)
            c3 = CGColor(srgbRed: 205.0 / 255.0, green: 20.0 / 255.0, blue: 90.0 / 255.0, alpha: 0.25)
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let leakColors: [CGColor] = [c1, c2, c3, CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)]
        let leakLocations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]

        if let grad = CGGradient(colorsSpace: colorSpace, colors: leakColors as CFArray, locations: leakLocations) {
            let x = rect.origin.x
            let y = rect.origin.y
            let w = rect.width
            let h = rect.height

            switch p {
            case "left":
                ctx.drawLinearGradient(grad, start: CGPoint(x: x, y: y + h * 0.5), end: CGPoint(x: x + w * 0.45, y: y + h * 0.5), options: [])
            case "right":
                ctx.drawLinearGradient(grad, start: CGPoint(x: x + w, y: y + h * 0.5), end: CGPoint(x: x + w - w * 0.45, y: y + h * 0.5), options: [])
            case "topRight":
                let center = CGPoint(x: x + w, y: rect.maxY)
                ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * 0.85, options: [])
            case "topLeft":
                let center = CGPoint(x: x, y: rect.maxY)
                ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * 0.85, options: [])
            case "bottomLeft":
                ctx.drawLinearGradient(grad, start: CGPoint(x: x, y: rect.minY), end: CGPoint(x: x + w * 0.5 + 60, y: rect.minY + h * 0.5 + 60), options: [])
            case "bottomRight":
                let center = CGPoint(x: x + w, y: rect.minY)
                ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * 0.85, options: [])
            case "diagonal":
                ctx.drawLinearGradient(grad, start: CGPoint(x: x, y: rect.maxY), end: CGPoint(x: x + w, y: rect.minY), options: [])
            default:
                ctx.drawLinearGradient(grad, start: CGPoint(x: x, y: y + h * 0.5), end: CGPoint(x: x + w * 0.45, y: y + h * 0.5), options: [])
            }
        }

        if type == "rainbow" {
            let rainbowColors: [CGColor] = [
                CGColor(srgbRed: 1.0, green: 64.0 / 255.0, blue: 64.0 / 255.0, alpha: 0.65),
                CGColor(srgbRed: 1.0, green: 153.0 / 255.0, blue: 38.0 / 255.0, alpha: 0.65),
                CGColor(srgbRed: 1.0, green: 230.0 / 255.0, blue: 51.0 / 255.0, alpha: 0.65),
                CGColor(srgbRed: 64.0 / 255.0, green: 217.0 / 255.0, blue: 115.0 / 255.0, alpha: 0.65),
                CGColor(srgbRed: 51.0 / 255.0, green: 153.0 / 255.0, blue: 242.0 / 255.0, alpha: 0.65),
                CGColor(srgbRed: 166.0 / 255.0, green: 77.0 / 255.0, blue: 217.0 / 255.0, alpha: 0.65)
            ]
            let stripeW = rect.width * 0.08
            for i in 0..<6 {
                ctx.setFillColor(rainbowColors[i])
                let stripeRect = CGRect(x: rect.origin.x + rect.width - CGFloat(6 - i) * stripeW, y: rect.origin.y, width: stripeW * 1.4, height: rect.height)
                ctx.fill(stripeRect)
            }
        }

        ctx.restoreGState()
    }

    public static func drawTactileFilmGrain(ctx: CGContext, rect: CGRect, intensity: Double, seed: Int = 12345) {
        guard intensity > 0.01 else { return }
        let gw = min(320, max(64, Int(rect.width / 2.2)))
        let gh = min(320, max(64, Int(rect.height / 2.2)))

        var s = seed
        var pixelData = [UInt8](repeating: 0, count: gw * gh * 4)
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            s = (s &* 9301 &+ 49297) % 233280
            let val = UInt8((s * 256) / 233280)
            pixelData[i] = val
            pixelData[i + 1] = val
            pixelData[i + 2] = val
            pixelData[i + 3] = 255
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let grainCG = CGImage(
                width: gw,
                height: gh,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: gw * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return }

        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setBlendMode(.overlay)
        ctx.setAlpha(CGFloat(min(1.0, intensity * 0.85)))
        ctx.interpolationQuality = .none
        ctx.draw(grainCG, in: rect)
        ctx.restoreGState()
    }

    public static func drawAnalogWear(ctx: CGContext, rect: CGRect, intensity: Double, seed: Int = 54321) {
        guard intensity > 0.01 else { return }
        ctx.saveGState()
        ctx.clip(to: rect)

        var s = seed
        func rng() -> Double {
            s = (s &* 9301 &+ 49297) % 233280
            return Double(s) / 233280.0
        }

        let dustCount = 10 + Int(intensity * 32.0)
        for _ in 0..<dustCount {
            let rx = rect.origin.x + CGFloat(rng()) * rect.width
            let ry = rect.origin.y + CGFloat(rng()) * rect.height
            let isWhite = rng() < 0.33
            let alpha = (0.20 + rng() * 0.40) * min(1.0, intensity * 1.2)

            let strokeColor = isWhite ? CGColor(srgbRed: 242/255, green: 242/255, blue: 245/255, alpha: CGFloat(alpha))
                                      : CGColor(srgbRed: 38/255, green: 30/255, blue: 25/255, alpha: CGFloat(alpha * 0.85))

            let type = Int(rng() * 3)
            if type == 0 {
                let len = CGFloat(5.0 + rng() * 14.0)
                let angle = CGFloat(rng() * 2.0 * .pi)
                let curve = CGFloat(-4.0 + rng() * 8.0)

                ctx.setLineWidth(CGFloat(0.8 + rng() * 0.6))
                ctx.setLineCap(.round)
                ctx.setStrokeColor(strokeColor)

                let path = CGMutablePath()
                path.move(to: CGPoint(x: rx, y: ry))
                let ctrlX = rx + cos(angle) * (len * 0.5) + sin(angle) * curve
                let ctrlY = ry + sin(angle) * (len * 0.5) - cos(angle) * curve
                let endX = rx + cos(angle) * len
                let endY = ry + sin(angle) * len
                path.addQuadCurve(to: CGPoint(x: endX, y: endY), control: CGPoint(x: ctrlX, y: ctrlY))
                ctx.addPath(path)
                ctx.strokePath()
            } else if type == 1 {
                let len = CGFloat(8.0 + rng() * 26.0)
                let angle = CGFloat(rng() * .pi)
                ctx.setLineWidth(0.7)
                ctx.setStrokeColor(strokeColor)
                ctx.strokeLineSegments(between: [
                    CGPoint(x: rx, y: ry),
                    CGPoint(x: rx + cos(angle) * len, y: ry + sin(angle) * len)
                ])
            } else {
                let r = CGFloat(0.8 + rng() * 1.5)
                ctx.setFillColor(strokeColor)
                ctx.fillEllipse(in: CGRect(x: rx - r, y: ry - r, width: r * 2, height: r * 2))
            }
        }

        if intensity > 0.12 {
            ctx.setBlendMode(.screen)
            let podAtBottom = Int(rng() * 2) == 0
            let gradH = rect.height * CGFloat(0.08 + intensity * 0.12)
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let c1 = CGColor(srgbRed: 1.0, green: 191/255, blue: 115/255, alpha: CGFloat(0.26 * intensity))
            let c2 = CGColor(srgbRed: 230/255, green: 153/255, blue: 76/255, alpha: CGFloat(0.10 * intensity))
            let c3 = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)

            if let grad = CGGradient(colorsSpace: colorSpace, colors: [c1, c2, c3] as CFArray, locations: [0.0, 0.4, 1.0]) {
                if podAtBottom {
                    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.origin.x, y: rect.minY), end: CGPoint(x: rect.origin.x, y: rect.minY + gradH), options: [])
                } else {
                    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.origin.x, y: rect.maxY), end: CGPoint(x: rect.origin.x, y: rect.maxY - gradH), options: [])
                }
            }
        }

        ctx.restoreGState()
    }

    public static func drawVintageDateStamp(ctx: CGContext, rect: CGRect, text: String, colorName: String, placement: String) {
        var stamp = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stamp.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "''yy MM dd"
            stamp = df.string(from: Date())
        }

        let textColor: CGColor
        let glowColor: CGColor
        if colorName == "red" {
            textColor = CGColor(srgbRed: 1.0, green: 37/255, blue: 37/255, alpha: 1.0)
            glowColor = CGColor(srgbRed: 1.0, green: 37/255, blue: 37/255, alpha: 0.75)
        } else if colorName == "green" {
            textColor = CGColor(srgbRed: 0.0, green: 230/255, blue: 118/255, alpha: 1.0)
            glowColor = CGColor(srgbRed: 0.0, green: 230/255, blue: 118/255, alpha: 0.75)
        } else if colorName == "white" {
            textColor = CGColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 1.0)
            glowColor = CGColor(srgbRed: 245/255, green: 245/255, blue: 247/255, alpha: 0.75)
        } else {
            textColor = CGColor(srgbRed: 1.0, green: 140/255, blue: 0.0, alpha: 1.0)
            glowColor = CGColor(srgbRed: 1.0, green: 140/255, blue: 0.0, alpha: 0.75)
        }

        let fontSize = max(14.0, rect.width * 0.042)
        let ctFont = CTFontCreateWithName("Courier-Bold" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor
        ]
        let attrStr = NSAttributedString(string: stamp, attributes: attrs)
        let ctLine = CTLineCreateWithAttributedString(attrStr)
        let lineBounds = CTLineGetBoundsWithOptions(ctLine, [])

        let padX = rect.width * 0.04
        let padY = rect.height * 0.04

        var stampX: CGFloat
        var stampY: CGFloat

        switch placement {
        case "bottomLeft":
            stampX = rect.minX + padX
            stampY = rect.minY + padY
        case "topRight":
            stampX = rect.maxX - lineBounds.width - padX
            stampY = rect.maxY - padY - fontSize
        case "topLeft":
            stampX = rect.minX + padX
            stampY = rect.maxY - padY - fontSize
        default:
            stampX = rect.maxX - lineBounds.width - padX
            stampY = rect.minY + padY
        }

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6.0, color: glowColor)
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: stampX, y: stampY)
        CTLineDraw(ctLine, ctx)
        ctx.restoreGState()
    }

    /// Encodes a CGImage into the exact Fujifilm Instax SHARE SP-1 / SP-2 / SP-3 Column-Major Planar RGB format.
    /// Verified bit-for-bit against `instax_api/instaxImage.py`:
    /// - Portrait image (`maxWidth × maxHeight`, e.g. 600×800 on SP-1/SP-2 or 800×800 on SP-3) is rotated 90° clockwise
    ///   so `printWidth = maxHeight (800)` and `printHeight = maxWidth (600 or 800)`.
    /// - Then for each scanline column `w` in `0..<printWidth`:
    ///   `R[0..<printHeight]`, `G[0..<printHeight]`, `B[0..<printHeight]`.
    public static func encodePlanarRGB(
        cgImage: CGImage,
        model: LegacyPrinterModel,
        reportedMaxWidth: Int? = nil,
        reportedMaxHeight: Int? = nil
    ) -> Data {
        let portraitW = reportedMaxWidth ?? model.width
        let portraitH = reportedMaxHeight ?? model.height

        // First ensure image is scaled to portraitW × portraitH if needed
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let baseImage: CGImage
        if cgImage.width != portraitW || cgImage.height != portraitH,
           let scaleCtx = CGContext(
               data: nil,
               width: portraitW,
               height: portraitH,
               bitsPerComponent: 8,
               bytesPerRow: portraitW * 4,
               space: colorSpace,
               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
           ) {
            scaleCtx.interpolationQuality = .high
            scaleCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: portraitW, height: portraitH))
            baseImage = scaleCtx.makeImage() ?? cgImage
        } else {
            baseImage = cgImage
        }

        // Rotate 90° clockwise (`rotate(-90, expand=True)` in PIL) so dimensions become `printWidth = portraitH`, `printHeight = portraitW`
        let rotatedImage = rotateCGImage(baseImage, degrees: 90) ?? baseImage
        let printWidth = portraitH   // 800 scanlines along the print feed direction
        let printHeight = portraitW  // 600 dots (SP-1/SP-2) or 800 dots (SP-3) across the print head

        var rgba = [UInt8](repeating: 255, count: printWidth * printHeight * 4)
        rgba.withUnsafeMutableBytes { ptr in
            if let ctx = CGContext(
                data: ptr.baseAddress,
                width: printWidth,
                height: printHeight,
                bitsPerComponent: 8,
                bytesPerRow: printWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.interpolationQuality = .high
                ctx.draw(rotatedImage, in: CGRect(x: 0, y: 0, width: printWidth, height: printHeight))
            }
        }

        var planar = [UInt8](repeating: 0, count: printWidth * printHeight * 3)
        for h in 0..<printHeight {
            let rowBase = h * printWidth * 4
            for w in 0..<printWidth {
                let pixelIdx = rowBase + w * 4
                let r = rgba[pixelIdx]
                let g = rgba[pixelIdx + 1]
                let b = rgba[pixelIdx + 2]

                let colBase = w * printHeight * 3
                planar[colBase + h] = r
                planar[colBase + printHeight + h] = g
                planar[colBase + (printHeight * 2) + h] = b
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
        case 160: return "Printer Busy / In Use by Another Device (0xA0)"
        case 161: return "Invalid Image Data Format (0xA1)"
        case 162: return "Battery Too Low to Print (0xA2)"
        case 163: return "Printing in Progress (0xA3)"
        case 164: return "Ejecting Film (0xA4)"
        case 180: return "Printer Charging / Voltage Wait (0xB4)"
        case 244: return "Out of Instax Film (0xF4)"
        case 245: return "Cam Point / Mechanism Error (0xF5)"
        case 246: return "Film Motor Jam Error (0xF6)"
        case 247: return "Incorrect Printer PIN Code (0xF7 — Factory Default is 1111)"
        case 248: return "PI Sensor Error (0xF8)"
        default:  return "Status Code \(returnCode) (0x\(String(format: "%02X", returnCode)))"
        }
    }
}

public enum LegacyInstaxPacket {
    public static func buildCommand(
        type: LegacyInstaxCommandType,
        sessionTime: UInt32,
        pinCode: UInt16 = 1111,
        payload: [UInt8] = []
    ) -> Data {
        let totalLength = 16 + payload.count
        var bytes = [UInt8]()
        bytes.reserveCapacity(totalLength)

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

    public static func parseResponse(_ data: Data) -> LegacyInstaxResponse? {
        guard data.count >= 16 else { return nil }
        let bytes = [UInt8](data)
        let mode = bytes[0]
        let cmdType = bytes[1]
        let length = (Int(bytes[2]) << 8) | Int(bytes[3])
        let sessionTime = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
        let returnCode = bytes[12]
        let unknown1 = bytes[13]
        let ejecting = (bytes[14] >> 2) & 0xFF
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
                payload = [0x00, 0xFE, 0x01, 0x13, 0x00, 0x00, 0x00, 0x00]
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
                    0x00, 0x0A,
                    0, 0, 0, 0,
                    UInt8((msgSz >> 8) & 0xFF), UInt8(msgSz & 0xFF),
                    0x10, 0x00,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                ]
            case LegacyInstaxCommandType.prePrint.rawValue:
                let cmdNo = packet.count >= 16 ? packet[15] : 1
                let respNo: UInt8 = (cmdNo <= 3) ? 2 : ((cmdNo <= 5) ? 1 : 0)
                payload = [0x00, cmdNo, 0x00, respNo]
            case LegacyInstaxCommandType.printerLock.rawValue:
                payload = []
            case LegacyInstaxCommandType.reset.rawValue:
                payload = []
            case LegacyInstaxCommandType.prepImage.rawValue:
                let maxLen = UInt16(simulatedModel.segmentSize)
                payload = [0x00, 0x00, UInt8((maxLen >> 8) & 0xFF), UInt8(maxLen & 0xFF)]
            case LegacyInstaxCommandType.sendImage.rawValue:
                let seq = packet.count >= 16 ? packet[15] : 0
                payload = [0, 0, 0, seq]
            case LegacyInstaxCommandType.triggerPrint.rawValue:
                printPollCounter = 2
                if simulatedFilmRemaining > 0 {
                    simulatedFilmRemaining -= 1
                }
                simulatedTotalPrints += 1
                payload = []
            case LegacyInstaxCommandType.lockState.rawValue:
                payload = [0, 0, 0, 100]
            case LegacyInstaxCommandType.printStatus.rawValue:
                if printPollCounter > 0 {
                    printPollCounter -= 1
                    returnCode = 163 // Printing
                } else {
                    returnCode = 0 // Complete
                }
                payload = []
            default:
                payload = []
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

// MARK: - Synchronous POSIX TCP Session Client (With Automatic Retry for Hardware RTOS Sockets)

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

    public func connect(timeoutSeconds: Double = 3.5, retries: Int = 3) throws {
        var lastError: Error?
        for attempt in 0..<max(1, retries) {
            do {
                try connectOnce(timeoutSeconds: timeoutSeconds)
                return
            } catch {
                lastError = error
                if attempt + 1 < retries {
                    Thread.sleep(forTimeInterval: 0.45)
                }
            }
        }
        throw lastError ?? LegacyTCPClientError.connectionFailed("Unable to connect to \(host):\(port).")
    }

    private func connectOnce(timeoutSeconds: Double) throws {
        close()
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw LegacyTCPClientError.connectionFailed("Unable to create TCP socket.")
        }

        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

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
            throw LegacyTCPClientError.connectionFailed("Cannot reach \(host):\(port). Select your printer's INSTAX-XXXXXXXX Wi-Fi from the dropdown first (or enable Virtual Simulator).")
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
                throw LegacyTCPClientError.connectionFailed("Connection timed out to \(host):\(port). Join your printer's INSTAX-XXXXXXXX Wi-Fi network first.")
            }

            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
            if soError != 0 {
                Darwin.close(fd)
                throw LegacyTCPClientError.connectionFailed("Connection refused by \(host):\(port) (errno \(soError)).")
            }
        }

        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        var rcvTimeout = timeval(tv_sec: 8, tv_usec: 0)
        var sndTimeout = timeval(tv_sec: 8, tv_usec: 0)
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

// MARK: - High-Level Printer Manager (Real Telemetry + Wi-Fi & Subnet Discovery)

public struct LegacyPrinterTelemetry {
    public var modelName: String? = nil
    public var firmwareVersion: String? = nil
    public var batteryLevel: Int? = nil       // nil when disconnected; 0..4 when connected
    public var filmRemaining: Int? = nil      // nil when disconnected; 0..10 when connected
    public var totalPrintHistory: Int? = nil  // nil when disconnected
    public var maxWidth: Int = 600
    public var maxHeight: Int = 800
    public var maxMsgSize: Int = 60000
}

public final class LegacyPrinterManager: ObservableObject {
    @Published public var printerIP: String = "192.168.0.251"
    @Published public var printerPort: String = "8080"
    @Published public var pinCode: String = "1111"
    @Published public var wifiPassword: String = "1111"

    @Published public var discoveryItems: [LegacyWiFiDiscoveryItem] = []
    @Published public var selectedDiscoveryID: String = "default-192.168.0.251"
    @Published public var isScanningWiFi: Bool = false

    @Published public var useVirtualSimulator: Bool = false {
        didSet {
            if useVirtualSimulator {
                _ = LegacyVirtualPrinterServer.shared.start(port: 18080)
                printerIP = "127.0.0.1"
                printerPort = "18080"
                selectedDiscoveryID = "virtual-sim"
                appendLog("🟢 Built-in Virtual Instax SHARE Simulator started at 127.0.0.1:18080")
                queryPrinterStatus()
            } else {
                printerIP = "192.168.0.251"
                printerPort = "8080"
                selectedDiscoveryID = "default-192.168.0.251"
                isConnected = false
                telemetry = LegacyPrinterTelemetry()
                statusHeadline = "Not Connected — Scan or select INSTAX Wi-Fi from dropdown"
                appendLog("📡 Switched target to physical Instax SHARE Wi-Fi Direct (192.168.0.251:8080)")
            }
        }
    }
    @Published public var dryRunMode: Bool = false

    @Published public var isConnected: Bool = false
    @Published public var isBusy: Bool = false
    @Published public var statusHeadline: String = "Not Connected — Scan or select INSTAX Wi-Fi from dropdown"
    @Published public var progressValue: Double = 0.0
    @Published public var telemetry = LegacyPrinterTelemetry()
    @Published public var detectedWiFiSSID: String = "Scanning Wi-Fi..."
    @Published public var logs: [String] = []

    public init() {
        scanWiFiAndPrinters(autoConnectIfFound: false)
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

    /// Scans nearby Wi-Fi SSIDs via CoreWLAN + checks local subnet for active Instax SHARE TCP endpoints on port 8080.
    public func scanWiFiAndPrinters(autoConnectIfFound: Bool = false, onModelDetected: ((LegacyPrinterModel) -> Void)? = nil) {
        guard !isScanningWiFi else { return }
        isScanningWiFi = true
        appendLog("📡 Scanning nearby Wi-Fi networks & local subnet for Instax SHARE printers...")

        DispatchQueue.global(qos: .userInitiated).async {
            var items: [LegacyWiFiDiscoveryItem] = []
            var seenIDs = Set<String>()

            func addItem(_ item: LegacyWiFiDiscoveryItem) {
                guard !seenIDs.contains(item.id) else { return }
                seenIDs.insert(item.id)
                items.append(item)
            }

            // 1. Check current Wi-Fi interface & scan nearby SSIDs via CoreWLAN
            var currentSSID: String? = nil
            if let iface = CWWiFiClient.shared().interface() {
                currentSSID = iface.ssid()
                if let ssid = currentSSID, !ssid.isEmpty {
                    let isInstax = ssid.uppercased().contains("INSTAX")
                    addItem(LegacyWiFiDiscoveryItem(
                        id: "ssid-\(ssid)",
                        title: isInstax ? "📶 Connected INSTAX Wi-Fi: \(ssid) (192.168.0.251)" : "📶 Current Wi-Fi: \(ssid)",
                        ssid: ssid,
                        host: "192.168.0.251",
                        port: 8080,
                        kind: isInstax ? .instaxWiFiSSID : .currentWiFiSSID
                    ))
                }

                if let networks = try? iface.scanForNetworks(withName: nil) {
                    let sorted = networks.sorted { ($0.ssid ?? "") < ($1.ssid ?? "") }
                    for net in sorted {
                        guard let ssid = net.ssid, !ssid.isEmpty else { continue }
                        if ssid.uppercased().contains("INSTAX") {
                            addItem(LegacyWiFiDiscoveryItem(
                                id: "ssid-\(ssid)",
                                title: "📸 Join Printer Wi-Fi: \(ssid) (RSSI \(net.rssiValue) dBm)",
                                ssid: ssid,
                                host: "192.168.0.251",
                                port: 8080,
                                kind: .instaxWiFiSSID
                            ))
                        }
                    }
                    for net in sorted {
                        guard let ssid = net.ssid, !ssid.isEmpty, !ssid.uppercased().contains("INSTAX") else { continue }
                        addItem(LegacyWiFiDiscoveryItem(
                            id: "ssid-\(ssid)",
                            title: "Wi-Fi Network: \(ssid)",
                            ssid: ssid,
                            host: "192.168.0.251",
                            port: 8080,
                            kind: .currentWiFiSSID
                        ))
                    }
                }
            }

            // 2. Check local IPv4 subnet & probe candidate Instax SHARE IPs on TCP port 8080
            var candidateIPs = ["192.168.0.251", "192.168.0.1"]
            var localInstaxIP: String? = nil

            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0, let first = ifaddr {
                var ptr: UnsafeMutablePointer<ifaddrs>? = first
                while let cur = ptr {
                    if let addr = cur.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(cString: hostname)
                            if ip.hasPrefix("192.168.0.") {
                                localInstaxIP = ip
                            } else if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") {
                                let parts = ip.split(separator: ".")
                                if parts.count == 4 {
                                    let prefix = "\(parts[0]).\(parts[1]).\(parts[2])"
                                    if !candidateIPs.contains("\(prefix).251") { candidateIPs.append("\(prefix).251") }
                                    if !candidateIPs.contains("\(prefix).1") { candidateIPs.append("\(prefix).1") }
                                }
                            }
                        }
                    }
                    ptr = cur.pointee.ifa_next
                }
                freeifaddrs(ifaddr)
            }

            var reachableEndpoint: LegacyWiFiDiscoveryItem? = nil
            for ip in candidateIPs {
                if Self.quickProbeTCP(host: ip, port: 8080, timeoutSeconds: 0.45) {
                    let item = LegacyWiFiDiscoveryItem(
                        id: "live-\(ip):8080",
                        title: "🟢 Discovered Instax SHARE Printer (\(ip):8080)",
                        ssid: nil,
                        host: ip,
                        port: 8080,
                        kind: .reachablePrinterEndpoint
                    )
                    addItem(item)
                    if reachableEndpoint == nil { reachableEndpoint = item }
                }
            }

            // 3. Always include the factory default endpoint and Virtual Simulator option
            addItem(LegacyWiFiDiscoveryItem(
                id: "default-192.168.0.251",
                title: "🎯 Instax SHARE Default (192.168.0.251:8080)",
                ssid: nil,
                host: "192.168.0.251",
                port: 8080,
                kind: .defaultPrinterEndpoint
            ))

            addItem(LegacyWiFiDiscoveryItem(
                id: "virtual-sim",
                title: "🧪 Virtual SP-1/2/3 Simulator (127.0.0.1:18080)",
                ssid: nil,
                host: "127.0.0.1",
                port: 18080,
                kind: .virtualSimulator
            ))

            DispatchQueue.main.async {
                self.discoveryItems = items
                self.isScanningWiFi = false

                if self.useVirtualSimulator {
                    self.detectedWiFiSSID = "Virtual SP Simulator (127.0.0.1:18080)"
                } else if let ssid = currentSSID, !ssid.isEmpty {
                    self.detectedWiFiSSID = "Wi-Fi: \(ssid)"
                } else if let lip = localInstaxIP {
                    self.detectedWiFiSSID = "On Instax Subnet (\(lip))"
                } else {
                    self.detectedWiFiSSID = "Select INSTAX-XXXXXXXX from Wi-Fi dropdown"
                }

                if let found = reachableEndpoint {
                    self.selectedDiscoveryID = found.id
                    self.printerIP = found.host
                    self.printerPort = String(found.port)
                    self.appendLog("🟢 Found live Instax SHARE TCP endpoint at \(found.host):\(found.port)!")
                    if autoConnectIfFound {
                        self.queryPrinterStatus(onModelDetected: onModelDetected)
                    }
                } else {
                    self.appendLog("📡 Scan complete (\(items.count) options in dropdown).")
                }
            }
        }
    }

    /// Handles user selecting an item from the Wi-Fi / Printer discovery dropdown.
    public func applyDiscoverySelection(_ itemID: String, onModelDetected: ((LegacyPrinterModel) -> Void)? = nil) {
        selectedDiscoveryID = itemID
        guard let item = discoveryItems.first(where: { $0.id == itemID }) else { return }

        switch item.kind {
        case .virtualSimulator:
            if !useVirtualSimulator {
                useVirtualSimulator = true
            } else {
                queryPrinterStatus(onModelDetected: onModelDetected)
            }
        case .instaxWiFiSSID, .currentWiFiSSID:
            if useVirtualSimulator { useVirtualSimulator = false }
            printerIP = item.host
            printerPort = String(item.port)
            if let targetSSID = item.ssid {
                joinWiFiAndConnect(ssid: targetSSID, onModelDetected: onModelDetected)
            }
        case .reachablePrinterEndpoint, .defaultPrinterEndpoint:
            if useVirtualSimulator { useVirtualSimulator = false }
            printerIP = item.host
            printerPort = String(item.port)
            queryPrinterStatus(onModelDetected: onModelDetected)
        }
    }

    /// Joins a selected `INSTAX-XXXXXXXX` Wi-Fi network using CoreWLAN and then connects to the printer.
    public func joinWiFiAndConnect(ssid: String, onModelDetected: ((LegacyPrinterModel) -> Void)? = nil) {
        appendLog("📶 Attempting to join Wi-Fi network '\(ssid)'...")
        statusHeadline = "Joining Wi-Fi '\(ssid)'..."

        DispatchQueue.global(qos: .userInitiated).async {
            var joined = false
            if let iface = CWWiFiClient.shared().interface() {
                if iface.ssid() == ssid {
                    joined = true
                } else if let nets = try? iface.scanForNetworks(withName: ssid), let net = nets.first {
                    let pass = self.wifiPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    do {
                        try iface.associate(to: net, password: pass.isEmpty ? nil : pass)
                        joined = true
                    } catch {
                        // Try open association if password wasn't required
                        try? iface.associate(to: net, password: nil)
                        joined = (iface.ssid() == ssid)
                    }
                }
            }

            DispatchQueue.main.async {
                if joined {
                    self.detectedWiFiSSID = "Wi-Fi: \(ssid)"
                    self.appendLog("✅ Joined Wi-Fi '\(ssid)'. Querying printer at \(self.printerIP):\(self.printerPort)...")
                    self.queryPrinterStatus(onModelDetected: onModelDetected)
                } else {
                    self.appendLog("ℹ️ Could not auto-associate to '\(ssid)'. Opening macOS Wi-Fi Settings so you can click '\(ssid)'...")
                    self.openSystemWiFiSettings()
                }
            }
        }
    }

    public func openSystemWiFiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func quickProbeTCP(host: String, port: UInt16, timeoutSeconds: Double) -> Bool {
        let s = LegacyTCPSession(host: host, port: port, pinCode: 1111, sessionTime: 12345)
        do {
            try s.connect(timeoutSeconds: timeoutSeconds, retries: 1)
            s.close()
            return true
        } catch {
            return false
        }
    }

    /// Queries the printer's Version (0xC0), Model Name (0xC2), Specifications (0x4F), and Print Count (0xC1)
    /// in the exact order used by `instax_api` (`sp2.py` / `sp3.py`).
    public func queryPrinterStatus(
        onModelDetected: ((LegacyPrinterModel) -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isBusy else {
            completion?(false)
            return
        }
        isBusy = true

        let host = printerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = UInt16(printerPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8080
        let pin = UInt16(pinCode.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1111
        let sessionTime = UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 * 1000))

        appendLog("🔍 Connecting to \(host):\(port) (PIN: \(pin))...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                try session.connect(timeoutSeconds: 3.5, retries: 2)
                defer { session.close() }

                // 1. Version (0xC0)
                let verResp = try session.sendAndReceive(type: .version)
                if !verResp.isOK {
                    throw LegacyTCPClientError.printerError(verResp.returnCodeDescription)
                }
                var fwString = "v1.0"
                if verResp.payload.count >= 4 {
                    let fwHi = verResp.payload[2]
                    let fwLo = verResp.payload[3]
                    fwString = String(format: "%02X.%02X", fwHi, fwLo)
                }

                // 2. Model Name (0xC2)
                let modelResp = try session.sendAndReceive(type: .modelName)
                if !modelResp.isOK {
                    throw LegacyTCPClientError.printerError(modelResp.returnCodeDescription)
                }
                let rawName = String(data: modelResp.payload, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines)) ?? "SP-2"

                // 3. Specifications (0x4F)
                let specResp = try session.sendAndReceive(type: .specifications)
                var maxW = 600
                var maxH = 800
                var maxMsgSz = 60000
                if specResp.payload.count >= 4 {
                    maxW = (Int(specResp.payload[0]) << 8) | Int(specResp.payload[1])
                    maxH = (Int(specResp.payload[2]) << 8) | Int(specResp.payload[3])
                }
                if specResp.payload.count >= 14 {
                    let reportedSeg = (Int(specResp.payload[12]) << 8) | Int(specResp.payload[13])
                    if reportedSeg > 0 { maxMsgSz = reportedSeg }
                }

                // 4. Print Count (0xC1)
                let countResp = try session.sendAndReceive(type: .printCount)
                var totalPrints = 0
                if countResp.payload.count >= 4 {
                    totalPrints = (Int(countResp.payload[0]) << 24)
                        | (Int(countResp.payload[1]) << 16)
                        | (Int(countResp.payload[2]) << 8)
                        | Int(countResp.payload[3])
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
                        batteryLevel: verResp.batteryLevel,
                        filmRemaining: verResp.filmRemaining,
                        totalPrintHistory: totalPrints,
                        maxWidth: maxW,
                        maxHeight: maxH,
                        maxMsgSize: maxMsgSz
                    )
                    self.isConnected = true
                    self.isBusy = false
                    self.statusHeadline = "Connected to \(rawName) • \(verResp.filmRemaining)/10 Film Left • Battery \(verResp.batteryLevel)/4"
                    self.appendLog("✅ Connected: \(rawName) (FW \(fwString)) | Specs: \(maxW)×\(maxH) (Seg \(maxMsgSz)B) | Film: \(verResp.filmRemaining)/10 | Battery: \(verResp.batteryLevel)/4 | Total Prints: \(totalPrints)")
                    onModelDetected?(detectedModel)
                    completion?(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.telemetry = LegacyPrinterTelemetry()
                    self.isBusy = false
                    self.statusHeadline = error.localizedDescription
                    self.appendLog("❌ Connection Error: \(error.localizedDescription)")
                    completion?(false)
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
        let isLocalhost = (host == "127.0.0.1" || host == "localhost")
        let interSessionDelay: TimeInterval = isLocalhost ? 0.15 : 0.90
        let sessionTime = UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 * 1000))

        appendLog(isDryRun
            ? "🧪 Starting DRY RUN (0-Film Test) for \(model.displayName) to \(host):\(port)..."
            : "🖨️ Starting Wi-Fi Direct Print for \(model.displayName) to \(host):\(port)...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Step 0: Query live Specifications (0x4F) so SP-1 / SP-2 / SP-3 hardware dimensions & segment size are 100% matched
                var hwWidth = model.width
                var hwHeight = model.height
                var segmentSize = model.segmentSize

                do {
                    let s0 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s0.connect(timeoutSeconds: 3.5, retries: 3)
                    defer { s0.close() }
                    let specResp = try s0.sendAndReceive(type: .specifications)
                    if !specResp.isOK {
                        throw LegacyTCPClientError.printerError("Specifications query failed: \(specResp.returnCodeDescription)")
                    }
                    if specResp.payload.count >= 4 {
                        let w = (Int(specResp.payload[0]) << 8) | Int(specResp.payload[1])
                        let h = (Int(specResp.payload[2]) << 8) | Int(specResp.payload[3])
                        if w >= 320 && h >= 320 {
                            hwWidth = w
                            hwHeight = h
                        }
                    }
                    if specResp.payload.count >= 14 {
                        let seg = (Int(specResp.payload[12]) << 8) | Int(specResp.payload[13])
                        if seg >= 1024 {
                            segmentSize = seg
                        }
                    }
                    DispatchQueue.main.async {
                        self.telemetry.batteryLevel = specResp.batteryLevel
                        self.telemetry.filmRemaining = specResp.filmRemaining
                        self.isConnected = true
                    }
                }
                Thread.sleep(forTimeInterval: interSessionDelay)

                // Encode Column-Major Planar RGB with 90° clockwise scanline orientation matching `instaxImage.py`
                let planarData = LegacyImageProcessor.encodePlanarRGB(
                    cgImage: cgImage,
                    model: model,
                    reportedMaxWidth: hwWidth,
                    reportedMaxHeight: hwHeight
                )
                let totalBytes = planarData.count
                let numSegments = max(1, (totalBytes + segmentSize - 1) / segmentSize)

                self.appendLog("📐 Encoded Planar RGB (\(hwHeight)×\(hwWidth) rotated scanlines): \(totalBytes) bytes (\(numSegments) segments × \(segmentSize) B)")

                // PHASE 1: Pre-Print Commands 1..8
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 1/5: Negotiating Pre-Print Handshake (1..8)..."
                    self.progressValue = 0.10
                }
                do {
                    let s1 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s1.connect(timeoutSeconds: 4.0, retries: 3)
                    defer { s1.close() }
                    for cmdNum in 1...8 {
                        let resp = try s1.sendAndReceive(type: .prePrint, payload: [0x00, 0x00, 0x00, UInt8(cmdNum)])
                        if !resp.isOK {
                            throw LegacyTCPClientError.printerError("PrePrint[\(cmdNum)] rejected: \(resp.returnCodeDescription)")
                        }
                    }
                }
                self.appendLog("✓ Phase 1 complete: PrePrint 1..8 acknowledged.")
                Thread.sleep(forTimeInterval: interSessionDelay)

                // PHASE 2: Lock Printer
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 2/5: Locking Instax SHARE Print Engine..."
                    self.progressValue = 0.18
                }
                do {
                    let s2 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s2.connect(timeoutSeconds: 4.0, retries: 3)
                    defer { s2.close() }
                    let resp = try s2.sendAndReceive(type: .printerLock, payload: [0x01, 0x00, 0x00, 0x00])
                    if !resp.isOK {
                        throw LegacyTCPClientError.printerError("Lock Printer rejected: \(resp.returnCodeDescription)")
                    }
                }
                self.appendLog("✓ Phase 2 complete: Printer locked for exclusive transfer.")
                Thread.sleep(forTimeInterval: interSessionDelay)

                // PHASE 3: Reset Printer Buffer
                DispatchQueue.main.async {
                    self.statusHeadline = "Phase 3/5: Resetting Printer Image Buffer..."
                    self.progressValue = 0.25
                }
                do {
                    let s3 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s3.connect(timeoutSeconds: 4.0, retries: 3)
                    defer { s3.close() }
                    let resp = try s3.sendAndReceive(type: .reset)
                    if !resp.isOK {
                        throw LegacyTCPClientError.printerError("Reset Buffer rejected: \(resp.returnCodeDescription)")
                    }
                }
                self.appendLog("✓ Phase 3 complete: Printer buffer cleared.")
                Thread.sleep(forTimeInterval: interSessionDelay)

                // PHASE 4: PrepImage + SendImage Segments (0..<numSegments) + TriggerPrint
                do {
                    let s4 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s4.connect(timeoutSeconds: 4.0, retries: 3)
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
                        let end = min(allBytes.count, start + segmentSize)
                        var segPayload = [UInt8]()
                        segPayload.reserveCapacity(4 + (end - start))
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

                        let frac = 0.28 + (Double(seg + 1) / Double(numSegments)) * 0.58
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
                Thread.sleep(forTimeInterval: interSessionDelay)

                // PHASE 5: Final Status Poll (or Dry Run Buffer Reset)
                if isDryRun {
                    let s5 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s5.connect(timeoutSeconds: 4.0, retries: 3)
                    defer { s5.close() }
                    _ = try? s5.sendAndReceive(type: .reset)
                    let finalInfo = try s5.sendAndReceive(type: .modelName)
                    DispatchQueue.main.async {
                        self.telemetry.batteryLevel = finalInfo.batteryLevel
                        self.telemetry.filmRemaining = finalInfo.filmRemaining
                        self.progressValue = 1.0
                        self.isBusy = false
                        self.isConnected = true
                        self.statusHeadline = "✅ Dry Run Passed! 100% of \(totalBytes / 1000) KB Verified (0 Film Used • \(finalInfo.filmRemaining)/10 Left)"
                        self.appendLog("🎉 DRY RUN COMPLETE: Connection, PIN, and \(numSegments) segments verified with 0 film used.")
                        completion?(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusHeadline = "Phase 5/5: Developing & Ejecting Instax Film..."
                        self.progressValue = 0.90
                    }
                    let s5 = LegacyTCPSession(host: host, port: port, pinCode: pin, sessionTime: sessionTime)
                    try s5.connect(timeoutSeconds: 4.0, retries: 3)
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
                        Thread.sleep(forTimeInterval: 0.8)
                    }

                    DispatchQueue.main.async {
                        self.telemetry.filmRemaining = finalFilm
                        self.telemetry.batteryLevel = finalBatt
                        self.telemetry.totalPrintHistory = (self.telemetry.totalPrintHistory ?? 0) + 1
                        self.progressValue = 1.0
                        self.isBusy = false
                        self.isConnected = true
                        self.statusHeadline = "✅ Print Complete! (\(finalFilm)/10 Film Remaining • Battery \(finalBatt)/4)"
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
