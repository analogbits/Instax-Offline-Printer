import SwiftUI
import AppKit
import PhotosUI
import UniformTypeIdentifiers
import Combine

@main
struct LegacyInstaxPrinterApp: App {
    @NSApplicationDelegateAdaptor(LegacyAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Legacy Instax Printer — Wi-Fi Direct Studio (SP-1 • SP-2 • SP-3)") {
            LegacyMainStudioView()
                .frame(minWidth: 1040, idealWidth: 1240, maxWidth: .infinity, minHeight: 680, idealHeight: 840, maxHeight: .infinity)
        }
        .windowStyle(.titleBar)
    }
}

final class LegacyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum LegacyInspectorTab: String, CaseIterable, Identifiable {
    case framing = "Framing"
    case filters = "Filters"
    case analogFX = "Analog FX"
    case collage = "Collage"
    case decorate = "Stickers & Borders"
    case qrAndText = "QR & Text"

    var id: String { rawValue }

    var tabLabel: String {
        switch self {
        case .framing: return "Framing"
        case .filters: return "Filters"
        case .analogFX: return "Analog"
        case .collage: return "Collage"
        case .decorate: return "Stickers"
        case .qrAndText: return "QR/Text"
        }
    }
}

enum CanvasDragMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case photo = "Photo"
    case sticker = "Sticker"
    case banner = "Banner"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto 🎯"
        case .photo: return "Photo 🖼️"
        case .sticker: return "Sticker 🎨"
        case .banner: return "Banner 🎀"
        }
    }
}

final class LegacyStudioViewModel: ObservableObject {
    @Published var options = LegacyPrintOptions()
    @Published var selectedTab: LegacyInspectorTab = .framing
    @Published var primaryImage: NSImage? = nil
    @Published var printQueue: [NSImage] = []
    @Published var previewImage: NSImage? = nil
    @Published var renderedCGImage: CGImage? = nil
    @Published var photoPickerItems: [PhotosPickerItem] = []
    @Published var collagePickerItems: [PhotosPickerItem] = []
    @Published var showProtocolConsole: Bool = false
    @Published var showNetworkDiagnosticsSheet: Bool = false

    @Published var canvasDragMode: CanvasDragMode = .auto
    var activeDragTarget: CanvasDragMode = .photo
    var dragStartOffset: CGSize = .zero
    var stickerStartOffset: CGSize = .zero
    var bannerStartOffset: CGSize = .zero
    var isDraggingCanvas: Bool = false

    func effectiveStickerNormalizedPosition() -> (x: Double, y: Double) {
        if options.stickerPosition == "custom" {
            return (options.stickerX, options.stickerY)
        }
        switch options.stickerPosition {
        case "topLeft": return (-0.68, -0.68)
        case "topRight": return (0.68, -0.68)
        case "bottomLeft": return (-0.68, 0.68)
        case "bottomRight": return (0.68, 0.68)
        case "center": return (0.0, 0.0)
        case "topCenter": return (0.0, -0.68)
        case "bottomCenter": return (0.0, 0.68)
        default: return (options.stickerX, options.stickerY)
        }
    }

    init() {
        primaryImage = Self.makeSampleTestCard(for: .sp2)
        refreshPreview()
    }

    func validateCollageLayout() {
        let total = 1 + options.collageImages.count
        if total <= 1 {
            options.collageLayout = .single
        } else if options.collageLayout.slotCount < total {
            switch total {
            case 2: options.collageLayout = .splitVertical
            case 3: options.collageLayout = .grid3
            case 4: options.collageLayout = .grid4
            default: options.collageLayout = .grid6
            }
        }
    }

    func refreshPreview() {
        if let result = LegacyImageProcessor.renderPreviewAndCGImage(primaryImage: primaryImage, options: options) {
            previewImage = result.nsImage
            renderedCGImage = result.cgImage
        }
    }

    @Published var filmPreset: String = "default"

    func applyFilmPreset(_ id: String) {
        filmPreset = id
        guard id != "none", !id.hasPrefix("header_"), let preset = LegacyFilmCatalog.presets.first(where: { $0.id == id }) else {
            return
        }
        options.filter = preset.filter
        options.brightness = preset.brightness
        options.contrast = preset.contrast
        options.saturation = preset.saturation
        options.warmth = preset.warmth
        options.vignette = preset.vignette
        options.lightLeak = preset.lightLeak
        if preset.lightLeak != "none" {
            options.leakPlacement = preset.leakPlacement
            options.leakIntensity = preset.leakIntensity
        }
        options.filmGrain = preset.filmGrain
        options.analogWear = preset.analogWear
        options.showVintageDate = preset.showVintageDate
        if preset.showVintageDate {
            options.vintageDateColor = preset.vintageDateColor
            options.vintageDatePlacement = preset.vintageDatePlacement
        }
        refreshPreview()
    }

    func resetAnalogFX() {
        filmPreset = "default"
        options.warmth = 0.0
        options.vignette = 0.0
        options.lightLeak = "none"
        options.leakPlacement = "auto"
        options.leakIntensity = 0.70
        options.filmGrain = 0.0
        options.analogWear = 0.0
        options.showVintageDate = false
        options.vintageDateText = ""
        options.vintageDateColor = "amber"
        options.vintageDatePlacement = "bottomRight"
        refreshPreview()
    }

    @Published var currentAutoLeakPlacement: String = "right"

    func rollAutoLeakPlacement() {
        let placements = ["left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]
        let candidates = placements.filter { $0 != currentAutoLeakPlacement }
        currentAutoLeakPlacement = candidates.randomElement() ?? "left"
        options.analogSeed = Int.random(in: 1...1_000_000)
        options.leakPlacement = "auto"
        refreshPreview()
    }

    func leakPlacementTitle(_ key: String) -> String {
        switch key {
        case "left": return "Left Edge"
        case "right": return "Right Edge"
        case "topRight": return "Top Right"
        case "topLeft": return "Top Left"
        case "bottomLeft": return "Bottom Left"
        case "bottomRight": return "Bottom Right"
        case "diagonal": return "Diagonal"
        default: return key
        }
    }

    func surpriseMeAnalogFX() {
        options.warmth = Double(Int.random(in: -30...60)) / 100.0
        options.vignette = Double(Int.random(in: 25...75)) / 100.0
        let leaks = ["none", "burn", "sunburst", "sunset", "rainbow"]
        options.lightLeak = leaks.randomElement() ?? "burn"
        let placements = ["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]
        options.leakPlacement = placements.randomElement() ?? "auto"
        options.leakIntensity = Double(Int.random(in: 45...90)) / 100.0
        options.filmGrain = Double(Int.random(in: 15...55)) / 100.0
        options.analogWear = Double(Int.random(in: 10...45)) / 100.0
        options.showVintageDate = true
        let colors = ["amber", "red", "green", "white"]
        options.vintageDateColor = colors.randomElement() ?? "amber"
        let datePlacements = ["bottomRight", "bottomLeft", "topRight", "topLeft"]
        options.vintageDatePlacement = datePlacements.randomElement() ?? "bottomRight"
        refreshPreview()
    }

    static func makeSampleTestCard(for model: LegacyPrinterModel) -> NSImage {
        let w = model.width
        let h = model.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(size: NSSize(width: w, height: h))
        }

        let colors = [
            CGColor(red: 0.14, green: 0.22, blue: 0.38, alpha: 1.0),
            CGColor(red: 0.85, green: 0.42, blue: 0.28, alpha: 1.0),
            CGColor(red: 0.96, green: 0.78, blue: 0.42, alpha: 1.0)
        ] as CFArray
        if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: CGFloat(w), y: 0), options: [])
        }

        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
        ctx.setLineWidth(3)
        let minDim = CGFloat(min(w, h))
        ctx.strokeEllipse(in: CGRect(
            x: (CGFloat(w) - minDim * 0.65) / 2,
            y: (CGFloat(h) - minDim * 0.65) / 2,
            width: minDim * 0.65,
            height: minDim * 0.65
        ))

        let nsGraphics = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphics
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 0.9),
            .paragraphStyle: style
        ]
        ("INSTAX SHARE \(model.rawValue)" as NSString).draw(
            in: CGRect(x: 20, y: CGFloat(h) * 0.52, width: CGFloat(w - 40), height: 50),
            withAttributes: titleAttrs
        )
        ("Wi-Fi Direct • \(w)×\(h) Planar RGB" as NSString).draw(
            in: CGRect(x: 20, y: CGFloat(h) * 0.44, width: CGFloat(w - 40), height: 32),
            withAttributes: subAttrs
        )
        NSGraphicsContext.restoreGraphicsState()

        if let cg = ctx.makeImage() {
            return NSImage(cgImage: cg, size: NSSize(width: w, height: h))
        }
        return NSImage(size: NSSize(width: w, height: h))
    }
}

