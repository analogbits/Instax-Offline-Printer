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
                .frame(minWidth: 1120, minHeight: 740)
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
    case collage = "Collage"
    case qrAndText = "QR & Text"

    var id: String { rawValue }
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
                    .frame(width: 255)
                Divider()

                centerPolaroidPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()

                rightCreativeInspector
                    .frame(width: 340)
            }

            if vm.showProtocolConsole {
                Divider()
                bottomProtocolConsole
                    .frame(height: 155)
            }

            Divider()
            bottomStatusBar
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

    // MARK: - Top Wi-Fi Direct Toolbar

    private var topWiFiConnectionBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(printer.isConnected ? .green : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Legacy Instax Printer")
                        .font(.system(size: 14, weight: .bold))
                    Text(printer.detectedWiFiSSID)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Divider().frame(height: 28)

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
            .frame(width: 230)

            HStack(spacing: 6) {
                Text("IP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("192.168.0.251", text: $printer.printerIP)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 112)
                    .disabled(printer.useVirtualSimulator)

                Text("Port:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("8080", text: $printer.printerPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 58)
                    .disabled(printer.useVirtualSimulator)

                Text("PIN:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("1111", text: $printer.pinCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
            }

            Button {
                printer.queryPrinterStatus { detected in
                    vm.options.model = detected
                    vm.refreshPreview()
                }
            } label: {
                Label(printer.isConnected ? "Refresh Status" : "Connect Wi-Fi", systemImage: "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            .tint(printer.isConnected ? .green : .blue)
            .disabled(printer.isBusy)

            Spacer()

            Toggle(isOn: $printer.useVirtualSimulator) {
                Text("Virtual SP Simulator")
                    .font(.system(size: 11, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $printer.dryRunMode) {
                Label("Dry Run (0-Film)", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(printer.dryRunMode ? .orange : .primary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Left Sidebar

    private var leftQueueSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(vm.options.model.rawValue) FILM LEDs")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(printer.telemetry.filmRemaining)/10 Left • Batt \(printer.telemetry.batteryLevel)/4")
                        .font(.system(size: 10, weight: .semibold))
                }
                HStack(spacing: 5) {
                    ForEach(0..<10, id: \.self) { idx in
                        Circle()
                            .fill(idx < printer.telemetry.filmRemaining ? Color.green : Color.gray.opacity(0.28))
                            .frame(width: 9, height: 9)
                            .shadow(color: idx < printer.telemetry.filmRemaining ? Color.green.opacity(0.6) : .clear, radius: 2)
                    }
                }
                .padding(.vertical, 2)
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
                Label("How to Connect SP-1 / SP-2 / SP-3", systemImage: "info.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("1. Power on your Instax SHARE printer.\n2. Join Wi-Fi 'INSTAX-XXXXXXXX' on your Mac.\n3. Default IP is 192.168.0.251, PIN is 1111.")
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
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch vm.selectedTab {
                    case .framing:
                        framingTabView
                    case .filters:
                        filtersTabView
                    case .collage:
                        collageTabView
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

    private var filtersTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FUJIFILM SHARE FILTERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Picker("Filter Preset", selection: Binding(
                get: { vm.options.filter },
                set: { vm.options.filter = $0; vm.refreshPreview() }
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
                    set: { vm.options.brightness = $0; vm.refreshPreview() }
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
                    set: { vm.options.contrast = $0; vm.refreshPreview() }
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
                    set: { vm.options.saturation = $0; vm.refreshPreview() }
                ), in: 0.0...2.0)
            }

            Button("Reset Color Adjustments") {
                vm.options.filter = .normal
                vm.options.brightness = 0.0
                vm.options.contrast = 1.0
                vm.options.saturation = 1.0
                vm.refreshPreview()
            }
            .controlSize(.small)
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
                .fill(printer.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(printer.statusHeadline)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer()
            Text("Lifetime Printer Counter: \(printer.telemetry.totalPrintHistory)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
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
