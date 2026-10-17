import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func drawLegacyIconPNG(size: Int, outputURL: URL) {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // 1. Rounded macOS Squircle Background (Warm Vintage Charcoal & Bronze Gradient)
    let pad = s * 0.08
    let bgRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let corner = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.18, green: 0.16, blue: 0.15, alpha: 1.0),
        CGColor(red: 0.09, green: 0.08, blue: 0.08, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: s / 2, y: s - pad), end: CGPoint(x: s / 2, y: pad), options: [])
    }

    // Subtle champagne gold rim border
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.72, blue: 0.48, alpha: 0.45))
    ctx.setLineWidth(s * 0.015)
    ctx.addPath(bgPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 2. Emerging Instant Film Frame at Top
    let filmW = s * 0.44
    let filmH = s * 0.38
    let filmX = (s - filmW) / 2.0
    let filmY = s * 0.48
    let filmRect = CGRect(x: filmX, y: filmY, width: filmW, height: filmH)
    let filmPath = CGPath(roundedRect: filmRect, cornerWidth: s * 0.025, cornerHeight: s * 0.025, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    ctx.setFillColor(CGColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1.0))
    ctx.addPath(filmPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Inner photo inside film (Warm Sunset / Retro Gradient)
    let innerPad = s * 0.032
    let photoRect = CGRect(
        x: filmX + innerPad,
        y: filmY + innerPad * 2.1,
        width: filmW - innerPad * 2,
        height: filmH - innerPad * 3.0
    )
    ctx.saveGState()
    ctx.addRect(photoRect)
    ctx.clip()
    let photoColors = [
        CGColor(red: 0.95, green: 0.48, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.85, green: 0.24, blue: 0.42, alpha: 1.0),
        CGColor(red: 0.25, green: 0.18, blue: 0.48, alpha: 1.0)
    ] as CFArray
    if let pGrad = CGGradient(colorsSpace: colorSpace, colors: photoColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(pGrad, start: CGPoint(x: photoRect.midX, y: photoRect.maxY), end: CGPoint(x: photoRect.midX, y: photoRect.minY), options: [])
    }
    ctx.restoreGState()

    // 3. Instax SHARE SP-2 / SP-3 Angular Geometric Printer Body (Champagne Gold / Silver Metallic)
    let bodyW = s * 0.62
    let bodyH = s * 0.40
    let bodyX = (s - bodyW) / 2.0
    let bodyY = s * 0.15
    let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: s * 0.055, cornerHeight: s * 0.055, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.05, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
    ctx.addPath(bodyPath)
    ctx.clip()

    let bodyColors = [
        CGColor(red: 0.92, green: 0.85, blue: 0.72, alpha: 1.0),
        CGColor(red: 0.78, green: 0.68, blue: 0.52, alpha: 1.0)
    ] as CFArray
    if let bGrad = CGGradient(colorsSpace: colorSpace, colors: bodyColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bGrad, start: CGPoint(x: bodyX, y: bodyY + bodyH), end: CGPoint(x: bodyX + bodyW, y: bodyY), options: [])
    }

    // Geometric facet lines characteristic of SP-2 / SP-3
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 0.45))
    ctx.setLineWidth(s * 0.008)
    ctx.move(to: CGPoint(x: bodyX, y: bodyY + bodyH))
    ctx.addLine(to: CGPoint(x: s * 0.5, y: bodyY + bodyH * 0.52))
    ctx.addLine(to: CGPoint(x: bodyX + bodyW, y: bodyY + bodyH))
    ctx.strokePath()
    ctx.restoreGState()

    // Top Ejection Slot
    let slotW = filmW + s * 0.04
    let slotH = s * 0.022
    let slotRect = CGRect(x: (s - slotW) / 2.0, y: bodyY + bodyH - slotH * 0.8, width: slotW, height: slotH)
    ctx.setFillColor(CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1.0))
    ctx.fill(slotRect)

    // 10 Green Film Counter LED Dots across the SP-2/SP-3 front
    let ledCount = 10
    let ledSpacing = (bodyW * 0.72) / CGFloat(ledCount - 1)
    let ledStartX = (s - (bodyW * 0.72)) / 2.0
    let ledY = bodyY + bodyH * 0.76
    let ledR = s * 0.009
    for i in 0..<ledCount {
        let lx = ledStartX + CGFloat(i) * ledSpacing - ledR
        let dotRect = CGRect(x: lx, y: ledY - ledR, width: ledR * 2, height: ledR * 2)
        ctx.setFillColor(CGColor(red: 0.20, green: 0.92, blue: 0.45, alpha: 1.0))
        ctx.fillEllipse(in: dotRect)
    }

    // 4. Wi-Fi Direct Emblem in Center of Printer Body
    let wifiCenter = CGPoint(x: s * 0.5, y: bodyY + bodyH * 0.30)
    let badgeR = s * 0.095
    let badgeRect = CGRect(x: wifiCenter.x - badgeR, y: wifiCenter.y - badgeR, width: badgeR * 2, height: badgeR * 2)
    ctx.setFillColor(CGColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 0.92))
    ctx.fillEllipse(in: badgeRect)

    // Wi-Fi arcs
    ctx.setStrokeColor(CGColor(red: 0.35, green: 0.78, blue: 1.0, alpha: 1.0))
    ctx.setLineWidth(s * 0.014)
    ctx.setLineCap(.round)
    let arcBaseY = wifiCenter.y - badgeR * 0.38
    for idx in 1...3 {
        let r = CGFloat(idx) * (badgeR * 0.36)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: wifiCenter.x, y: arcBaseY), radius: r, startAngle: .pi * 0.25, endAngle: .pi * 0.75, clockwise: false)
        ctx.strokePath()
    }
    let wifiDotR = s * 0.012
    ctx.setFillColor(CGColor(red: 0.35, green: 0.78, blue: 1.0, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: wifiCenter.x - wifiDotR, y: arcBaseY - wifiDotR, width: wifiDotR * 2, height: wifiDotR * 2))

    if let cgImage = ctx.makeImage(),
       let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
    }
}

let iconsetDir = "/Users/michaelfitzgerald/.gemini/antigravity/scratch/legacy-instax-printer/Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes = [16, 32, 128, 256, 512]
for sz in sizes {
    drawLegacyIconPNG(size: sz, outputURL: URL(fileURLWithPath: "\(iconsetDir)/icon_\(sz)x\(sz).png"))
    drawLegacyIconPNG(size: sz * 2, outputURL: URL(fileURLWithPath: "\(iconsetDir)/icon_\(sz)x\(sz)@2x.png"))
}
print("Iconset generated successfully.")