struct LegacyMainStudioView: View {
    @StateObject private var printer = LegacyPrinterManager()
    @StateObject private var vm = LegacyStudioViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topWiFiConnectionBar
            Divider()

            HStack(spacing: 0) {
                leftQueueSidebar
                    .frame(width: 265)
                Divider()

                centerPolaroidPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()

                rightCreativeInspector
                    .frame(width: 390)
            }

            if vm.showProtocolConsole {
                Divider()
                bottomProtocolConsole
                    .frame(height: 155)
            }

            Divider()
            bottomStatusBar
        }
        .sheet(isPresented: $vm.showNetworkDiagnosticsSheet) {
            LegacyNetworkDiagnosticsSheet(printer: printer, vm: vm)
        }
        .onChange(of: vm.photoPickerItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = NSImage(data: data) {
                        await MainActor.run {
                            if vm.primaryImage == nil {
                                vm.primaryImage = img
                            } else {
                                vm.printQueue.append(img)
                                vm.primaryImage = img
                            }
                            vm.refreshPreview()
                        }
                    }
                }
                await MainActor.run { vm.photoPickerItems.removeAll() }
            }
        }
        .onChange(of: vm.collagePickerItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = NSImage(data: data) {
                        await MainActor.run {
                            vm.options.collageImages.append(img)
                            vm.validateCollageLayout()
                            vm.refreshPreview()
                        }
                    }
                }
                await MainActor.run { vm.collagePickerItems.removeAll() }
            }
        }
        .onOpenURL { url in
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = comps.queryItems?.first(where: { $0.name == "file" })?.value,
               let img = NSImage(contentsOfFile: fileParam) {
                vm.primaryImage = img
                vm.refreshPreview()
            }
        }
    }

    // MARK: - Top Wi-Fi Direct Discovery & Connection Bar (Streamlined & Clean)

    private var topWiFiConnectionBar: some View {
        HStack(spacing: 12) {
            // Brand & Wi-Fi status indicator
            HStack(spacing: 8) {
                Image(systemName: printer.isConnected ? "wifi.circle.fill" : "wifi.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor(printer.isConnected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Legacy Instax Printer")
                        .font(.system(size: 13, weight: .bold))
                    Text(printer.isConnected ? (printer.detectedWiFiSSID.isEmpty ? "Connected" : printer.detectedWiFiSSID) : "Join INSTAX-XXXXXXXX Wi-Fi")
                        .font(.system(size: 10))
                        .foregroundColor(printer.isConnected ? .green : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 175, alignment: .leading)

            Divider().frame(height: 24)

            // Model Selection
            HStack(spacing: 5) {
                Text("Model:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Model", selection: Binding(
                    get: { vm.options.model },
                    set: { newModel in
                        vm.options.model = newModel
                        LegacyVirtualPrinterServer.shared.simulatedModel = newModel
                        vm.refreshPreview()
                    }
                )) {
                    ForEach(LegacyPrinterModel.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
            }

            // Connection Target Dropdown
            HStack(spacing: 5) {
                Text("Target:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Target", selection: Binding(
                    get: { printer.selectedDiscoveryID },
                    set: { newID in
                        printer.applyDiscoverySelection(newID) { detected in
                            vm.options.model = detected
                            vm.refreshPreview()
                        }
                    }
                )) {
                    ForEach(printer.discoveryItems) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            // Primary Connect Button
            Button {
                printer.queryPrinterStatus { detected in
                    vm.options.model = detected
                    vm.refreshPreview()
                }
            } label: {
                Label(printer.isConnected ? "Refresh" : "Connect", systemImage: "bolt.horizontal.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(printer.isConnected ? .green : .blue)
            .disabled(printer.isBusy)

            if printer.isConnected {
                Button {
                    printer.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "personalhotspot.slash")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(printer.isBusy)
                .help("Disconnect active session with Instax SHARE printer")

                Button(role: .destructive) {
                    printer.turnOffOrSleep()
                } label: {
                    Label("Turn Off (Sleep)", systemImage: "power")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(printer.isBusy)
                .help("Send hardware reset command to printer to release lock and allow sleep/power off")
            }

            Spacer()

            // Network Settings & Diagnostics Popover/Sheet Button
            Button {
                vm.showNetworkDiagnosticsSheet = true
            } label: {
                Label("Network & Diagnostics", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Configure custom IP/PIN, scan nearby Wi-Fi airwaves, or test TCP 8080 reachability")

            Divider().frame(height: 24)

            // Dry Run (0-Film) Toggle Switch
            Toggle(isOn: $printer.dryRunMode) {
                Text("Dry Run (0-Film)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(printer.dryRunMode ? .orange : .primary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Send 100% of planar RGB image segments to verify Wi-Fi & PIN, then skip physical print trigger so 0 film is used")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Left Sidebar (Authentic Hardware Telemetry + Photos + Queue)

    private var leftQueueSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Authentic 10-LED Film Counter Card (Only lights up when actually connected!)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(printer.telemetry.modelName ?? vm.options.model.rawValue) FILM LEDs")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if printer.isConnected,
                       let film = printer.telemetry.filmRemaining,
                       let batt = printer.telemetry.batteryLevel {
                        Text("\(film)/10 Left • Batt \(batt)/4")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("Not Connected • —/10 • Batt —")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 5) {
                    let activeFilm = printer.isConnected ? (printer.telemetry.filmRemaining ?? 0) : 0
                    ForEach(0..<10, id: \.self) { idx in
                        Circle()
                            .fill(idx < activeFilm ? Color.green : Color.gray.opacity(0.22))
                            .frame(width: 9, height: 9)
                            .shadow(color: idx < activeFilm ? Color.green.opacity(0.6) : .clear, radius: 2)
                    }
                }
                .padding(.vertical, 2)

                if !printer.isConnected {
                    HStack(spacing: 6) {
                        Text("Join printer Wi-Fi to read live LEDs")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Wi-Fi Settings") {
                            printer.openSystemWiFiSettings()
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.link)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            Text("PHOTO SOURCE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            PhotosPicker(
                selection: $vm.photoPickerItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Label("Apple Photos / iCloud...", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            HStack(spacing: 6) {
                Button {
                    openFilesFromDisk(forCollage: false)
                } label: {
                    Label("Open File...", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    vm.primaryImage = LegacyStudioViewModel.makeSampleTestCard(for: vm.options.model)
                    vm.refreshPreview()
                } label: {
                    Label("Test Card", systemImage: "sparkles.rectangle.stack")
                }
            }

            Divider()

            HStack {
                Text("PRINT QUEUE (\(vm.printQueue.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if !vm.printQueue.isEmpty {
                    Button("Clear") {
                        vm.printQueue.removeAll()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if let active = vm.primaryImage {
                        HStack(spacing: 8) {
                            Image(nsImage: active)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active Canvas Photo")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(vm.options.model.width)×\(vm.options.model.height) Planar RGB")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.14)))
                    }

                    ForEach(Array(vm.printQueue.enumerated()), id: \.offset) { idx, img in
                        HStack(spacing: 8) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text("Queued Photo #\(idx + 1)")
                                .font(.system(size: 11))
                            Spacer()
                            Button {
                                vm.primaryImage = img
                                vm.refreshPreview()
                            } label: {
                                Image(systemName: "arrow.up.left.square")
                            }
                            .buttonStyle(.borderless)
                            Button {
                                vm.printQueue.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Label("Wi-Fi Direct Connection Checklist", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("1. Turn on SP-1, SP-2, or SP-3.\n2. Click 'Scan Wi-Fi' and select 'INSTAX-XXXXXXXX' from the dropdown.\n3. Default PIN is 1111 (IP 192.168.0.251).")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
        .padding(12)
    }

    // MARK: - Center Polaroid Frame Preview

    private var centerPolaroidPreview: some View {
        VStack(spacing: 14) {
            HStack {
                Text(vm.options.model.displayName)
                    .font(.system(size: 14, weight: .bold))
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(vm.options.model.width) × \(vm.options.model.height) px (\(vm.options.model.totalBytes / 1000) KB Planar RGB • \(vm.options.model.segmentCount) TCP Segments)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    vm.options.rotationDegrees = (vm.options.rotationDegrees + 90) % 360
                    vm.refreshPreview()
                } label: {
                    Label("Rotate 90°", systemImage: "rotate.right")
                }
                Button {
                    savePreviewToDisk()
                } label: {
                    Label("Export PNG", systemImage: "square.and.arrow.down")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.97, green: 0.96, blue: 0.94))
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)

                VStack(spacing: 10) {
                    if let prev = vm.previewImage {
                        Image(nsImage: prev)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(vm.options.model.aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        let pWidth: Double = (vm.options.model == .sp3 ? 380.0 : 305.0)
                                        let pHeight: Double = pWidth / vm.options.model.aspectRatio
                                        let halfW = pWidth / 2.0
                                        let halfH = pHeight / 2.0

                                        if !vm.isDraggingCanvas {
                                            vm.isDraggingCanvas = true
                                            vm.dragStartOffset = CGSize(width: vm.options.offsetX, height: vm.options.offsetY)
                                            vm.stickerStartOffset = CGSize(width: vm.options.stickerX, height: vm.options.stickerY)
                                            vm.bannerStartOffset = CGSize(width: vm.options.bannerX, height: vm.options.bannerY)

                                            switch vm.canvasDragMode {
                                            case .photo:
                                                vm.activeDragTarget = .photo
                                            case .sticker:
                                                vm.activeDragTarget = .sticker
                                                let stPos = vm.effectiveStickerNormalizedPosition()
                                                if vm.options.stickerPosition != "custom" {
                                                    vm.options.stickerPosition = "custom"
                                                    vm.options.stickerX = stPos.x
                                                    vm.options.stickerY = stPos.y
                                                    vm.stickerStartOffset = CGSize(width: stPos.x, height: stPos.y)
                                                }
                                            case .banner:
                                                vm.activeDragTarget = .banner
                                            case .auto:
                                                let clickNormX = (Double(value.startLocation.x) - halfW) / halfW
                                                let clickNormY = (Double(value.startLocation.y) - halfH) / halfH

                                                let hasSticker = (vm.options.sticker != "none" || vm.options.stickerImage != nil)
                                                let hasBanner = (!vm.options.bannerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.options.bannerStyle != "none")

                                                var stickerHit = false
                                                let stPos = vm.effectiveStickerNormalizedPosition()
                                                if hasSticker {
                                                    let dist = hypot(clickNormX - stPos.x, clickNormY - stPos.y)
                                                    if dist < 0.45 {
                                                        stickerHit = true
                                                    }
                                                }

                                                var bannerHit = false
                                                if hasBanner {
                                                    let bannerDistX = abs(clickNormX - vm.options.bannerX)
                                                    let bannerDistY = abs(clickNormY - vm.options.bannerY)
                                                    if bannerDistX < 0.50 && bannerDistY < 0.28 {
                                                        bannerHit = true
                                                    }
                                                }

                                                if stickerHit {
                                                    vm.activeDragTarget = .sticker
                                                    if vm.options.stickerPosition != "custom" {
                                                        vm.options.stickerPosition = "custom"
                                                        vm.options.stickerX = stPos.x
                                                        vm.options.stickerY = stPos.y
                                                        vm.stickerStartOffset = CGSize(width: stPos.x, height: stPos.y)
                                                    }
                                                } else if bannerHit {
                                                    vm.activeDragTarget = .banner
                                                } else {
                                                    vm.activeDragTarget = .photo
                                                }
                                            }
                                        }

                                        let dx = Double(value.translation.width) / halfW
                                        let dy = Double(value.translation.height) / halfH

                                        switch vm.activeDragTarget {
                                        case .sticker:
                                            vm.options.stickerPosition = "custom"
                                            vm.options.stickerX = max(-1.0, min(1.0, Double(vm.stickerStartOffset.width) + dx))
                                            vm.options.stickerY = max(-1.0, min(1.0, Double(vm.stickerStartOffset.height) + dy))
                                            vm.refreshPreview()
                                        case .banner:
                                            vm.options.bannerX = max(-1.0, min(1.0, Double(vm.bannerStartOffset.width) + dx))
                                            vm.options.bannerY = max(-1.0, min(1.0, Double(vm.bannerStartOffset.height) + dy))
                                            vm.refreshPreview()
                                        case .photo, .auto:
                                            vm.options.offsetX = max(-1.5, min(1.5, Double(vm.dragStartOffset.width) + dx))
                                            vm.options.offsetY = max(-1.5, min(1.5, Double(vm.dragStartOffset.height) + dy))
                                            vm.refreshPreview()
                                        }
                                    }
                                    .onEnded { _ in
                                        vm.isDraggingCanvas = false
                                    }
                            )
                    } else {
                        ProgressView("Rendering preview...")
                    }

                    HStack {
                        Text("FUJIFILM instax SHARE \(vm.options.model.rawValue)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.gray.opacity(0.65))
                        Spacer()
                        if vm.options.collageLayout != .single {
                            Text("\(vm.options.collageLayout.rawValue) • Border \(Int(vm.options.collageBorderSpacing))px")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
            .frame(
                width: vm.options.model == .sp3 ? 420 : 345,
                height: vm.options.model == .sp3 ? 470 : 480
            )
            .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }

            // Drag Target Focus Selector
            HStack(spacing: 8) {
                Text("Drag Target:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Picker("Drag Target", selection: $vm.canvasDragMode) {
                    ForEach(CanvasDragMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            .padding(.top, 4)

            Spacer()

            HStack(spacing: 14) {
                if printer.isBusy {
                    ProgressView(value: printer.progressValue)
                        .frame(width: 240)
                }

                Button {
                    triggerPrint(forceDryRun: true)
                } label: {
                    Label("Test Transfer (0-Film Dry Run)", systemImage: "checkmark.shield")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(printer.isBusy || vm.renderedCGImage == nil)

                Button {
                    triggerPrint(forceDryRun: false)
                } label: {
                    Label(
                        printer.dryRunMode
                            ? "Run Dry-Run Verification (\(vm.options.model.rawValue))"
                            : "Print to Instax \(vm.options.model.rawValue) Over Wi-Fi",
                        systemImage: printer.dryRunMode ? "checkmark.shield.fill" : "printer.fill"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(printer.dryRunMode ? .orange : .accentColor)
                .disabled(printer.isBusy || vm.renderedCGImage == nil)
            }
            .padding(.bottom, 14)
        }
        .background(Color(NSColor.underPageBackgroundColor).opacity(0.35))
    }

    // MARK: - Right Inspector

    private var rightCreativeInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $vm.selectedTab) {
                ForEach(LegacyInspectorTab.allCases) { tab in
                    Text(tab.tabLabel).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch vm.selectedTab {
                    case .framing:
                        framingTabView
                    case .filters:
                        filtersTabView
                    case .analogFX:
                        analogFXTabView
                    case .collage:
                        collageTabView
                    case .decorate:
                        decorateTabView
                    case .qrAndText:
                        qrAndTextTabView
                    }
                }
                .padding(14)
            }
        }
    }

    private var framingTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FRAMING & MATTE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Scaling Mode", selection: Binding(
                get: { vm.options.fitMode },
                set: { vm.options.fitMode = $0; vm.refreshPreview() }
            )) {
                ForEach(LegacyFitMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Matte / Border Color", selection: Binding(
                get: { vm.options.matteColor },
                set: { vm.options.matteColor = $0; vm.refreshPreview() }
            )) {
                ForEach(LegacyMatteColor.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }

            Divider()

            Text("ZOOM & POSITION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Zoom")
                    Spacer()
                    Text(String(format: "%.2f×", vm.options.zoom))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.zoom },
                    set: { vm.options.zoom = $0; vm.refreshPreview() }
                ), in: 0.5...3.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Horizontal Pan")
                    Spacer()
                    Text(String(format: "%+.0f%%", vm.options.offsetX * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.offsetX },
                    set: { vm.options.offsetX = $0; vm.refreshPreview() }
                ), in: -1.0...1.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Vertical Pan")
                    Spacer()
                    Text(String(format: "%+.0f%%", vm.options.offsetY * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.offsetY },
                    set: { vm.options.offsetY = $0; vm.refreshPreview() }
                ), in: -1.0...1.0)
            }

            Button("Reset Zoom & Pan") {
                vm.options.zoom = 1.0
                vm.options.offsetX = 0.0
                vm.options.offsetY = 0.0
                vm.options.rotationDegrees = 0
                vm.refreshPreview()
            }
            .controlSize(.small)
        }
    }

    private var filmPresetsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FILM EMULATION PRESETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Preset", selection: Binding(
                get: { vm.filmPreset },
                set: { vm.applyFilmPreset($0) }
            )) {
                Text("Default / Base (No Effects)").tag("default")
                Text("Custom / Manual (Unsaved)").tag("none")

                Divider()
                Text("── Polaroid Emulations ──").tag("header_polaroid")
                Text("Polaroid SX-70 (1972 Warm Chemistry)").tag("polaroid_sx70")
                Text("Polaroid 600 (Classic 80s/90s Pop)").tag("polaroid_600")
                Text("Polaroid I-Type / Modern Color").tag("polaroid_itype")
                Text("Polaroid Spectra / Image System").tag("polaroid_spectra")

                Divider()
                Text("── Vintage & Nostalgia Eras ──").tag("header_vintage")
                Text("1970s Golden Vintage").tag("vintage_70s")
                Text("1980s Retro Flash Pop").tag("retro_80s")
                Text("1990s Point & Shoot / Disposable").tag("pns_90s")
                Text("1960s Monochrome Silver Halide").tag("mono_silver")

                Divider()
                Text("── Instax Film Profiles ──").tag("header_instax")
                Text("🌈 instax-Rich (Vibrant High Contrast)").tag("instax_rich")
                Text("📷 instax-Natural (3D-LUT Fuji Emulation)").tag("instax_natural")
                Text("Instax Monochrome (B&W Street Film)").tag("instax_mono")
                Text("Instax Warm Sepia (Nostalgic Tea Wash)").tag("instax_sepia")
            }

            Text("Applying a preset synchronizes color, filters, light leaks, vignette, grain & date stamps across tabs.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var filtersTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            filmPresetsBox

            Divider()

            Text("FUJIFILM SHARE FILTERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Filter Preset", selection: Binding(
                get: { vm.options.filter },
                set: { vm.filmPreset = "none"; vm.options.filter = $0; vm.refreshPreview() }
            )) {
                ForEach(LegacyPhotoFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }

            Divider()

            Text("FINE EXPOSURE & COLOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Brightness")
                    Spacer()
                    Text(String(format: "%+.2f", vm.options.brightness))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.brightness },
                    set: { vm.filmPreset = "none"; vm.options.brightness = $0; vm.refreshPreview() }
                ), in: -0.35...0.35)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Contrast")
                    Spacer()
                    Text(String(format: "%.2f×", vm.options.contrast))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.contrast },
                    set: { vm.filmPreset = "none"; vm.options.contrast = $0; vm.refreshPreview() }
                ), in: 0.6...1.6)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Saturation")
                    Spacer()
                    Text(String(format: "%.2f×", vm.options.saturation))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.saturation },
                    set: { vm.filmPreset = "none"; vm.options.saturation = $0; vm.refreshPreview() }
                ), in: 0.0...2.0)
            }

            Button("Reset Color Adjustments") {
                vm.filmPreset = "default"
                vm.options.filter = .normal
                vm.options.brightness = 0.0
                vm.options.contrast = 1.0
                vm.options.saturation = 1.0
                vm.refreshPreview()
            }
            .controlSize(.small)
        }
    }

    private var analogFXTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            filmPresetsBox

            Divider()

            Text("ANALOG CREATIVE FX")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            // Warmth
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Analog Warmth Dial")
                    Spacer()
                    Text(
                        vm.options.warmth > 0 ? String(format: "+%.2f (Amber)", vm.options.warmth) :
                        vm.options.warmth < 0 ? String(format: "%.2f (Cool)", vm.options.warmth) : "0.00 (Neutral)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.warmth },
                    set: { vm.options.warmth = $0; vm.refreshPreview() }
                ), in: -1.0...1.0)
            }

            // Vignette
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lens Vignette Falloff")
                    Spacer()
                    Text("\(Int(vm.options.vignette * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.vignette },
                    set: { vm.options.vignette = $0; vm.refreshPreview() }
                ), in: 0.0...1.0)
            }

            Divider()

            // Light Leaks
            Text("ANALOG LIGHT LEAKS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Leak Type", selection: Binding(
                get: { vm.options.lightLeak },
                set: { vm.options.lightLeak = $0; vm.refreshPreview() }
            )) {
                Text("None").tag("none")
                Text("🔥 Film Burn (Golden Red)").tag("burn")
                Text("☀️ Sunburst Flare (Amber)").tag("sunburst")
                Text("🌅 Sunset Glow (Magenta)").tag("sunset")
                Text("🌈 Rainbow Prism").tag("rainbow")
            }

            if vm.options.lightLeak != "none" {
                HStack(spacing: 8) {
                    Picker("Placement", selection: Binding(
                        get: { vm.options.leakPlacement },
                        set: {
                            if $0 == "auto" {
                                vm.rollAutoLeakPlacement()
                            } else {
                                vm.options.leakPlacement = $0
                                vm.refreshPreview()
                            }
                        }
                    )) {
                        Text(vm.options.leakPlacement == "auto" ? "🎲 Auto (\(vm.leakPlacementTitle(vm.currentAutoLeakPlacement)))" : "🎲 Auto (Randomize)").tag("auto")
                        Text("Left Edge").tag("left")
                        Text("Right Edge").tag("right")
                        Text("Top Right Corner").tag("topRight")
                        Text("Top Left Corner").tag("topLeft")
                        Text("Bottom Left Streak").tag("bottomLeft")
                        Text("Bottom Right Corner").tag("bottomRight")
                        Text("Diagonal Across").tag("diagonal")
                    }

                    if vm.options.leakPlacement == "auto" {
                        Button(action: {
                            vm.rollAutoLeakPlacement()
                        }) {
                            Image(systemName: "die.face.5.fill")
                        }
                        .help("Roll / randomize auto leak position again (🎲)")
                        .buttonStyle(.borderless)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Leak Intensity")
                        Spacer()
                        Text("\(Int(vm.options.leakIntensity * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { vm.options.leakIntensity },
                        set: { vm.options.leakIntensity = $0; vm.refreshPreview() }
                    ), in: 0.1...1.0)
                }
            }

            Divider()

            // Grain & Wear
            Text("HALIDE GRAIN & WEAR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Silver Halide Grain")
                    Spacer()
                    Text("\(Int(vm.options.filmGrain * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.filmGrain },
                    set: { vm.options.filmGrain = $0; vm.refreshPreview() }
                ), in: 0.0...1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scratches, Dust & Wear")
                    Spacer()
                    Text("\(Int(vm.options.analogWear * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.analogWear },
                    set: { vm.options.analogWear = $0; vm.refreshPreview() }
                ), in: 0.0...1.0)
            }

            Divider()

            // Vintage LED Date Stamp
            Text("VINTAGE LED DATE STAMP")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Toggle("Enable LED Date Stamp", isOn: Binding(
                get: { vm.options.showVintageDate },
                set: { vm.options.showVintageDate = $0; vm.refreshPreview() }
            ))

            if vm.options.showVintageDate {
                TextField("Date Text (Empty = Today ''YY MM DD)", text: Binding(
                    get: { vm.options.vintageDateText },
                    set: { vm.options.vintageDateText = $0; vm.refreshPreview() }
                ))
                .textFieldStyle(.roundedBorder)

                Picker("LED Color", selection: Binding(
                    get: { vm.options.vintageDateColor },
                    set: { vm.options.vintageDateColor = $0; vm.refreshPreview() }
                )) {
                    Text("🟠 Amber Gold").tag("amber")
                    Text("🔴 Retro Red").tag("red")
                    Text("🟢 Matrix Green").tag("green")
                    Text("⚪ Cool White").tag("white")
                }

                Picker("Placement", selection: Binding(
                    get: { vm.options.vintageDatePlacement },
                    set: { vm.options.vintageDatePlacement = $0; vm.refreshPreview() }
                )) {
                    Text("Bottom Right").tag("bottomRight")
                    Text("Bottom Left").tag("bottomLeft")
                    Text("Top Right").tag("topRight")
                    Text("Top Left").tag("topLeft")
                }
            }

            HStack {
                Button("🎲 Surprise Me!") {
                    vm.surpriseMeAnalogFX()
                }
                .controlSize(.small)

                Spacer()

                Button("Reset Analog FX") {
                    vm.resetAnalogFX()
                }
                .controlSize(.small)
            }
        }
    }

    private var collageTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MULTI-PHOTO COLLAGE STUDIO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Grid Layout", selection: Binding(
                get: { vm.options.collageLayout },
                set: { vm.options.collageLayout = $0; vm.refreshPreview() }
            )) {
                ForEach(LegacyCollageLayout.allCases) { layout in
                    Text("\(layout.rawValue) (\(layout.slotCount) slots)").tag(layout)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Collage Border Spacing")
                    Spacer()
                    Text("\(Int(vm.options.collageBorderSpacing)) px")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.collageBorderSpacing },
                    set: { newVal in
                        vm.options.collageBorderSpacing = newVal
                        if vm.options.collageLayout == .single && !vm.options.collageImages.isEmpty {
                            vm.validateCollageLayout()
                        }
                        vm.refreshPreview()
                    }
                ), in: 0...28, step: 1)
            }

            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $vm.collagePickerItems,
                    maxSelectionCount: 6,
                    matching: .images
                ) {
                    Label("Add Photos...", systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openFilesFromDisk(forCollage: true)
                } label: {
                    Label("Add Files...", systemImage: "folder.badge.plus")
                }
            }

            let totalLoaded = (vm.primaryImage != nil ? 1 : 0) + vm.options.collageImages.count
            Text("Slot 1 uses your active canvas photo (\(totalLoaded) total loaded across \(vm.options.collageLayout.slotCount) layout slots).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if !vm.options.collageImages.isEmpty {
                Divider()
                HStack {
                    Text("EXTRA COLLAGE SLOTS (\(vm.options.collageImages.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear Extra Slots") {
                        vm.options.collageImages.removeAll()
                        vm.options.collageLayout = .single
                        vm.refreshPreview()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }

                ForEach(Array(vm.options.collageImages.enumerated()), id: \.offset) { idx, img in
                    HStack(spacing: 8) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        Text("Slot #\(idx + 2)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button {
                            vm.options.collageImages.remove(at: idx)
                            vm.validateCollageLayout()
                            vm.refreshPreview()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                }
            }
        }
    }

    // MARK: - Stickers & Decorative Frames Tab View

    private var decorateTabView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DECORATIVE FILM FRAMES & BORDERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Frame Style", selection: Binding(
                get: { vm.options.frameStyle },
                set: { vm.options.frameStyle = $0; vm.refreshPreview() }
            )) {
                Text("None (Full Bleed)").tag("none")
                Divider()
                Text("⚪ Classic White Film Frame").tag("classic_white")
                Text("⚫ Obsidian Black Film Frame").tag("obsidian_black")
                Text("🌈 Rainbow Spectrum Gradient").tag("rainbow_gradient")
                Text("🌅 Sunset Ombre Fade").tag("sunset_ombre")
                Text("🎞️ 35mm Vintage Film Sprockets").tag("sprocket_35mm")
                Text("🪙 Metallic Gold Foil").tag("gold_metallic")
                Text("✨ Rose Gold Foil").tag("rose_gold")
                Text("🍬 Pastel Candy Geometric").tag("pastel_pop")
                Text("✉️ Scalloped Postage Stamp").tag("postage_stamp")
                Divider()
                Text("⚜️ Baroque Filigree Oval").tag("baroque_filigree")
                Text("🌿 Wedding Floral Corner Brackets").tag("wedding_corners")
                Text("💎 Stained Glass Leaded Mosaic").tag("stained_glass")
                Text("✨ Glowing Bokeh & Sparkles").tag("bokeh_sparkles")
                Text("🎆 Fireworks Celebration").tag("fireworks_celebration")
                Text("💕 Hanging Twin Hearts Garland").tag("twin_hearts_garland")
                Text("🎄 Holiday Pine & Bow Garland").tag("holiday_garland")
                Text("🍂 Autumn Botanical Foliage").tag("botanical_foliage")
            }
            .pickerStyle(.menu)

            Divider()

            Text("STICKER EMBELLISHMENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Sticker", selection: Binding(
                get: { vm.options.sticker },
                set: { vm.options.sticker = $0; vm.refreshPreview() }
            )) {
                Text("None (No Sticker)").tag("none")
                Divider()
                Group {
                    Text("💖 \"love\" Calligraphy Brush").tag("love_script")
                    Text("❤️ \"I LOVE YOU\" Hearts").tag("i_love_you")
                    Text("♾️ \"forever\" Script Heart").tag("forever_heart")
                    Text("✏️ Sketched Scribble Heart").tag("sketchy_heart")
                    Text("🪽 Angel Winged Heart").tag("winged_heart")
                    Text("💌 Love Letter & Red Heart").tag("love_envelope")
                    Text("🌟 Radiant Bursting Heart").tag("shining_heart")
                    Text("🎈 Trio Heart Balloons").tag("heart_balloons")
                    Text("💘 Cupid Pierced Arrow Heart").tag("heart_arrow")
                    Text("🫶 Heart Hands Gesture").tag("heart_hands")
                    Text("➰ Continuous Ribbon Heart").tag("looping_heart")
                }
                Divider()
                Group {
                    Text("🎂 Birthday Cake with Candles").tag("birthday_cake_doodle")
                    Text("🚩 Party Pennant Bunting").tag("birthday_bunting")
                    Text("✨ \"Happy Holidays\" Gold").tag("happy_holidays_gold")
                    Text("🌿 \"Season's Greetings\" Wreath").tag("season_greetings")
                    Text("🎄 Decorated Holiday Tree").tag("xmas_tree")
                    Text("🍒 Winter Holly & Berries").tag("holly_berries")
                    Text("🧦 Hanging Holiday Stockings").tag("christmas_stockings")
                    Text("👻 Friendly Ghost & Hat").tag("halloween_ghost")
                    Text("🎃 Jack-o'-Lantern Pumpkin").tag("jack_o_lantern")
                    Text("🦇 Flying Night Bats").tag("flying_bats")
                    Text("🩴 Summer Beach Sandals").tag("summer_flipflops")
                    Text("🐚 Scallop Shell & Starfish").tag("seashells")
                    Text("🌸 Sakura Blossom Branch").tag("cherry_blossoms")
                    Text("🌾 Golden Mimosa Blossom").tag("mimosa")
                }
                Divider()
                Group {
                    Text("🎉 Party Popper").tag("party_popper")
                    Text("🎂 Birthday Cake").tag("birthday_cake")
                    Text("✨ Magic Sparkles").tag("sparkles")
                    Text("🥂 Cheers Champagne").tag("cheers")
                    Text("🎈 Party Balloon").tag("balloon")
                    Text("🎁 Gift Box").tag("gift")
                }
                Divider()
                Group {
                    Text("📸 Vintage Camera").tag("camera")
                    Text("✈️ Jet Airplane").tag("airplane")
                    Text("🌴 Tropical Palm").tag("palm_tree")
                    Text("⛺️ Camp Tent").tag("tent")
                    Text("⛰️ Mountain Peak").tag("mountain")
                    Text("☀️ Radiant Sun").tag("sun")
                    Text("🌊 Ocean Wave").tag("wave")
                }
                Divider()
                Group {
                    Text("❤️ Classic Red Heart").tag("heart")
                    Text("💖 Sparkling Heart").tag("sparkle_heart")
                    Text("💕 Two Hearts").tag("two_hearts")
                    Text("💌 Love Letter").tag("love_letter")
                    Text("🌹 Red Rose").tag("rose")
                    Text("💐 Flower Bouquet").tag("bouquet")
                }
                Divider()
                Group {
                    Text("🐾 Paw Prints").tag("paw")
                    Text("🐶 Cute Doggo").tag("puppy")
                    Text("🐱 Sweet Kitty").tag("kitten")
                    Text("🌸 Cherry Blossom").tag("cherry_blossom")
                    Text("☕️ Warm Coffee").tag("coffee")
                    Text("🍀 Lucky Clover").tag("four_leaf_clover")
                }
                Divider()
                Group {
                    Text("📼 Mixtape Cassette").tag("cassette")
                    Text("🕶️ Cool Sunglasses").tag("sunglasses")
                    Text("✌️ Peace Sign").tag("peace")
                    Text("⚡️ Lightning Bolt").tag("lightning")
                    Text("🎵 Musical Melody").tag("music")
                    Text("🔥 Lit / Fire").tag("fire")
                }
            }
            .pickerStyle(.menu)

            // Quick Sticker Buttons
            HStack(spacing: 5) {
                Button("✨") { vm.options.sticker = "sparkles"; vm.refreshPreview() }
                Button("❤️") { vm.options.sticker = "heart"; vm.refreshPreview() }
                Button("💖") { vm.options.sticker = "love_script"; vm.refreshPreview() }
                Button("🎂") { vm.options.sticker = "birthday_cake_doodle"; vm.refreshPreview() }
                Button("📸") { vm.options.sticker = "camera"; vm.refreshPreview() }
                Button("🎉") { vm.options.sticker = "party_popper"; vm.refreshPreview() }
                Button("🎄") { vm.options.sticker = "xmas_tree"; vm.refreshPreview() }
                Button("🌸") { vm.options.sticker = "cherry_blossoms"; vm.refreshPreview() }
                Spacer()
                if vm.options.sticker != "none" {
                    Button("Clear") { vm.options.sticker = "none"; vm.refreshPreview() }
                        .controlSize(.small)
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider()

            Text("CUSTOM IMAGE OVERLAY / LOGO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            HStack {
                Button("Choose PNG / Image...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image, .png, .jpeg]
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        if let img = NSImage(contentsOf: url) {
                            vm.options.stickerImage = img
                            vm.refreshPreview()
                        }
                    }
                }
                .controlSize(.small)

                if vm.options.stickerImage != nil {
                    Button("Remove") {
                        vm.options.stickerImage = nil
                        vm.refreshPreview()
                    }
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }

            Divider()

            Text("STICKER TRANSFORM & POSITION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Position", selection: Binding(
                get: { vm.options.stickerPosition },
                set: { newPos in
                    vm.options.stickerPosition = newPos
                    if newPos != "custom" {
                        let pos = vm.effectiveStickerNormalizedPosition()
                        vm.options.stickerX = pos.x
                        vm.options.stickerY = pos.y
                    }
                    vm.refreshPreview()
                }
            )) {
                Text("Bottom-Right Corner").tag("bottomRight")
                Text("Bottom-Left Corner").tag("bottomLeft")
                Text("Top-Right Corner").tag("topRight")
                Text("Top-Left Corner").tag("topLeft")
                Text("Center").tag("center")
                Text("Bottom-Center").tag("bottomCenter")
                Text("Top-Center").tag("topCenter")
                Text("✋ Free Move / Drag Anywhere").tag("custom")
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sticker Horizontal (X)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.stickerX * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.stickerX },
                    set: { vm.options.stickerX = $0; vm.refreshPreview() }
                ), in: -1.0...1.0, step: 0.02)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sticker Vertical (Y)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.stickerY * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.stickerY },
                    set: { vm.options.stickerY = $0; vm.refreshPreview() }
                ), in: -1.0...1.0, step: 0.02)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Size")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.stickerScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.stickerScale },
                    set: { vm.options.stickerScale = $0; vm.refreshPreview() }
                ), in: 0.10...0.60, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.stickerOpacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.stickerOpacity },
                    set: { vm.options.stickerOpacity = $0; vm.refreshPreview() }
                ), in: 0.10...1.0, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Rotation")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.stickerRotation))°")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.stickerRotation },
                    set: { vm.options.stickerRotation = $0; vm.refreshPreview() }
                ), in: -45.0...45.0, step: 5.0)
            }

            Divider()

            Text("CUSTOM BANNER MAKER")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            TextField("Banner text (e.g. Best Friends, Summer '26)...", text: Binding(
                get: { vm.options.bannerText },
                set: { vm.options.bannerText = $0; vm.refreshPreview() }
            ))
            .textFieldStyle(.roundedBorder)

            Picker("Banner Style", selection: Binding(
                get: { vm.options.bannerStyle },
                set: { vm.options.bannerStyle = $0; vm.refreshPreview() }
            )) {
                Text("None (No Banner)").tag("none")
                Text("🎀 3D Folded Swallowtail Ribbon").tag("ribbon")
                Text("✒️ Calligraphy Brush Stroke").tag("calligraphy")
                Text("💊 Modern Frosted Pill Badge").tag("pill")
                Text("🏷️ Vintage Luggage Tag").tag("tag")
                Text("📮 Postal Cancellation Stamp").tag("stamp")
                Text("🚩 Triangle Bunting Garland").tag("garland")
            }
            .pickerStyle(.menu)

            Picker("Icon Badge", selection: Binding(
                get: { vm.options.bannerIcon },
                set: { vm.options.bannerIcon = $0; vm.refreshPreview() }
            )) {
                Text("None").tag("none")
                Text("❤️ Heart").tag("heart")
                Text("✨ Sparkles").tag("sparkles")
                Text("🎉 Party").tag("party")
                Text("⭐ Star").tag("star")
                Text("📸 Camera").tag("camera")
                Text("🎂 Birthday Cake").tag("cake")
                Text("🌸 Flower").tag("flower")
                Text("💍 Ring").tag("ring")
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Banner Horizontal (X)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.bannerX * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.bannerX },
                    set: { vm.options.bannerX = $0; vm.refreshPreview() }
                ), in: -1.0...1.0, step: 0.02)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Banner Vertical (Y)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.bannerY * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.bannerY },
                    set: { vm.options.bannerY = $0; vm.refreshPreview() }
                ), in: -1.0...1.0, step: 0.02)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Banner Scale")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.bannerScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.bannerScale },
                    set: { vm.options.bannerScale = $0; vm.refreshPreview() }
                ), in: 0.3...2.0, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Banner Rotation")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(vm.options.bannerRotation))°")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.options.bannerRotation },
                    set: { vm.options.bannerRotation = $0; vm.refreshPreview() }
                ), in: -45.0...45.0, step: 5.0)
            }

            Button("Reset All Decorations") {
                vm.options.frameStyle = "none"
                vm.options.sticker = "none"
                vm.options.stickerImage = nil
                vm.options.stickerPosition = "bottomRight"
                vm.options.stickerScale = 0.25
                vm.options.stickerOpacity = 1.0
                vm.options.stickerRotation = 0.0
                vm.options.stickerX = 0.65
                vm.options.stickerY = 0.65
                vm.options.bannerText = ""
                vm.options.bannerStyle = "none"
                vm.options.bannerIcon = "none"
                vm.options.bannerX = 0.0
                vm.options.bannerY = 0.68
                vm.options.bannerScale = 1.0
                vm.options.bannerRotation = 0.0
                vm.refreshPreview()
            }
            .controlSize(.small)
        }
    }

    private var qrAndTextTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SCANNABLE QR CODE OVERLAY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("QR Code Type", selection: Binding(
                get: { vm.options.qrContentType },
                set: { vm.options.qrContentType = $0; vm.refreshPreview() }
            )) {
                ForEach(LegacyQRContentType.allCases) { qt in
                    Text(qt.rawValue).tag(qt)
                }
            }

            if vm.options.qrContentType != .none {
                VStack(alignment: .leading, spacing: 8) {
                    Text(qrPrimaryPrompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(qrPrimaryPlaceholder, text: Binding(
                        get: { vm.options.qrPrimaryText },
                        set: { vm.options.qrPrimaryText = $0; vm.refreshPreview() }
                    ))
                    .textFieldStyle(.roundedBorder)

                    if let secPrompt = qrSecondaryPrompt {
                        Text(secPrompt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("", text: Binding(
                            get: { vm.options.qrSecondaryText },
                            set: { vm.options.qrSecondaryText = $0; vm.refreshPreview() }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    Picker("Corner Position", selection: Binding(
                        get: { vm.options.qrCorner },
                        set: { vm.options.qrCorner = $0; vm.refreshPreview() }
                    )) {
                        ForEach(LegacyQRCorner.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("QR Badge Size")
                            Spacer()
                            Text("\(Int(vm.options.qrSizeRatio * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { vm.options.qrSizeRatio },
                            set: { vm.options.qrSizeRatio = $0; vm.refreshPreview() }
                        ), in: 0.13...0.30)
                    }

                    Toggle("Show Label Under QR", isOn: Binding(
                        get: { vm.options.qrIncludeLabel },
                        set: { vm.options.qrIncludeLabel = $0; vm.refreshPreview() }
                    ))

                    if vm.options.qrIncludeLabel {
                        TextField("SCAN ME", text: Binding(
                            get: { vm.options.qrLabelText },
                            set: { vm.options.qrLabelText = $0; vm.refreshPreview() }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            }

            Divider()

            Text("CAPTION & DATE STAMP")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            TextField("Optional bottom caption...", text: Binding(
                get: { vm.options.captionText },
                set: { vm.options.captionText = $0; vm.refreshPreview() }
            ))
            .textFieldStyle(.roundedBorder)

            Toggle("Include Date Stamp (YYYY.MM.DD)", isOn: Binding(
                get: { vm.options.includeDateStamp },
                set: { vm.options.includeDateStamp = $0; vm.refreshPreview() }
            ))
        }
    }

    // MARK: - Bottom Protocol Log & Status Bar

    private var bottomProtocolConsole: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Instax SHARE Wi-Fi Direct TCP Protocol Log (Port \(printer.printerPort))", systemImage: "terminal.fill")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Button("Clear Log") {
                    printer.logs.removeAll()
                }
                .font(.caption)
                .buttonStyle(.link)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(printer.logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .background(Color.black.opacity(0.88))
        .foregroundColor(.green)
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(printer.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(printer.statusHeadline)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer()
            if printer.isConnected, let total = printer.telemetry.totalPrintHistory {
                Text("Lifetime Printer Counter: \(total)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("Lifetime Printer Counter: — (Offline)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Button {
                vm.showProtocolConsole.toggle()
            } label: {
                Label(vm.showProtocolConsole ? "Hide TCP Console" : "Show TCP Console", systemImage: "chevron.up.chevron.down")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helpers

    private var qrPrimaryPrompt: String {
        switch vm.options.qrContentType {
        case .none: return ""
        case .url: return "Website URL (https://...)"
        case .text: return "Text / Message to Encode"
        case .phone: return "Phone Number (+44...)"
        case .email: return "Recipient Email Address"
        case .wifi: return "Wi-Fi Network Name (SSID)"
        case .location: return "Latitude (e.g. 51.5074)"
        }
    }

    private var qrPrimaryPlaceholder: String {
        switch vm.options.qrContentType {
        case .url: return "https://..."
        case .text: return "Enter note or memory..."
        case .phone: return "+44 7700 900077"
        case .email: return "hello@example.com"
        case .wifi: return "MyHomeWiFi"
        case .location: return "51.5074"
        case .none: return ""
        }
    }

    private var qrSecondaryPrompt: String? {
        switch vm.options.qrContentType {
        case .email: return "Email Subject (Optional)"
        case .wifi: return "Wi-Fi Password"
        case .location: return "Longitude (e.g. -0.1278)"
        default: return nil
        }
    }

    private func triggerPrint(forceDryRun: Bool) {
        guard let cg = vm.renderedCGImage else { return }
        let previousDry = printer.dryRunMode
        if forceDryRun { printer.dryRunMode = true }
        printer.printCGImage(cg, model: vm.options.model) { _ in
            if forceDryRun {
                printer.dryRunMode = previousDry
            }
        }
    }

    private func openFilesFromDisk(forCollage: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let img = NSImage(contentsOf: url) {
                    if forCollage {
                        vm.options.collageImages.append(img)
                    } else {
                        if vm.primaryImage == nil {
                            vm.primaryImage = img
                        } else {
                            vm.printQueue.append(img)
                            vm.primaryImage = img
                        }
                    }
                }
            }
            if forCollage { vm.validateCollageLayout() }
            vm.refreshPreview()
        }
    }

    private func savePreviewToDisk() {
        guard let cg = vm.renderedCGImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Instax-\(vm.options.model.rawValue)-\(Int(Date().timeIntervalSince1970)).png"
        if panel.runModal() == .OK, let url = panel.url {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let viewModel = vm
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let img = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            viewModel.primaryImage = img
                            viewModel.refreshPreview()
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Wi-Fi Network Settings & Diagnostics Sheet

struct LegacyNetworkDiagnosticsSheet: View {
    @ObservedObject var printer: LegacyPrinterManager
    @ObservedObject var vm: LegacyStudioViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Wi-Fi Network Settings & Diagnostics")
                        .font(.headline)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Connection Guide Banner
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to Connect to Instax SHARE (SP-1 / SP-2 / SP-3)")
                                .font(.subheadline.bold())
                            Text("1. Turn on your printer.\n2. Open your Mac's Wi-Fi menu and connect to INSTAX-XXXXXXXX (default password: 11111111).\n3. Return to the app and click Connect!\n\n💡 Note: Running Wi-Fi airwave scans or modifying IP settings is only necessary if you are troubleshooting reachability or using a custom Wi-Fi router bridge.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )

                    // Network Configuration Settings
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Printer Connection Settings")
                            .font(.subheadline.bold())

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Printer IP Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("192.168.0.251", text: $printer.printerIP)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                                    .disabled(printer.useVirtualSimulator)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Port")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("8080", text: $printer.printerPort)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 65)
                                    .disabled(printer.useVirtualSimulator)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("PIN Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("1111", text: $printer.pinCode)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 65)
                            }

                            Spacer()

                            Toggle(isOn: $printer.useVirtualSimulator) {
                                VStack(alignment: .leading) {
                                    Text("Virtual SP Simulator")
                                        .font(.subheadline.bold())
                                    Text("127.0.0.1:18080")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Wi-Fi Airwaves Scan & Discovery
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nearby Wi-Fi Airwaves & Printers")
                                    .font(.subheadline.bold())
                                Text("Scans 2.4GHz spectrum for INSTAX-XXXXXXXX SSIDs and probes TCP 8080")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                printer.scanWiFiAndPrinters(autoConnectIfFound: true) { detected in
                                    vm.options.model = detected
                                    vm.refreshPreview()
                                }
                            } label: {
                                Label(printer.isScanningWiFi ? "Scanning..." : "Scan Wi-Fi Airwaves", systemImage: "arrow.clockwise")
                            }
                            .disabled(printer.isScanningWiFi || printer.isBusy)
                        }

                        if printer.discoveryItems.isEmpty {
                            Text("No printers or Wi-Fi points scanned yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(printer.discoveryItems) { item in
                                    HStack {
                                        Image(systemName: item.kind == .virtualSimulator ? "laptopcomputer" : (item.kind == .instaxWiFiSSID || item.kind == .reachablePrinterEndpoint ? "printer.fill" : "wifi"))
                                            .foregroundColor(item.kind == .instaxWiFiSSID || item.kind == .reachablePrinterEndpoint ? .green : .secondary)
                                        Text(item.title)
                                            .font(.system(size: 12, weight: item.kind == .instaxWiFiSSID || item.kind == .reachablePrinterEndpoint ? .bold : .regular))
                                        Spacer()
                                        if item.id == printer.selectedDiscoveryID {
                                            Text("Selected")
                                                .font(.caption2.bold())
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.12))
                                                .cornerRadius(4)
                                        } else {
                                            Button("Select") {
                                                printer.selectedDiscoveryID = item.id
                                                printer.applyDiscoverySelection(item.id) { detected in
                                                    vm.options.model = detected
                                                    vm.refreshPreview()
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(item.id == printer.selectedDiscoveryID ? Color.blue.opacity(0.06) : Color.clear)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
            .frame(width: 580, height: 490)
        }
    }
}

