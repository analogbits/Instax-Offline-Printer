import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreBluetooth
import Photos

// MARK: - Bulk Print Queue & Photos Models

enum QueueItemStatus: Equatable {
    case pending
    case printing
    case printed
    case failed(String)

    var badgeText: String {
        switch self {
        case .pending: return "Queued"
        case .printing: return "Printing..."
        case .printed: return "Printed ✓"
        case .failed: return "Failed"
        }
    }

    var badgeColor: Color {
        switch self {
        case .pending: return .blue
        case .printing: return .orange
        case .printed: return .green
        case .failed: return .red
        }
    }
}

struct QueuedPhotoItem: Identifiable {
    let id: UUID
    var name: String
    var sourceImage: NSImage
    var options: InstaxImageOptions
    var bgColor: Color
    var renderedPreview: NSImage?
    var compressedJPEG: Data?
    var jpegQualityPercent: Int
    var status: QueueItemStatus
    var isCollage: Bool = false
    var collageLayout: InstaxCollageLayout = .single
    var collageImages: [NSImage] = []

    init(
        id: UUID = UUID(),
        name: String,
        sourceImage: NSImage,
        options: InstaxImageOptions = InstaxImageOptions(),
        bgColor: Color = .white,
        isCollage: Bool = false,
        collageLayout: InstaxCollageLayout = .single,
        collageImages: [NSImage] = []
    ) {
        self.id = id
        self.name = name
        self.sourceImage = sourceImage
        self.options = options
        self.bgColor = bgColor
        self.renderedPreview = nil
        self.compressedJPEG = nil
        self.jpegQualityPercent = 92
        self.status = .pending
        self.isCollage = isCollage
        self.collageLayout = collageLayout
        self.collageImages = collageImages
    }
}

struct PhotoAlbumOption: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let collection: PHAssetCollection?
}

struct PhotoAssetEntry: Identifiable {
    let id: String // localIdentifier
    let asset: PHAsset
    let creationDate: Date?
    let isFavorite: Bool
}

enum InstaxPrinterModel: String, CaseIterable, Identifiable {
    case square = "Instax SQUARE Link (800×800)"
    case wide = "Instax Link WIDE / WIDE 2 (1260×840)"
    case mini = "Instax Mini Link 1/2/3 & Link+ (600×800)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .square: return "SQUARE"
        case .wide: return "WIDE"
        case .mini: return "MINI"
        }
    }

    var displayName: String {
        switch self {
        case .square: return "Instax SQUARE Link"
        case .wide: return "Instax Link WIDE / WIDE 2"
        case .mini: return "Instax Mini Link (1/2/3/Link+)"
        }
    }

    var title: String { displayName }

    var icon: String {
        switch self {
        case .square: return "square"
        case .wide: return "rectangle.ratio.16.to.9"
        case .mini: return "rectangle.portrait"
        }
    }

    var printWidth: Int {
        switch self {
        case .square: return 800
        case .wide: return 1260
        case .mini: return 600
        }
    }

    var printHeight: Int {
        switch self {
        case .square: return 800
        case .wide: return 840
        case .mini: return 800
        }
    }

    var previewWidth: CGFloat {
        switch self {
        case .square: return 420
        case .wide: return 480
        case .mini: return 320
        }
    }

    var previewHeight: CGFloat {
        switch self {
        case .square: return 420
        case .wide: return 320
        case .mini: return 426
        }
    }

    var maxJpegBytes: Int {
        switch self {
        case .square: return 60 * 1024
        case .wide: return 200 * 1024
        case .mini: return 55 * 1024
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case framing = "Framing"
    case color = "Color & Filters"
    case analogFX = "Analog FX"
    case collage = "Collage"
    case qrOverlay = "QR & Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .framing: return "crop"
        case .color: return "slider.horizontal.3"
        case .analogFX: return "camera.filters"
        case .collage: return "square.grid.2x2"
        case .qrOverlay: return "qrcode"
        }
    }

    var tabLabel: String {
        switch self {
        case .framing: return "Framing"
        case .color: return "Filters"
        case .analogFX: return "Analog"
        case .collage: return "Collage"
        case .qrOverlay: return "QR/Text"
        }
    }
}

enum LogCategory: String, CaseIterable, Identifiable {
    case all = "ALL"
    case ble = "BLE"
    case print = "PRINT"
    case image = "IMG"
    case err = "ERR"

    var id: String { rawValue }

    var badgeColor: Color {
        switch self {
        case .all: return .gray
        case .ble: return .blue
        case .print: return .green
        case .image: return .purple
        case .err: return .red
        }
    }
}

struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: LogCategory
    let text: String

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

enum HelpTopic: String, CaseIterable, Identifiable {
    case quickStart = "Quick Start"
    case framing = "Framing & Aspect Ratios"
    case printModes = "Rich vs. Natural (3D-LUT)"
    case bulkQueue = "Bulk Queue & Apple Photos"
    case multiPrinter = "Multi-Printer (Square, Wide, Mini)"
    case debugConsole = "Protocol Debug & CLI"
    case offlineBackup = "Offline Backup & Firmware Safety"
    case troubleshooting = "Troubleshooting & FAQs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quickStart: return "bolt.fill"
        case .framing: return "crop"
        case .printModes: return "paintpalette.fill"
        case .bulkQueue: return "square.stack.3d.up.fill"
        case .multiPrinter: return "printer.fill"
        case .debugConsole: return "terminal.fill"
        case .offlineBackup: return "externaldrive.badge.checkmark"
        case .troubleshooting: return "questionmark.circle.fill"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class InstaxAppViewModel: ObservableObject {
    // Printer Model & Bluetooth Status
    @Published var selectedModel: InstaxPrinterModel = .square {
        didSet {
            if !isLoadingSelection {
                updatePreview()
            }
        }
    }
    @Published var targetDeviceName: String = InstaxConstants.defaultDeviceName
    @Published var discoveredPrinters: [DiscoveredPrinter] = []
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectedDeviceName: String = ""
    @Published var status: PrinterStatus = PrinterStatus()
    @Published var bluetoothStateText: String = "Initializing Bluetooth..."

    // Multi-Printer Management & Auto-Detection
    @Published var savedPrinters: [String] = {
        if let saved = UserDefaults.standard.stringArray(forKey: "InstaxSavedPrinters"), !saved.isEmpty {
            return saved
        }
        return [InstaxConstants.defaultDeviceName]
    }()
    @Published var isScanningPrinters: Bool = false
    @Published var showCustomPrinterSheet: Bool = false
    @Published var customPrinterInput: String = ""

    // Debug & Protocol Diagnostics Console
    @Published var logEntries: [LogMessage] = []
    @Published var showDebugConsole: Bool = false
    @Published var debugFilter: LogCategory = .all
    @Published var logSearchQuery: String = ""
    @Published var isAutoScrollLogs: Bool = true

    // User Guide & Help
    @Published var showHelpSheet: Bool = false
    @Published var selectedHelpTopic: HelpTopic = .quickStart
    @Published var helpSearchQuery: String = ""

    // Inspector Tab
    @Published var selectedTab: InspectorTab = .framing

    // Active Editor State
    @Published var sourceImage: NSImage?
    @Published var sourceImageName: String = "Sample Test Card"
    @Published var renderedPreview: NSImage?
    @Published var compressedJPEG: Data?
    @Published var jpegQualityPercent: Int = 92

    // Framing Options
    @Published var fitMode: InstaxFitMode = .crop { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var bgColor: Color = .white { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var zoom: Double = 1.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var offsetX: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var offsetY: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var rotationDegrees: Int = 0 { didSet { if !isLoadingSelection { updatePreview() } } }

    // Color & Filters Options
    @Published var printMode: InstaxPrintMode = .rich { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var filterPreset: InstaxFilterPreset = .none { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var brightness: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var contrast: Double = 1.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var saturation: Double = 1.0 { didSet { if !isLoadingSelection { updatePreview() } } }

    // Analog Creative FX Options (Ported from PolaroidEngine)
    @Published var warmth: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var vignette: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var lightLeak: String = "none" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var leakPlacement: String = "auto" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var leakIntensity: Double = 0.70 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var filmGrain: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var analogWear: Double = 0.0 { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var showVintageDate: Bool = false { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var vintageDateText: String = "" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var vintageDateColor: String = "amber" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var vintageDatePlacement: String = "bottomRight" { didSet { if !isLoadingSelection { updatePreview() } } }

    // Collage & Border Options
    @Published var borderColor: InstaxBorderColor = .white { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var captionText: String = "" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var showDateStamp: Bool = false { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var activeCollageLayout: InstaxCollageLayout = .single { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var collageSpacing: Double = 8.0 { didSet { if !isLoadingSelection { updatePreview() } } }

    // Rich QR Code Overlay Options
    @Published var qrCodeContent: String = "" { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var qrCodePosition: InstaxQRPosition = .bottomRight { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var qrCodeSize: InstaxQRSize = .medium { didSet { if !isLoadingSelection { updatePreview() } } }
    @Published var qrCodeStyle: InstaxQRStyle = .frosted { didSet { if !isLoadingSelection { updatePreview() } } }

    // Bulk Print Queue State
    @Published var printQueue: [QueuedPhotoItem] = []
    @Published var selectedQueueID: UUID?
    @Published var isPrinting: Bool = false
    @Published var isBulkPrinting: Bool = false
    @Published var isDryRun: Bool = false
    @Published var cancelBulkRequested: Bool = false
    @Published var printProgress: Double = 0.0
    @Published var bulkProgressText: String = ""

    // Apple Photos / iCloud Picker Sheet State
    @Published var showPhotosSheet: Bool = false
    @Published var photosAuthStatus: PHAuthorizationStatus = .notDetermined
    @Published var photoAlbums: [PhotoAlbumOption] = []
    @Published var selectedAlbumID: String = "ALL_PHOTOS" { didSet { fetchAssetsForSelectedAlbum() } }
    @Published var photosSearchQuery: String = "" { didSet { filterPhotoAssets() } }
    @Published var sortNewestFirst: Bool = true { didSet { fetchAssetsForSelectedAlbum() } }
    @Published var allFetchedAssets: [PhotoAssetEntry] = []
    @Published var photoAssets: [PhotoAssetEntry] = []
    @Published var photoThumbnails: [String: NSImage] = [:]
    @Published var selectedPhotoAssetIDs: [String] = []
    @Published var isDownloadingICloudPhotos: Bool = false
    @Published var iCloudDownloadProgressText: String = ""

    // Banner
    @Published var statusBanner: String = "Ready — Connect to INSTAX-50271289, drop multiple photos for bulk printing, or browse Apple Photos / iCloud."
    @Published var isErrorBanner: Bool = false

    private let ble = InstaxBLEController()
    private let imageManager = PHCachingImageManager()
    private var isLoadingSelection: Bool = false

    init() {
        setupCallbacks()
        let args = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-") && FileManager.default.fileExists(atPath: $0) }
        if !args.isEmpty {
            for path in args {
                if let img = NSImage(contentsOfFile: path) {
                    addPhotoToQueue(img, name: URL(fileURLWithPath: path).lastPathComponent, select: false)
                }
            }
            if let first = printQueue.first {
                selectQueueItem(first.id)
            }
        } else {
            let sample = Self.makeSampleTestCard()
            addPhotoToQueue(sample, name: "Instax Square Test Card", select: true)
        }
    }

    private func setupCallbacks() {
        InstaxLogger.onLog = { [weak self] msg in
            Task { @MainActor in
                self?.appendRawLog(msg)
            }
        }

        ble.onLog = { [weak self] msg in
            Task { @MainActor in
                self?.appendRawLog(msg)
            }
        }

        ble.onStateUpdate = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .poweredOn:
                    self.bluetoothStateText = "Bluetooth On"
                    self.addLog(category: .ble, text: "Mac Bluetooth adapter is powered ON.")
                    self.ble.startBackgroundScan()
                case .poweredOff:
                    self.bluetoothStateText = "Bluetooth Off"
                    self.addLog(category: .err, text: "Mac Bluetooth is turned OFF.")
                case .unauthorized:
                    self.bluetoothStateText = "Bluetooth Unauthorized"
                    self.addLog(category: .err, text: "Bluetooth permission unauthorized.")
                default:
                    self.bluetoothStateText = "Bluetooth Initializing"
                }
            }
        }

        ble.onPrintersDiscovered = { [weak self] list in
            Task { @MainActor in
                guard let self = self else { return }
                self.discoveredPrinters = list
                for p in list {
                    self.savePrinterToRecents(p.name)
                }
            }
        }

        ble.onConnectionChanged = { [weak self] connected, name in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = connected
                self.connectedDeviceName = name ?? ""
                if connected {
                    self.addLog(category: .ble, text: "GATT connection established with \(name ?? "printer").")
                } else {
                    self.addLog(category: .ble, text: "Printer connection closed.")
                    if !self.isPrinting {
                        self.statusBanner = "Disconnected from printer."
                    }
                }
            }
        }
    }

    // MARK: - Logging & Printer Management Helpers

    func addLog(category: LogCategory, text: String) {
        let entry = LogMessage(timestamp: Date(), category: category, text: text)
        logEntries.append(entry)
        if logEntries.count > 600 {
            logEntries.removeFirst(logEntries.count - 600)
        }
    }

    func appendRawLog(_ raw: String) {
        let cat: LogCategory
        if raw.contains("[TX]") || raw.contains("[RX]") || raw.contains("Bluetooth") || raw.contains("GATT") || raw.contains("[STATUS]") {
            cat = .ble
        } else if raw.contains("[PRINT]") {
            cat = .print
        } else if raw.contains("[IMG]") {
            cat = .image
        } else if raw.contains("[ERR]") || raw.contains("failed") || raw.contains("rejected") || raw.contains("Error") {
            cat = .err
        } else {
            cat = .ble
        }
        addLog(category: cat, text: raw)
    }

    func savePrinterToRecents(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        if !savedPrinters.contains(trimmed) {
            savedPrinters.append(trimmed)
            UserDefaults.standard.set(savedPrinters, forKey: "InstaxSavedPrinters")
        }
    }

    func selectPrinterAndConnect(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isConnected {
            ble.disconnect()
            isConnected = false
        }
        targetDeviceName = trimmed
        savePrinterToRecents(trimmed)
        addLog(category: .ble, text: "Selected printer '\(trimmed)'. Initiating connection...")
        connectAndRefresh()
    }

    func disconnectPrinter() {
        guard isConnected else { return }
        ble.disconnect()
        isConnected = false
        connectedDeviceName = ""
        addLog(category: .ble, text: "User initiated disconnect.")
        statusBanner = "Disconnected from printer."
    }

    func scanForNearbyPrinters() {
        guard !isScanningPrinters else { return }
        isScanningPrinters = true
        addLog(category: .ble, text: "Scanning for nearby Instax printers...")
        Task {
            do {
                let discovered = try await ble.scanForPrinters(duration: 4.0)
                await MainActor.run {
                    self.discoveredPrinters = discovered
                    self.isScanningPrinters = false
                    self.addLog(category: .ble, text: "Scan finished. Found \(discovered.count) printer(s): \(discovered.map { "\($0.name) (\($0.rssi)dBm)" }.joined(separator: ", "))")
                    for p in discovered {
                        self.savePrinterToRecents(p.name)
                    }
                    if let first = discovered.first, self.targetDeviceName.isEmpty {
                        self.targetDeviceName = first.name
                    }
                }
            } catch {
                await MainActor.run {
                    self.isScanningPrinters = false
                    self.addLog(category: .err, text: "Scan failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func rssiStrength(_ rssi: Int) -> String {
        if rssi >= -60 { return "Strong" }
        if rssi >= -75 { return "Good" }
        if rssi >= -85 { return "Fair" }
        return "Weak"
    }

    func copyLogsToClipboard() {
        let formatted = logEntries.map { "[\($0.timeString)] [\($0.category.rawValue)] \($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formatted, forType: .string)
        statusBanner = "Copied \(logEntries.count) log lines to clipboard."
    }

    func clearLogs() {
        logEntries.removeAll()
        addLog(category: .ble, text: "Diagnostics log cleared.")
    }

    func revealOfflineBackupInFinder() {
        let zipPath = "/Users/michaelfitzgerald/Desktop/Instax-Printer-Offline-Backup.zip"
        if FileManager.default.fileExists(atPath: zipPath) {
            NSWorkspace.shared.selectFile(zipPath, inFileViewerRootedAtPath: "")
        } else {
            statusBanner = "Offline backup archive not found on Desktop."
        }
    }

    // MARK: - Image Rendering & Queue Sync

    // MARK: - Image Rendering & Queue Sync

    var selectedQueueItem: QueuedPhotoItem? {
        guard let selID = selectedQueueID else { return nil }
        return printQueue.first(where: { $0.id == selID })
    }

    var effectiveWidth: Int {
        (status.width > 0 && isConnected) ? status.width : selectedModel.printWidth
    }

    var effectiveHeight: Int {
        (status.height > 0 && isConnected) ? status.height : selectedModel.printHeight
    }

    var effectiveMaxJpegBytes: Int {
        if isConnected && status.maxJpegSize > 0 {
            if selectedModel == .wide {
                return min(status.maxJpegSize, 203 * 1024)
            }
            return status.maxJpegSize
        }
        return selectedModel.maxJpegBytes
    }

    func currentImageOptions() -> InstaxImageOptions {
        var opts = InstaxImageOptions()
        opts.fitMode = fitMode
        opts.backgroundColor = NSColor(bgColor)
        opts.zoom = zoom
        opts.offsetX = offsetX
        opts.offsetY = offsetY
        opts.rotationDegrees = rotationDegrees
        opts.brightness = brightness
        opts.contrast = contrast
        opts.saturation = saturation
        opts.printMode = printMode
        opts.filter = filterPreset
        opts.borderColor = borderColor
        opts.captionText = captionText
        opts.showDateStamp = showDateStamp
        opts.collageSpacing = collageSpacing
        opts.collageLayout = activeCollageLayout
        opts.qrCodeContent = qrCodeContent
        opts.qrCodePosition = qrCodePosition
        opts.qrCodeSize = qrCodeSize
        opts.qrCodeStyle = qrCodeStyle
        opts.warmth = warmth
        opts.vignette = vignette
        opts.lightLeak = lightLeak
        opts.leakPlacement = leakPlacement
        opts.leakIntensity = leakIntensity
        opts.filmGrain = filmGrain
        opts.analogWear = analogWear
        opts.showVintageDate = showVintageDate
        opts.vintageDateText = vintageDateText
        opts.vintageDateColor = vintageDateColor
        opts.vintageDatePlacement = vintageDatePlacement
        return opts
    }

    func renderItem(_ item: inout QueuedPhotoItem) {
        let w = effectiveWidth
        let h = effectiveHeight
        let maxB = effectiveMaxJpegBytes

        let rendered: NSImage?
        if item.isCollage && !item.collageImages.isEmpty {
            rendered = InstaxImageRenderer.renderCollageSquare(
                images: item.collageImages,
                layout: item.collageLayout,
                targetWidth: w,
                targetHeight: h,
                spacing: CGFloat(item.options.collageSpacing),
                options: item.options
            )
        } else {
            rendered = InstaxImageRenderer.renderSquareImage(
                from: item.sourceImage,
                targetWidth: w,
                targetHeight: h,
                options: item.options
            )
        }

        if let square = rendered {
            item.renderedPreview = square
            if let comp = InstaxImageRenderer.compressToJPEG(square, maxBytes: maxB) {
                item.compressedJPEG = comp.data
                item.jpegQualityPercent = Int((comp.quality * 100.0).rounded())
            }
        }
    }

    func updatePreview() {
        let opts = currentImageOptions()
        let w = effectiveWidth
        let h = effectiveHeight
        let maxB = effectiveMaxJpegBytes

        // Check if active queue item is a collage
        var isCollageItem = false
        var colImages: [NSImage] = []
        var colLayout = activeCollageLayout

        if let selID = selectedQueueID,
           let item = printQueue.first(where: { $0.id == selID }),
           item.isCollage && !item.collageImages.isEmpty {
            isCollageItem = true
            colImages = item.collageImages
            if colLayout == .single {
                colLayout = item.collageLayout
                activeCollageLayout = item.collageLayout
            }
        }

        let rendered: NSImage?
        if isCollageItem {
            rendered = InstaxImageRenderer.renderCollageSquare(
                images: colImages,
                layout: colLayout,
                targetWidth: w,
                targetHeight: h,
                spacing: CGFloat(collageSpacing),
                options: opts
            )
        } else {
            guard let src = sourceImage else { return }
            rendered = InstaxImageRenderer.renderSquareImage(
                from: src,
                targetWidth: w,
                targetHeight: h,
                options: opts
            )
        }

        if let square = rendered {
            self.renderedPreview = square
            if let comp = InstaxImageRenderer.compressToJPEG(square, maxBytes: maxB) {
                self.compressedJPEG = comp.data
                self.jpegQualityPercent = Int((comp.quality * 100.0).rounded())
            }
        }

        // Sync back into selected queue item
        if let selID = selectedQueueID,
           let idx = printQueue.firstIndex(where: { $0.id == selID }) {
            printQueue[idx].options = opts
            printQueue[idx].bgColor = bgColor
            if isCollageItem {
                printQueue[idx].collageLayout = colLayout
                if let rend = self.renderedPreview {
                    printQueue[idx].sourceImage = rend
                }
            }
            printQueue[idx].renderedPreview = self.renderedPreview
            printQueue[idx].compressedJPEG = self.compressedJPEG
            printQueue[idx].jpegQualityPercent = self.jpegQualityPercent
        }
    }

    func addPhotoToQueue(_ img: NSImage, name: String, select: Bool = true) {
        // Remove sample test card if user is adding their first real photo and test card hasn't been printed
        if printQueue.count == 1,
           printQueue[0].name == "Instax Square Test Card",
           name != "Instax Square Test Card",
           printQueue[0].status == .pending {
            printQueue.removeAll()
        }

        var opts = currentImageOptions()
        opts.printMode = printMode
        var newItem = QueuedPhotoItem(name: name, sourceImage: img, options: opts, bgColor: bgColor)
        renderItem(&newItem)
        printQueue.append(newItem)

        if select || selectedQueueID == nil {
            selectQueueItem(newItem.id)
        }
    }

    func selectQueueItem(_ id: UUID) {
        guard let item = printQueue.first(where: { $0.id == id }) else { return }
        isLoadingSelection = true
        selectedQueueID = item.id
        sourceImage = item.sourceImage
        sourceImageName = item.name
        fitMode = item.options.fitMode
        printMode = item.options.printMode
        filterPreset = item.options.filter
        borderColor = item.options.borderColor
        captionText = item.options.captionText
        showDateStamp = item.options.showDateStamp
        if item.isCollage {
            activeCollageLayout = item.collageLayout
            collageSpacing = item.options.collageSpacing
        }
        qrCodeContent = item.options.qrCodeContent
        qrCodePosition = item.options.qrCodePosition
        qrCodeSize = item.options.qrCodeSize
        qrCodeStyle = item.options.qrCodeStyle
        bgColor = item.bgColor
        zoom = item.options.zoom
        offsetX = item.options.offsetX
        offsetY = item.options.offsetY
        rotationDegrees = item.options.rotationDegrees
        brightness = item.options.brightness
        contrast = item.options.contrast
        saturation = item.options.saturation
        warmth = item.options.warmth
        vignette = item.options.vignette
        lightLeak = item.options.lightLeak
        leakPlacement = item.options.leakPlacement
        leakIntensity = item.options.leakIntensity
        filmGrain = item.options.filmGrain
        analogWear = item.options.analogWear
        showVintageDate = item.options.showVintageDate
        vintageDateText = item.options.vintageDateText
        vintageDateColor = item.options.vintageDateColor
        vintageDatePlacement = item.options.vintageDatePlacement
        renderedPreview = item.renderedPreview
        compressedJPEG = item.compressedJPEG
        jpegQualityPercent = item.jpegQualityPercent
        isLoadingSelection = false
        if renderedPreview == nil {
            updatePreview()
        }
    }

    func removeQueueItem(_ id: UUID) {
        guard !isPrinting else { return }
        printQueue.removeAll { $0.id == id }
        if selectedQueueID == id {
            if let next = printQueue.first {
                selectQueueItem(next.id)
            } else {
                let sample = Self.makeSampleTestCard()
                addPhotoToQueue(sample, name: "Instax Square Test Card", select: true)
            }
        }
    }

    func duplicateQueueItem(_ id: UUID) {
        guard let item = printQueue.first(where: { $0.id == id }) else { return }
        var copy = QueuedPhotoItem(
            name: "\(item.name) (Copy)",
            sourceImage: item.sourceImage,
            options: item.options,
            bgColor: item.bgColor,
            isCollage: item.isCollage,
            collageLayout: item.collageLayout,
            collageImages: item.collageImages
        )
        renderItem(&copy)
        printQueue.append(copy)
        statusBanner = "Added duplicate of '\(item.name)' to bulk print queue (\(printQueue.count) total)."
    }

    // MARK: - Collage Creation

    func createCollageFromQueue(layout: InstaxCollageLayout) {
        let needed = layout.requiredPhotos

        // If the selected item is already a collage, update its layout immediately!
        if let selID = selectedQueueID,
           let idx = printQueue.firstIndex(where: { $0.id == selID }),
           printQueue[idx].isCollage {
            let col = printQueue[idx]
            // If the collage doesn't have enough images for the new layout, borrow from printQueue
            var images = col.collageImages
            if images.count < needed {
                for item in printQueue where !item.isCollage {
                    if images.count >= needed { break }
                    if !images.contains(where: { $0 === item.sourceImage }) {
                        images.append(item.sourceImage)
                    }
                }
            }
            guard images.count >= needed else {
                isErrorBanner = true
                statusBanner = "Need at least \(needed) distinct photos in queue for \(layout.title) layout."
                return
            }

            activeCollageLayout = layout
            printQueue[idx].collageLayout = layout
            printQueue[idx].collageImages = images
            printQueue[idx].name = "\(selectedModel.shortName) Collage (\(layout.title))"
            updatePreview()
            isErrorBanner = false
            statusBanner = "Switched active collage layout to \(layout.title) (\(needed) photos)."
            return
        }

        guard printQueue.count >= needed else {
            isErrorBanner = true
            statusBanner = "Need at least \(needed) photos in queue to create a \(layout.title) collage."
            return
        }

        // Use selected item plus following items, or first N items
        let startIndex: Int
        if let selID = selectedQueueID, let idx = printQueue.firstIndex(where: { $0.id == selID }) {
            startIndex = idx
        } else {
            startIndex = 0
        }

        var sourceImages: [NSImage] = []
        for i in 0..<needed {
            let itemIdx = (startIndex + i) % printQueue.count
            sourceImages.append(printQueue[itemIdx].sourceImage)
        }

        activeCollageLayout = layout
        var opts = currentImageOptions()
        opts.collageLayout = layout
        opts.collageSpacing = collageSpacing

        var newItem = QueuedPhotoItem(
            name: "\(selectedModel.shortName) Collage (\(layout.title))",
            sourceImage: sourceImages.first ?? NSImage(),
            options: opts,
            bgColor: bgColor,
            isCollage: true,
            collageLayout: layout,
            collageImages: sourceImages
        )
        renderItem(&newItem)
        printQueue.append(newItem)
        selectQueueItem(newItem.id)

        isErrorBanner = false
        statusBanner = "Created \(layout.title) collage (\(effectiveWidth)×\(effectiveHeight) px) from \(needed) photos!"
    }

    func createBrandNewCollageFromQueue(layout: InstaxCollageLayout) {
        let needed = layout.requiredPhotos
        guard printQueue.count >= needed else {
            isErrorBanner = true
            statusBanner = "Need at least \(needed) photos in queue to create a \(layout.title) collage."
            return
        }

        var sourceImages: [NSImage] = []
        for i in 0..<needed {
            sourceImages.append(printQueue[i % printQueue.count].sourceImage)
        }

        activeCollageLayout = layout
        var opts = currentImageOptions()
        opts.collageLayout = layout
        opts.collageSpacing = collageSpacing

        var newItem = QueuedPhotoItem(
            name: "\(selectedModel.shortName) Collage (\(layout.title))",
            sourceImage: sourceImages.first ?? NSImage(),
            options: opts,
            bgColor: bgColor,
            isCollage: true,
            collageLayout: layout,
            collageImages: sourceImages
        )
        renderItem(&newItem)
        printQueue.append(newItem)
        selectQueueItem(newItem.id)

        isErrorBanner = false
        statusBanner = "Created new \(layout.title) collage from \(needed) photos."
    }

    func clearPrintedFromQueue() {
        guard !isPrinting else { return }
        printQueue.removeAll { $0.status == .printed }
        if let sel = selectedQueueID, !printQueue.contains(where: { $0.id == sel }) {
            if let first = printQueue.first {
                selectQueueItem(first.id)
            }
        }
    }

    func clearEntireQueue() {
        guard !isPrinting else { return }
        printQueue.removeAll()
        let sample = Self.makeSampleTestCard()
        addPhotoToQueue(sample, name: "Instax Square Test Card", select: true)
        statusBanner = "Cleared print queue."
    }

    func resetPrintedItemsToPending() {
        for idx in printQueue.indices {
            if printQueue[idx].status == .printed || printQueue[idx].status != .pending {
                printQueue[idx].status = .pending
            }
        }
        statusBanner = "Reset all \(printQueue.count) queued photo(s) to Pending."
    }

    func applyCurrentFramingToAllQueueItems() {
        let opts = currentImageOptions()
        let color = bgColor
        for idx in printQueue.indices {
            printQueue[idx].options = opts
            printQueue[idx].bgColor = color
            renderItem(&printQueue[idx])
        }
        isErrorBanner = false
        statusBanner = "Applied framing, filters & borders to all \(printQueue.count) photos in queue."
    }

    func resetAdjustments() {
        isLoadingSelection = true
        zoom = 1.0
        offsetX = 0.0
        offsetY = 0.0
        rotationDegrees = 0
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        bgColor = .white
        filterPreset = .none
        captionText = ""
        showDateStamp = false
        isLoadingSelection = false
        updatePreview()
    }

    func resetAnalogFX() {
        isLoadingSelection = true
        warmth = 0.0
        vignette = 0.0
        lightLeak = "none"
        leakPlacement = "auto"
        leakIntensity = 0.70
        filmGrain = 0.0
        analogWear = 0.0
        showVintageDate = false
        vintageDateText = ""
        vintageDateColor = "amber"
        vintageDatePlacement = "bottomRight"
        isLoadingSelection = false
        updatePreview()
    }

    func surpriseMeAnalogFX() {
        isLoadingSelection = true
        warmth = Double(Int.random(in: -30...60)) / 100.0
        vignette = Double(Int.random(in: 25...75)) / 100.0
        let leaks = ["none", "burn", "sunburst", "sunset", "rainbow"]
        lightLeak = leaks.randomElement() ?? "burn"
        let placements = ["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]
        leakPlacement = placements.randomElement() ?? "auto"
        leakIntensity = Double(Int.random(in: 45...90)) / 100.0
        filmGrain = Double(Int.random(in: 15...55)) / 100.0
        analogWear = Double(Int.random(in: 10...45)) / 100.0
        showVintageDate = true
        let colors = ["amber", "red", "green", "white"]
        vintageDateColor = colors.randomElement() ?? "amber"
        let datePlacements = ["bottomRight", "bottomLeft", "topRight", "topLeft"]
        vintageDatePlacement = datePlacements.randomElement() ?? "bottomRight"
        isLoadingSelection = false
        updatePreview()
    }

    func rotate90Clockwise() {
        rotationDegrees = (rotationDegrees + 90) % 360
    }

    func rotate90CounterClockwise() {
        rotationDegrees = (rotationDegrees + 270) % 360
    }

    func openFilePicker(allowMultiple: Bool = true) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .tiff, .bmp]
        panel.allowsMultipleSelection = allowMultiple
        panel.canChooseDirectories = false
        panel.title = "Select One or More Photos to Print (or Browse Media -> Photos in Sidebar)"
        panel.prompt = "Add to Print Queue"
        if panel.runModal() == .OK {
            let urls = panel.urls
            var addedCount = 0
            for (idx, url) in urls.enumerated() {
                if let img = NSImage(contentsOf: url) {
                    addPhotoToQueue(img, name: url.lastPathComponent, select: idx == urls.count - 1)
                    addedCount += 1
                }
            }
            if addedCount > 0 {
                isErrorBanner = false
                statusBanner = "Added \(addedCount) photo(s) to the print queue (\(pendingQueueCount) ready to print)."
            }
        }
    }

    func addPhotoURLsToQueue(_ urls: [URL]) {
        var addedCount = 0
        for (idx, url) in urls.enumerated() {
            if let img = NSImage(contentsOf: url) {
                addPhotoToQueue(img, name: url.lastPathComponent, select: idx == urls.count - 1)
                addedCount += 1
            }
        }
        if addedCount > 0 {
            isErrorBanner = false
            statusBanner = "Added \(addedCount) photo(s) from Apple Photos to the print queue (\(pendingQueueCount) ready)."
        }
    }

    func savePreviewToDisk() {
        guard let jpeg = compressedJPEG else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.nameFieldStringValue = "instax-square-800x800.jpg"
        panel.title = "Save 800×800 Instax Square JPEG"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try jpeg.write(to: url)
                isErrorBanner = false
                statusBanner = "Saved 800×800 JPEG (\(String(format: "%.1f", Double(jpeg.count) / 1024.0)) KB) to \(url.lastPathComponent)."
            } catch {
                isErrorBanner = true
                statusBanner = "Failed to save preview: \(error.localizedDescription)"
            }
        }
    }

    var pendingQueueCount: Int {
        printQueue.filter {
            if case .pending = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    // MARK: - Bluetooth & LED Actions

    func toggleConnection() {
        if isConnected {
            ble.disconnect()
            isConnected = false
            statusBanner = "Disconnected."
            return
        }
        connectAndRefresh()
    }

    func connectAndRefresh() {
        guard !isConnecting else { return }
        isConnecting = true
        isErrorBanner = false
        statusBanner = "Searching for \(targetDeviceName) over Bluetooth..."

        Task {
            do {
                try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                try? await ble.stopLED()
                let st = try await ble.fetchStatus()
                self.status = st
                self.isConnected = true
                self.connectedDeviceName = st.deviceName
                if st.width == 1260 || st.height == 840 || st.deviceName.uppercased().contains("WIDE") {
                    self.selectedModel = .wide
                } else if st.width == 600 || (st.height == 800 && st.width != 800) || st.deviceName.uppercased().contains("MINI") {
                    self.selectedModel = .mini
                } else if st.width == 800 {
                    self.selectedModel = .square
                }
                self.updatePreview()
                let chargeStr = st.isCharging ? "Charging ⚡️" : "\(st.batteryPercent)%"
                self.statusBanner = "Connected to \(st.deviceName) (\(self.selectedModel.shortName) • \(st.width)×\(st.height) px) — Film: \(st.filmRemaining)/10 • Battery: \(chargeStr)"
            } catch {
                self.isErrorBanner = true
                self.statusBanner = error.localizedDescription
            }
            self.isConnecting = false
        }
    }

    func refreshStatus() {
        Task {
            do {
                if !isConnected {
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    isConnected = true
                }
                let st = try await ble.fetchStatus()
                self.status = st
                if st.width == 1260 || st.height == 840 || st.deviceName.uppercased().contains("WIDE") {
                    self.selectedModel = .wide
                } else if st.width == 600 || (st.height == 800 && st.width != 800) || st.deviceName.uppercased().contains("MINI") {
                    self.selectedModel = .mini
                } else if st.width == 800 {
                    self.selectedModel = .square
                }
                self.updatePreview()
                self.isErrorBanner = false
                let chargeStr = st.isCharging ? "Charging ⚡️" : "\(st.batteryPercent)%"
                self.statusBanner = "Status updated: \(st.deviceName) (\(self.selectedModel.shortName)) — Film: \(st.filmRemaining)/10 • Battery: \(chargeStr) • Prints: \(st.totalPrints)"
            } catch {
                self.isErrorBanner = true
                self.statusBanner = error.localizedDescription
            }
        }
    }

    func flashLEDOnce() {
        Task {
            do {
                if !isConnected {
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    isConnected = true
                }
                self.isErrorBanner = false
                self.statusBanner = "Flashing rainbow LED once on \(connectedDeviceName.isEmpty ? targetDeviceName : connectedDeviceName)..."
                try await ble.flashRainbowLED()
                self.statusBanner = "Rainbow LED flash complete (LED restored to normal)."
            } catch {
                self.isErrorBanner = true
                self.statusBanner = error.localizedDescription
            }
        }
    }

    func stopLEDNow() {
        Task {
            do {
                if !isConnected {
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    isConnected = true
                }
                try await ble.stopLED()
                self.isErrorBanner = false
                self.statusBanner = "Stopped LED flashing on \(connectedDeviceName.isEmpty ? targetDeviceName : connectedDeviceName)."
            } catch {
                self.isErrorBanner = true
                self.statusBanner = error.localizedDescription
            }
        }
    }

    func ejectFilmCoverNow() {
        Task {
            do {
                if !isConnected {
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    isConnected = true
                }
                self.isErrorBanner = false
                self.statusBanner = "Sending eject command for black protective film cover (dark slide)..."
                try await ble.ejectFilmCover()
                let st = try await ble.fetchStatus()
                self.status = st
                self.statusBanner = "Black film cover ejected! Film remaining: \(st.filmRemaining)/10."
            } catch {
                self.isErrorBanner = true
                self.statusBanner = "Eject dark slide failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Single & Bulk Printing


    func printSelectedImage() {
        guard !isPrinting else { return }
        updatePreview()
        guard let jpegData = compressedJPEG else {
            isErrorBanner = true
            statusBanner = "No image ready to print."
            return
        }

        let activeID = selectedQueueID
        let activeName = sourceImageName
        let activeMode = printMode
        let runDry = isDryRun
        isPrinting = true
        isBulkPrinting = false
        isErrorBanner = false
        printProgress = 0.02
        let actionDesc = runDry ? "Testing data flow for" : "Preparing to print"
        statusBanner = "\(actionDesc) '\(activeName)' (\(activeMode.title)) to \(targetDeviceName)..."

        if let id = activeID, let idx = printQueue.firstIndex(where: { $0.id == id }) {
            printQueue[idx].status = .printing
        }

        Task {
            do {
                if !isConnected {
                    self.statusBanner = "Connecting to \(targetDeviceName)..."
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    self.isConnected = true
                }
                let finalStatus = try await ble.printJPEG(jpegData, mode: activeMode, dryRun: runDry) { stage, pct in
                    Task { @MainActor in
                        self.statusBanner = "[\(activeName)] \(stage)"
                        self.printProgress = pct
                    }
                }
                self.status = finalStatus
                if let id = activeID, let idx = self.printQueue.firstIndex(where: { $0.id == id }) {
                    self.printQueue[idx].status = runDry ? .pending : .printed
                }
                self.isErrorBanner = false
                if runDry {
                    self.statusBanner = "🧪 Dry run succeeded! Data stream verified by printer. Film remaining: \(finalStatus.filmRemaining)/10 (0 film used)"
                } else {
                    self.statusBanner = "🎉 Printed '\(activeName)'! Film remaining: \(finalStatus.filmRemaining)/10"
                }
            } catch {
                if let id = activeID, let idx = self.printQueue.firstIndex(where: { $0.id == id }) {
                    self.printQueue[idx].status = .failed(error.localizedDescription)
                }
                self.isErrorBanner = true
                let prefix = runDry ? "Dry run test failed: " : "Print failed: "
                self.statusBanner = "\(prefix)\(error.localizedDescription)"
            }
            self.isPrinting = false
        }
    }

    func bulkPrintQueue() {
        guard !isPrinting else { return }
        updatePreview()

        // Find all items that are pending or failed
        var indicesToPrint: [Int] = []
        for idx in printQueue.indices {
            switch printQueue[idx].status {
            case .pending, .failed:
                indicesToPrint.append(idx)
            case .printing, .printed:
                break
            }
        }

        if indicesToPrint.isEmpty {
            for idx in printQueue.indices {
                printQueue[idx].status = .pending
                indicesToPrint.append(idx)
            }
        }

        guard !indicesToPrint.isEmpty else {
            isErrorBanner = true
            statusBanner = "Print queue is empty. Add photos first."
            return
        }

        for idx in indicesToPrint {
            if printQueue[idx].compressedJPEG == nil {
                renderItem(&printQueue[idx])
            }
        }

        isPrinting = true
        isBulkPrinting = true
        cancelBulkRequested = false
        isErrorBanner = false
        printProgress = 0.01
        let totalToPrint = indicesToPrint.count
        bulkProgressText = "Preparing bulk print (\(totalToPrint) photos)..."
        statusBanner = bulkProgressText

        Task {
            do {
                if !isConnected {
                    self.statusBanner = "Connecting to \(targetDeviceName)..."
                    try await ble.connect(targetNameOrPrefix: targetDeviceName, timeout: 8.0)
                    self.isConnected = true
                }

                let initialStatus = try await ble.fetchStatus()
                self.status = initialStatus

                if initialStatus.isCoverOpen {
                    throw NSError(domain: "InstaxBulkPrint", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Printer film door is open. Please close the cover before bulk printing."
                    ])
                }
                if initialStatus.filmRemaining <= 0 {
                    throw NSError(domain: "InstaxBulkPrint", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "No film remaining (0/10) in printer."
                    ])
                }

                var completedCount = 0

                for (orderIdx, queueIdx) in indicesToPrint.enumerated() {
                    if cancelBulkRequested {
                        self.statusBanner = "Bulk print stopped after \(completedCount) of \(totalToPrint) photo(s)."
                        break
                    }

                    guard queueIdx < self.printQueue.count else { continue }
                    let item = self.printQueue[queueIdx]
                    guard let jpegData = item.compressedJPEG else { continue }

                    self.selectQueueItem(item.id)
                    self.printQueue[queueIdx].status = .printing
                    let stepLabel = "Photo \(orderIdx + 1) of \(totalToPrint) ('\(item.name)')"
                    self.bulkProgressText = stepLabel

                    do {
                        let updatedStatus = try await ble.printJPEG(jpegData, mode: item.options.printMode) { stage, singlePct in
                            Task { @MainActor in
                                let overall = (Double(orderIdx) + singlePct) / Double(totalToPrint)
                                self.printProgress = overall
                                self.statusBanner = "[\(orderIdx + 1)/\(totalToPrint)] \(item.name): \(stage)"
                            }
                        }
                        self.status = updatedStatus
                        self.printQueue[queueIdx].status = .printed
                        completedCount += 1

                        if orderIdx + 1 < totalToPrint && !self.cancelBulkRequested {
                            if updatedStatus.filmRemaining <= 0 {
                                self.isErrorBanner = true
                                self.statusBanner = "Paused bulk print after \(completedCount)/\(totalToPrint) photos — Film pack is now empty (0/10)! Load a new film pack and click Bulk Print to continue."
                                break
                            }
                            self.statusBanner = "[\(orderIdx + 1)/\(totalToPrint)] Cooling down 3s before printing next photo..."
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                        }
                    } catch {
                        self.printQueue[queueIdx].status = .failed(error.localizedDescription)
                        self.isErrorBanner = true
                        self.statusBanner = "Stopped bulk print on '\(item.name)': \(error.localizedDescription)"
                        break
                    }
                }

                if !self.isErrorBanner && !self.cancelBulkRequested {
                    self.printProgress = 1.0
                    self.statusBanner = "🎉 Bulk print finished! Printed \(completedCount) photo(s). Film remaining: \(self.status.filmRemaining)/10"
                }
            } catch {
                self.isErrorBanner = true
                self.statusBanner = "Bulk print error: \(error.localizedDescription)"
            }

            self.isPrinting = false
            self.isBulkPrinting = false
            self.cancelBulkRequested = false
        }
    }

    // MARK: - Apple Photos & iCloud Photos Integration (Show ALL Photos)

    func openApplePhotosPicker() {
        showPhotosSheet = true
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosAuthStatus = current

        if current == .authorized || current == .limited {
            loadPhotoAlbumsAndAssets()
        } else if current == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.photosAuthStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.loadPhotoAlbumsAndAssets()
                    }
                }
            }
        }
    }

    func loadPhotoAlbumsAndAssets() {
        var optionsList: [PhotoAlbumOption] = []

        let allCount = PHAsset.fetchAssets(with: .image, options: nil).count
        optionsList.append(PhotoAlbumOption(id: "ALL_PHOTOS", title: "All Photos / Library", count: allCount, collection: nil))

        let smartFavs = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
        if let favCol = smartFavs.firstObject {
            let favCount = PHAsset.fetchAssets(in: favCol, options: nil).count
            optionsList.append(PhotoAlbumOption(id: "FAVORITES", title: "Favorites ★", count: favCount, collection: favCol))
        }

        let smartSubtypes: [(PHAssetCollectionSubtype, String)] = [
            (.smartAlbumRecentlyAdded, "Recently Added"),
            (.smartAlbumSelfPortraits, "Selfies"),
            (.smartAlbumScreenshots, "Screenshots"),
            (.smartAlbumPanoramas, "Panoramas")
        ]
        for (subtype, title) in smartSubtypes {
            let smartCols = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            smartCols.enumerateObjects { col, _, _ in
                let cnt = PHAsset.fetchAssets(in: col, options: nil).count
                if cnt > 0 {
                    optionsList.append(PhotoAlbumOption(id: col.localIdentifier, title: title, count: cnt, collection: col))
                }
            }
        }

        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { col, _, _ in
            let title = col.localizedTitle ?? "Album"
            let cnt = PHAsset.fetchAssets(in: col, options: nil).count
            optionsList.append(PhotoAlbumOption(id: col.localIdentifier, title: title, count: cnt, collection: col))
        }

        self.photoAlbums = optionsList
        fetchAssetsForSelectedAlbum()
    }

    func fetchAssetsForSelectedAlbum() {
        guard photosAuthStatus == .authorized || photosAuthStatus == .limited else { return }

        let fetchOpts = PHFetchOptions()
        fetchOpts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !sortNewestFirst)]

        let result: PHFetchResult<PHAsset>
        if selectedAlbumID == "FAVORITES" {
            fetchOpts.predicate = NSPredicate(format: "mediaType == %d AND favorite == YES", PHAssetMediaType.image.rawValue)
            result = PHAsset.fetchAssets(with: fetchOpts)
        } else if let albumOpt = photoAlbums.first(where: { $0.id == selectedAlbumID }),
                  let col = albumOpt.collection {
            fetchOpts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            result = PHAsset.fetchAssets(in: col, options: fetchOpts)
        } else {
            fetchOpts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            result = PHAsset.fetchAssets(with: fetchOpts)
        }

        var entries: [PhotoAssetEntry] = []
        entries.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            entries.append(PhotoAssetEntry(
                id: asset.localIdentifier,
                asset: asset,
                creationDate: asset.creationDate,
                isFavorite: asset.isFavorite
            ))
        }
        self.allFetchedAssets = entries
        filterPhotoAssets()
    }

    func filterPhotoAssets() {
        let q = photosSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            self.photoAssets = allFetchedAssets
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            self.photoAssets = allFetchedAssets.filter { entry in
                if let d = entry.creationDate {
                    let dStr = df.string(from: d).lowercased()
                    if dStr.contains(q) { return true }
                    let yearStr = "\(Calendar.current.component(.year, from: d))"
                    if yearStr.contains(q) { return true }
                }
                return false
            }
        }
    }

    func requestThumbnailIfNeeded(for entry: PhotoAssetEntry) {
        guard photoThumbnails[entry.id] == nil else { return }
        let thumbOpts = PHImageRequestOptions()
        thumbOpts.isNetworkAccessAllowed = true
        thumbOpts.deliveryMode = .opportunistic
        thumbOpts.resizeMode = .fast
        imageManager.requestImage(
            for: entry.asset,
            targetSize: CGSize(width: 320, height: 320),
            contentMode: .aspectFit,
            options: thumbOpts
        ) { [weak self] img, _ in
            guard let img = img else { return }
            Task { @MainActor in
                self?.photoThumbnails[entry.id] = img
            }
        }
    }

    func togglePhotoAssetSelection(_ id: String) {
        if let idx = selectedPhotoAssetIDs.firstIndex(of: id) {
            selectedPhotoAssetIDs.remove(at: idx)
        } else {
            selectedPhotoAssetIDs.append(id)
        }
    }

    func selectAllFilteredAssets() {
        let allIDs = photoAssets.map { $0.id }
        self.selectedPhotoAssetIDs = Array(Set(selectedPhotoAssetIDs).union(allIDs))
    }

    func importSelectedPhotosFromICloud(andPrintImmediately: Bool = false) {
        let idsToImport = selectedPhotoAssetIDs
        guard !idsToImport.isEmpty else { return }

        let matchingEntries = idsToImport.compactMap { id in
            allFetchedAssets.first(where: { $0.id == id })
        }
        guard !matchingEntries.isEmpty else { return }

        isDownloadingICloudPhotos = true
        iCloudDownloadProgressText = "Downloading \(matchingEntries.count) photo(s) from Apple Photos / iCloud..."

        Task {
            var importedCount = 0
            for (idx, entry) in matchingEntries.enumerated() {
                self.iCloudDownloadProgressText = "Fetching photo \(idx + 1) of \(matchingEntries.count) from Photos / iCloud..."
                if let fullImage = await self.fetchFullResolutionImageFromICloud(asset: entry.asset, index: idx) {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HHmmss"
                    let dateStr = entry.creationDate.map { dateFormatter.string(from: $0) } ?? "\(idx + 1)"
                    let name = "Photos \(dateStr)"
                    self.addPhotoToQueue(fullImage, name: name, select: idx == matchingEntries.count - 1)
                    importedCount += 1
                }
            }

            self.isDownloadingICloudPhotos = false
            self.selectedPhotoAssetIDs.removeAll()
            self.showPhotosSheet = false

            if importedCount > 0 {
                self.isErrorBanner = false
                self.statusBanner = "Imported \(importedCount) photo(s) from Apple Photos / iCloud into Print Queue."
                if andPrintImmediately {
                    if importedCount == 1 {
                        self.printSelectedImage()
                    } else {
                        self.bulkPrintQueue()
                    }
                }
            } else {
                self.isErrorBanner = true
                self.statusBanner = "Could not load selected photo(s) from iCloud Photos."
            }
        }
    }

    private func fetchFullResolutionImageFromICloud(asset: PHAsset, index: Int) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false
            opts.progressHandler = { [weak self] progress, _, _, _ in
                Task { @MainActor in
                    let pct = Int((progress * 100.0).rounded())
                    self?.iCloudDownloadProgressText = "Downloading from iCloud (\(pct)%)..."
                }
            }

            var resumed = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, orientation, _ in
                guard !resumed else { return }
                resumed = true
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }

                // Decode and normalize EXIF orientation using CGImageSource with transform
                if let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: 4096
                   ] as CFDictionary) {
                    let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: img)
                } else if let img = NSImage(data: data) {
                    continuation.resume(returning: img)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    var dragStartOffset: CGSize = .zero
    var isDraggingCanvas: Bool = false

    static func makeSampleTestCard() -> NSImage {
        let size = NSSize(width: 800, height: 800)
        let img = NSImage(size: size)
        img.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.11, green: 0.15, blue: 0.28, alpha: 1.0),
            NSColor(srgbRed: 0.24, green: 0.14, blue: 0.36, alpha: 1.0),
            NSColor(srgbRed: 0.85, green: 0.35, blue: 0.28, alpha: 1.0)
        ])
        gradient?.draw(in: rect, angle: -45)

        NSColor.white.withAlphaComponent(0.22).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 24, yRadius: 24)
        border.lineWidth = 3
        border.stroke()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 46, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.88)
        ]

        let title = "instax SQUARE Link" as NSString
        let tSize = title.size(withAttributes: titleAttrs)
        title.draw(at: NSPoint(x: (800 - tSize.width) / 2, y: 430), withAttributes: titleAttrs)

        let sub = "800 × 800 px • Collage & Creative Filters Ready" as NSString
        let sSize = sub.size(withAttributes: subAttrs)
        sub.draw(at: NSPoint(x: (800 - sSize.width) / 2, y: 375), withAttributes: subAttrs)

        img.unlockFocus()
        return img
    }
}

// MARK: - Main Window View

struct InstaxMainView: View {
    @ObservedObject var vm: InstaxAppViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ScrollView([.vertical, .horizontal], showsIndicators: false) {
                        previewWorkspace
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    bulkQueueStrip
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                controlsSidebar
                    .frame(width: 445)
            }

            Divider()
            footerStatusBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 1220, idealWidth: 1300, maxWidth: .infinity, minHeight: 840, idealHeight: 900, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .sheet(isPresented: $vm.showPhotosSheet) {
            PhotosLibrarySheetView(vm: vm)
        }
        .sheet(isPresented: $vm.showDebugConsole) {
            DebugConsoleSheetView(vm: vm)
        }
        .sheet(isPresented: $vm.showCustomPrinterSheet) {
            CustomPrinterEntrySheet(vm: vm)
        }
        .sheet(isPresented: $vm.showHelpSheet) {
            HelpGuideSheetView(vm: vm)
        }
    }

    // MARK: Top Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isConnected ? Color.green : (vm.isConnecting ? Color.orange : Color.secondary.opacity(0.5)))
                    .frame(width: 10, height: 10)
                Text(vm.isConnected && !vm.connectedDeviceName.isEmpty ? vm.connectedDeviceName : vm.selectedModel.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Model format toggle (SQUARE / WIDE / MINI)
            Picker("Format", selection: $vm.selectedModel) {
                ForEach(InstaxPrinterModel.allCases) { m in
                    Text(m.shortName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)
            .fixedSize(horizontal: true, vertical: false)
            .help("Switch between Instax SQUARE (800×800), WIDE (1260×840), and MINI (600×800)")

            // Multi-Printer Dropdown / Selection List
            Menu {
                // Section 1: Discovered Nearby Printers
                Section("Discovered Nearby (\(vm.discoveredPrinters.count))") {
                    if vm.discoveredPrinters.isEmpty {
                        Text(vm.isScanningPrinters ? "Scanning nearby Bluetooth..." : "No printers in range")
                    } else {
                        ForEach(vm.discoveredPrinters) { p in
                            Button {
                                vm.selectPrinterAndConnect(p.name)
                            } label: {
                                HStack {
                                    if vm.targetDeviceName == p.name {
                                        Text("✓ \(p.name)")
                                    } else {
                                        Text(p.name)
                                    }
                                    Spacer()
                                    Text("(\(p.rssi) dBm • \(vm.rssiStrength(p.rssi)))")
                                }
                            }
                        }
                    }
                }

                // Section 2: Saved / Recent Printers
                Section("Saved & Recent Printers") {
                    ForEach(vm.savedPrinters, id: \.self) { name in
                        Button {
                            vm.selectPrinterAndConnect(name)
                        } label: {
                            HStack {
                                if vm.targetDeviceName == name {
                                    Text("✓ \(name)")
                                } else {
                                    Text(name)
                                }
                            }
                        }
                    }
                }

                Divider()

                Button {
                    vm.scanForNearbyPrinters()
                } label: {
                    Label(vm.isScanningPrinters ? "Scanning Nearby..." : "Scan for Nearby Printers", systemImage: "arrow.clockwise")
                }

                Button {
                    vm.customPrinterInput = vm.targetDeviceName
                    vm.showCustomPrinterSheet = true
                } label: {
                    Label("Enter Custom Printer Name...", systemImage: "pencil")
                }

                if vm.isConnected {
                    Divider()
                    Button(role: .destructive) {
                        vm.disconnectPrinter()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.isConnected ? "printer.fill" : "printer")
                        .foregroundColor(vm.isConnected ? .green : .secondary)
                    Text(vm.targetDeviceName.isEmpty ? "Select Printer..." : vm.targetDeviceName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
            }
            .fixedSize(horizontal: true, vertical: false)
            .help("Select from discovered nearby Instax printers, saved devices, or custom entry")

            Button(action: { vm.toggleConnection() }) {
                Label(
                    vm.isConnected ? "Disconnect" : (vm.isConnecting ? "Connecting..." : "Connect"),
                    systemImage: vm.isConnected ? "personalhotspot.slash" : "dot.radiowaves.left.and.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isConnected ? .gray : .blue)
            .controlSize(.regular)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(vm.isConnecting || vm.isPrinting)

            Button(action: { vm.refreshStatus() }) {
                Label("Status", systemImage: "arrow.clockwise")
            }
            .controlSize(.regular)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(vm.isConnecting || vm.isPrinting)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button(action: { vm.flashLEDOnce() }) {
                        Label("Flash LED", systemImage: "sparkles")
                    }
                    .controlSize(.regular)
                    .help("Flash the printer's front LED once and auto-stop")
                    .disabled(vm.isConnecting || vm.isPrinting)

                    Button(action: { vm.stopLEDNow() }) {
                        Label("Stop LED", systemImage: "lightbulb.slash")
                    }
                    .controlSize(.regular)
                    .help("Immediately stop any continuous LED flashing on the printer")
                    .disabled(vm.isConnecting || vm.isPrinting)

                    Button(action: { vm.ejectFilmCoverNow() }) {
                        Label("Eject Cover", systemImage: "eject.circle")
                    }
                    .controlSize(.regular)
                    .help("Eject the black protective plastic dark slide from a newly loaded film pack")
                    .disabled(vm.isConnecting || vm.isPrinting)

                    Button(action: { vm.showHelpSheet = true }) {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .controlSize(.regular)
                    .help("Open User Guide & Printing Help (⌘?)")
                }

                Menu {
                    Button { vm.flashLEDOnce() } label: { Label("Flash LED Once", systemImage: "sparkles") }
                    Button { vm.stopLEDNow() } label: { Label("Stop LED", systemImage: "lightbulb.slash") }
                    Button { vm.ejectFilmCoverNow() } label: { Label("Eject Film Cover", systemImage: "eject.circle") }
                    Divider()
                    Button { vm.showHelpSheet = true } label: { Label("Help Guide (⌘?)", systemImage: "questionmark.circle") }
                } label: {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
                .controlSize(.regular)
                .disabled(vm.isConnecting || vm.isPrinting)
            }

            Spacer(minLength: 12)

            // Live Film & Battery Badges (Locked Layout - Never Squeezed)
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .foregroundColor(.accentColor)
                    Text("Film: \(vm.isConnected ? "\(vm.status.filmRemaining)/10" : "—/10")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)

                HStack(spacing: 6) {
                    Image(systemName: vm.status.isCharging ? "battery.100.bolt" : "battery.75")
                        .foregroundColor(vm.status.isCharging ? .green : .primary)
                    Text(
                        vm.isConnected
                            ? "\(vm.status.batteryPercent)% \(vm.status.isCharging ? "(Charging)" : "")"
                            : "—"
                    )
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Center Print Preview Canvas (True 1:1 Print Exposure)

    private var previewWorkspace: some View {
        ZStack {
            Color(NSColor.underPageBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                // True Print Canvas (auto-adapting: 800x800 for Square, 1260x840 for Wide, 600x800 for Mini)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: vm.fitMode == .fit ? NSColor(vm.bgColor) : .black))
                        .frame(width: vm.selectedModel.previewWidth, height: vm.selectedModel.previewHeight)
                        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)

                    if let preview = vm.renderedPreview {
                        Image(nsImage: preview)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: vm.selectedModel.previewWidth, height: vm.selectedModel.previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if !vm.isDraggingCanvas {
                                            vm.isDraggingCanvas = true
                                            vm.dragStartOffset = CGSize(width: vm.offsetX, height: vm.offsetY)
                                        }
                                        let dx = Double(value.translation.width) / (Double(vm.selectedModel.previewWidth) / 2.0)
                                        let dy = Double(value.translation.height) / (Double(vm.selectedModel.previewHeight) / 2.0)
                                        vm.offsetX = max(-1.5, min(1.5, Double(vm.dragStartOffset.width) + dx))
                                        vm.offsetY = max(-1.5, min(1.5, Double(vm.dragStartOffset.height) + dy))
                                    }
                                    .onEnded { _ in
                                        vm.isDraggingCanvas = false
                                    }
                            )
                    }

                    // Subtle border outline
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        .frame(width: vm.selectedModel.previewWidth, height: vm.selectedModel.previewHeight)
                        .allowsHitTesting(false)
                }

                // Quick Action Toolbar directly beneath preview
                HStack(spacing: 8) {
                    Button(action: { vm.openApplePhotosPicker() }) {
                        Label("Photos...", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .help("Browse Apple Photos / iCloud Library (⌘ Shift I)")

                    Button(action: { vm.openFilePicker(allowMultiple: true) }) {
                        Label("Files...", systemImage: "folder.badge.plus")
                    }
                    .help("Add photos from Finder (⌘O)")

                    Button(action: { vm.rotate90CounterClockwise() }) {
                        Label("↺ 90°", systemImage: "rotate.left")
                    }
                    .help("Rotate 90° Counter-Clockwise")

                    Button(action: { vm.rotate90Clockwise() }) {
                        Label("↻ 90°", systemImage: "rotate.right")
                    }
                    .help("Rotate 90° Clockwise")

                    Button(action: { vm.resetAdjustments() }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .help("Center photo and reset zoom and rotation")

                    Button(action: { vm.savePreviewToDisk() }) {
                        Label("Save JPEG...", systemImage: "square.and.arrow.down")
                    }
                    .help("Save rendered preview to disk (⌘S)")
                }
                .controlSize(.regular)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

                // Info pill beneath toolbar
                HStack(spacing: 12) {
                    Text("\(vm.effectiveWidth) × \(vm.effectiveHeight) px (\(vm.selectedModel.shortName) Print)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(vm.printMode == .rich ? "🌈 instax-Rich" : "📷 instax-Natural (3D-LUT)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(vm.printMode == .rich ? .blue : .purple)
                    if vm.filterPreset != .none {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Filter: \(vm.filterPreset.title)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    if let jpeg = vm.compressedJPEG {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("JPEG: \(String(format: "%.1f", Double(jpeg.count) / 1024.0)) KB")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(12)

                Text("Drag photo to pan • Physical \(vm.selectedModel.shortName) film borders are provided by the film cartridge")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }

    // MARK: Bottom Bulk Print Queue Strip

    private var bulkQueueStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Queue (\(vm.printQueue.count) Photos\(vm.pendingQueueCount > 0 ? " • \(vm.pendingQueueCount) Pending" : ""))", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .fixedSize()

                Spacer()

                Menu {
                    Section("2 Photos") {
                        Button("2-Split (Left / Right)") { vm.createCollageFromQueue(layout: .split2V) }
                        Button("2-Split (Top / Bottom)") { vm.createCollageFromQueue(layout: .split2H) }
                    }
                    Section("3 Photos") {
                        Button("3-Split (Hero Left + 2 Stacked)") { vm.createCollageFromQueue(layout: .split3Hero) }
                        Button("3-Stripes (Vertical WIDE)") { vm.createCollageFromQueue(layout: .split3V) }
                        Button("3-Split (Hero Top + 2 Bottom)") { vm.createCollageFromQueue(layout: .split3H) }
                    }
                    Section("4 Photos") {
                        Button("4-Grid (2 × 2 Collage)") { vm.createCollageFromQueue(layout: .grid4) }
                        Button("4-Stripes (Photo Booth WIDE)") { vm.createCollageFromQueue(layout: .strips4V) }
                    }
                    Section("6 to 9 Photos (WIDE & Multi)") {
                        Button("6-Grid (3 × 2 WIDE)") { vm.createCollageFromQueue(layout: .grid6) }
                        Button("8-Grid (4 × 2 WIDE)") { vm.createCollageFromQueue(layout: .grid8) }
                        Button("9-Grid (3 × 3)") { vm.createCollageFromQueue(layout: .grid9) }
                    }
                } label: {
                    Label("Create Collage", systemImage: "square.grid.2x2.fill")
                }
                .controlSize(.small)
                .disabled(vm.printQueue.count < 2)
                .help("Combine queued photos into a multi-photo collage print (Square, WIDE, or Mini)")

                Button(action: { vm.openApplePhotosPicker() }) {
                    Label("+ iCloud Photos", systemImage: "photo.badge.plus")
                }
                .controlSize(.small)

                Button(action: { vm.openFilePicker(allowMultiple: true) }) {
                    Label("+ Add Files", systemImage: "plus.rectangle.on.rectangle")
                }
                .controlSize(.small)

                Menu {
                    if let selID = vm.selectedQueueID {
                        Button(action: { vm.duplicateQueueItem(selID) }) {
                            Label("Duplicate Selected Photo", systemImage: "plus.square.on.square")
                        }
                    }
                    if vm.printQueue.count > 1 {
                        Button("Apply Current Framing to All") {
                            vm.applyCurrentFramingToAllQueueItems()
                        }
                    }
                    if vm.printQueue.contains(where: { $0.status == .printed }) {
                        Button("Clear Printed Photos") {
                            vm.clearPrintedFromQueue()
                        }
                    }
                    if vm.printQueue.count > 1 {
                        Divider()
                        Button(role: .destructive, action: { vm.clearEntireQueue() }) {
                            Label("Clear Entire Queue", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Queue Actions", systemImage: "ellipsis.circle")
                }
                .controlSize(.small)
                .disabled(vm.isPrinting || vm.printQueue.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(Array(vm.printQueue.enumerated()), id: \.element.id) { idx, item in
                        let isSelected = (vm.selectedQueueID == item.id)
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                if let thumb = item.renderedPreview ?? Optional(item.sourceImage) {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 82, height: 82)
                                        .clipped()
                                        .cornerRadius(6)
                                }

                                // Queue number badge (top-left)
                                VStack {
                                    HStack {
                                        Text("#\(idx + 1)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.65))
                                            .cornerRadius(4)
                                        Spacer()
                                        if !vm.isPrinting {
                                            Button(action: { vm.removeQueueItem(item.id) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                            .buttonStyle(.plain)
                                            .help("Remove from queue")
                                        }
                                    }
                                    Spacer()
                                    // Status pill at bottom of thumbnail
                                    Text(item.status.badgeText)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(item.status.badgeColor.opacity(0.92))
                                        .cornerRadius(4)
                                        .padding(.bottom, 3)
                                }
                                .padding(3)
                                .frame(width: 82, height: 82)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                            )

                            Text(item.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .frame(width: 86)
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
                        )
                        .onTapGesture {
                            vm.selectQueueItem(item.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            .frame(height: 126)
            .padding(.bottom, 4)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Right Controls Sidebar (Tabbed & Unclipped Layout)

    private var controlsSidebar: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("Section", selection: $vm.selectedTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.tabLabel).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch vm.selectedTab {
                    case .framing:
                        framingTabContent
                    case .color:
                        colorAndFiltersTabContent
                    case .analogFX:
                        analogFXTabContent
                    case .collage:
                        collageTabContent
                    case .qrOverlay:
                        qrAndTextTabContent
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 20)
                .padding(.vertical, 12)
            }

            Divider()

            // Bottom Print Actions
            VStack(spacing: 8) {
                if vm.isPrinting {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: vm.printProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        Text("\(Int((vm.printProgress * 100).rounded()))% — \(vm.statusBanner)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if vm.isBulkPrinting {
                            Button(role: .destructive, action: { vm.cancelBulkRequested = true }) {
                                Label(
                                    vm.cancelBulkRequested ? "Stopping after current..." : "Stop Bulk Print",
                                    systemImage: "stop.circle.fill"
                                )
                            }
                            .controlSize(.small)
                            .disabled(vm.cancelBulkRequested)
                        }
                    }
                    .padding(.bottom, 4)
                }

                // Dry Run Mode Toggle
                Toggle(isOn: $vm.isDryRun) {
                    HStack(spacing: 5) {
                        Image(systemName: vm.isDryRun ? "bolt.badge.checkmark.fill" : "bolt.badge.checkmark")
                            .foregroundColor(vm.isDryRun ? .indigo : .secondary)
                        Text("Dry Run (Test Data Flow — 0 Film)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(vm.isDryRun ? .indigo : .primary)
                    }
                }
                .toggleStyle(.checkbox)
                .help("Streams 100% of image packets over Bluetooth to verify link, framing, and printer ASIC buffer without exposing or ejecting film.")
                .padding(.bottom, 2)

                Button(action: { vm.printSelectedImage() }) {
                    HStack {
                        Spacer()
                        Image(systemName: vm.isDryRun ? "bolt.badge.checkmark" : "printer.fill")
                        Text(vm.isPrinting && !vm.isBulkPrinting
                             ? (vm.isDryRun ? "Testing Data Flow..." : "Printing Photo...")
                             : (vm.isDryRun ? "Test Transfer (Dry Run — 0 Film)" : "Print Selected Photo"))
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isDryRun ? .indigo : .accentColor)
                .controlSize(.regular)
                .disabled(vm.isPrinting)

                Button(action: { vm.bulkPrintQueue() }) {
                    HStack {
                        Spacer()
                        Image(systemName: "square.stack.3d.up.fill")
                        let count = vm.pendingQueueCount > 0 ? vm.pendingQueueCount : vm.printQueue.count
                        Text(vm.isBulkPrinting ? "Bulk Printing..." : "Bulk Print Queue (\(count) Photos)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
                .disabled(vm.isPrinting || vm.printQueue.isEmpty || vm.isDryRun)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Sidebar Tabs

    private var framingTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Square Framing", systemImage: "crop")) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Fit Mode", selection: $vm.fitMode) {
                        ForEach(InstaxFitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if vm.fitMode == .fit {
                        HStack {
                            Text("Letterbox Matte:")
                                .font(.caption)
                            ColorPicker("", selection: $vm.bgColor, supportsOpacity: false)
                                .labelsHidden()
                            Button("White") { vm.bgColor = .white }.controlSize(.mini)
                            Button("Black") { vm.bgColor = .black }.controlSize(.mini)
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Zoom")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f×", vm.zoom))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.zoom, in: 0.4...3.0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Horizontal Pan")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%+.2f", vm.offsetX))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.offsetX, in: -1.0...1.0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Vertical Pan")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%+.2f", vm.offsetY))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.offsetY, in: -1.0...1.0)
                    }

                    HStack {
                        Button("Rotate 90°") { vm.rotate90Clockwise() }.controlSize(.small)
                        Spacer()
                        Button("Reset Framing") { vm.resetAdjustments() }.controlSize(.small)
                    }
                }
                .padding(8)
            }
        }
    }

    private var colorAndFiltersTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Instax Film Profile (3D-LUT)", systemImage: "camera.filters")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Profile", selection: $vm.printMode) {
                        Text("🌈 instax-Rich").tag(InstaxPrintMode.rich)
                        Text("📷 instax-Natural").tag(InstaxPrintMode.natural)
                    }
                    .pickerStyle(.segmented)

                    if vm.printMode == .rich {
                        Text("• Rich Mode: Deep vibrant colors with modern contrast.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("• Natural Mode: Soft vintage analog tones via printer 3D-LUT.")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Artistic Filters", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Filter", selection: $vm.filterPreset) {
                        ForEach(InstaxFilterPreset.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Selected filter is rendered in real-time and applied to the 800×800 instant print.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(label: Label("Image Adjustments", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Brightness")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%+.2f", vm.brightness))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.brightness, in: -0.35...0.35)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Contrast")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f×", vm.contrast))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.contrast, in: 0.6...1.6)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Saturation")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f×", vm.saturation))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.saturation, in: 0.0...1.8)
                    }

                    HStack {
                        Spacer()
                        Button("Reset Adjustments") {
                            vm.brightness = 0.0
                            vm.contrast = 1.0
                            vm.saturation = 1.0
                            vm.filterPreset = .none
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
            }
        }
    }

    private var analogFXTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Analog Warmth & Temperature", systemImage: "thermometer.sun.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Warmth Dial")
                            .font(.caption)
                        Spacer()
                        Text(
                            vm.warmth > 0 ? String(format: "+%.2f (Amber)", vm.warmth) :
                            vm.warmth < 0 ? String(format: "%.2f (Cool)", vm.warmth) : "0.00 (Neutral)"
                        )
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                    }
                    Slider(value: $vm.warmth, in: -1.0...1.0)
                    Text("Organic color shift between cool Arctic cyan (-1.0) and golden California amber (+1.0).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(label: Label("Lens Vignette Falloff", systemImage: "circle.circle")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Vignette Intensity")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(vm.vignette * 100))%")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    Slider(value: $vm.vignette, in: 0.0...1.0)
                    Text("Optical barrel light falloff naturally darkens corners like classic wide-angle lenses.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(label: Label("Analog Light Leaks", systemImage: "sun.haze.fill")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Leak Type", selection: $vm.lightLeak) {
                        Text("None").tag("none")
                        Text("🔥 Film Burn (Golden Red)").tag("burn")
                        Text("☀️ Sunburst Flare (Amber)").tag("sunburst")
                        Text("🌅 Sunset Glow (Magenta)").tag("sunset")
                        Text("🌈 Rainbow Prism").tag("rainbow")
                    }
                    .pickerStyle(.menu)

                    if vm.lightLeak != "none" {
                        Picker("Placement", selection: $vm.leakPlacement) {
                            Text("🎲 Auto (Organic)").tag("auto")
                            Text("Left Edge").tag("left")
                            Text("Right Edge").tag("right")
                            Text("Top Right Corner").tag("topRight")
                            Text("Top Left Corner").tag("topLeft")
                            Text("Bottom Left Streak").tag("bottomLeft")
                            Text("Bottom Right Corner").tag("bottomRight")
                            Text("Diagonal Across").tag("diagonal")
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Intensity")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(vm.leakIntensity * 100))%")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(4)
                            }
                            Slider(value: $vm.leakIntensity, in: 0.1...1.0)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Film Grain & Analog Wear", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tactile Silver Halide Grain")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(vm.filmGrain * 100))%")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.filmGrain, in: 0.0...1.0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Analog Wear, Scratches & Dust")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(vm.analogWear * 100))%")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        Slider(value: $vm.analogWear, in: 0.0...1.0)
                    }

                    Text("Generates curved bezier hair fibers, hairline surface scratches, dust motes & chemical roller spread.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(label: Label("Vintage Glowing LED Date Stamp", systemImage: "clock.badge.checkmark")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable LED Date Stamp", isOn: $vm.showVintageDate)

                    if vm.showVintageDate {
                        TextField("Date Text (Empty = Today ''YY MM DD)", text: $vm.vintageDateText)
                            .textFieldStyle(.roundedBorder)

                        Picker("LED Color", selection: $vm.vintageDateColor) {
                            Text("🟠 Amber Gold").tag("amber")
                            Text("🔴 Retro Red").tag("red")
                            Text("🟢 Matrix Green").tag("green")
                            Text("⚪ Cool White").tag("white")
                        }
                        .pickerStyle(.menu)

                        Picker("Placement", selection: $vm.vintageDatePlacement) {
                            Text("Bottom Right").tag("bottomRight")
                            Text("Bottom Left").tag("bottomLeft")
                            Text("Top Right").tag("topRight")
                            Text("Top Left").tag("topLeft")
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(8)
            }

            HStack {
                Button(action: { vm.surpriseMeAnalogFX() }) {
                    Label("🎲 Surprise Me!", systemImage: "sparkles")
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

    private var collageTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Multi-Photo Collage Studio", systemImage: "square.grid.2x2.fill")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header Status Banner
                    if let sel = vm.selectedQueueItem, sel.isCollage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active Collage: \(vm.activeCollageLayout.title)")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Click any layout or adjust spacing slider below for live update.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("New from Queue") {
                                vm.createBrandNewCollageFromQueue(layout: .grid4)
                            }
                            .controlSize(.mini)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                    } else {
                        Text("Select a layout to combine queued photos into a native \(vm.selectedModel.title) collage (\(vm.effectiveWidth) × \(vm.effectiveHeight) px):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Layout Selector with Visual Buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2 PHOTOS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            collageLayoutButton(.split2V, title: "2-Split (Left / Right)", photos: 2)
                            collageLayoutButton(.split2H, title: "2-Split (Top / Bottom)", photos: 2)
                        }

                        Text("3 PHOTOS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        HStack(spacing: 6) {
                            collageLayoutButton(.split3Hero, title: "Hero Left + 2", photos: 3)
                            collageLayoutButton(.split3V, title: "3-Stripes (WIDE)", photos: 3)
                        }
                        collageLayoutButton(.split3H, title: "Hero Top + 2 Bottom", photos: 3)

                        Text("4 PHOTOS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        HStack(spacing: 6) {
                            collageLayoutButton(.grid4, title: "4-Grid (2 × 2)", photos: 4)
                            collageLayoutButton(.strips4V, title: "4-Stripes (Booth)", photos: 4)
                        }

                        Text("6 TO 9 PHOTOS (WIDE & MULTI)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        HStack(spacing: 6) {
                            collageLayoutButton(.grid6, title: "6-Grid (3 × 2)", photos: 6)
                            collageLayoutButton(.grid8, title: "8-Grid (4 × 2)", photos: 8)
                        }
                        collageLayoutButton(.grid9, title: "9-Grid (3 × 3 Poster)", photos: 9)
                    }

                    Divider()

                    // Spacing Slider with Quick Pills
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Border Spacing")
                                .font(.caption.bold())
                            Spacer()
                            Text("\(Int(vm.collageSpacing)) px")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundColor(.accentColor)
                        }

                        HStack(spacing: 4) {
                            Button("Flush (0)") { vm.collageSpacing = 0; vm.updatePreview() }
                                .controlSize(.mini)
                            Button("Thin (6)") { vm.collageSpacing = 6; vm.updatePreview() }
                                .controlSize(.mini)
                            Button("Medium (12)") { vm.collageSpacing = 12; vm.updatePreview() }
                                .controlSize(.mini)
                            Button("Thick (20)") { vm.collageSpacing = 20; vm.updatePreview() }
                                .controlSize(.mini)
                            Button("Wide (28)") { vm.collageSpacing = 28; vm.updatePreview() }
                                .controlSize(.mini)
                        }

                        Slider(value: $vm.collageSpacing, in: 0...36, step: 2)
                            .onChange(of: vm.collageSpacing) { _ in
                                vm.updatePreview()
                            }
                    }

                    Divider()

                    // Border Color
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Collage Border & Matte Color")
                            .font(.caption.bold())
                        Picker("", selection: $vm.borderColor) {
                            ForEach(InstaxBorderColor.allCases) { col in
                                Text(col.title).tag(col)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.borderColor) { _ in
                            vm.updatePreview()
                        }
                    }

                    if vm.printQueue.count < 2 {
                        Text("💡 Add at least 2 photos into the queue below to activate collage layouts.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
            }
        }
    }

    private func collageLayoutButton(_ layout: InstaxCollageLayout, title: String, photos: Int) -> some View {
        let isSelected = (vm.selectedQueueItem?.isCollage == true && vm.activeCollageLayout == layout)
        let canCreate = vm.printQueue.count >= photos

        return Button {
            vm.createCollageFromQueue(layout: layout)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: layout.icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .foregroundColor(isSelected ? .accentColor : (canCreate ? .primary : .secondary))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
    }

    private var qrAndTextTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Rich QR Code (Instax QR Print)", systemImage: "qrcode")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Status Badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(vm.qrCodeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.secondary.opacity(0.4)
                                  : Color.green)
                            .frame(width: 8, height: 8)
                        Text(vm.qrCodeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "QR Code: Off / Inactive"
                             : "Active on Print (\(vm.qrCodePosition.title))")
                            .font(.caption.bold())
                            .foregroundColor(vm.qrCodeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                        Spacer()
                        if !vm.qrCodeContent.isEmpty {
                            Button("Clear") {
                                vm.qrCodeContent = ""
                                vm.updatePreview()
                            }
                            .controlSize(.mini)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)

                    // Presets
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Presets")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        HStack(spacing: 5) {
                            Button("🌐 Web URL") {
                                vm.qrCodeContent = "https://instagram.com/"
                                vm.updatePreview()
                            }
                            .controlSize(.mini)

                            Button("📍 Location") {
                                vm.qrCodeContent = "https://maps.apple.com/?q=Tokyo"
                                vm.updatePreview()
                            }
                            .controlSize(.mini)

                            Button("📞 Phone") {
                                vm.qrCodeContent = "tel:+1"
                                vm.updatePreview()
                            }
                            .controlSize(.mini)

                            Button("💬 Secret Note") {
                                vm.qrCodeContent = "❤️ A special memory captured on Instax!"
                                vm.updatePreview()
                            }
                            .controlSize(.mini)
                        }
                    }

                    // Content Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QR Content (Link, Message, Phone, Map)")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        TextField("Enter link, secret message, or number...", text: $vm.qrCodeContent)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: vm.qrCodeContent) { _ in
                                vm.updatePreview()
                            }
                    }

                    // Position, Size, and Style - ALWAYS VISIBLE
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Position")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            Picker("", selection: $vm.qrCodePosition) {
                                ForEach(InstaxQRPosition.allCases) { pos in
                                    Text(pos.title).tag(pos)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: vm.qrCodePosition) { _ in
                                vm.updatePreview()
                            }
                        }

                        HStack {
                            Text("Size")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            Picker("", selection: $vm.qrCodeSize) {
                                ForEach(InstaxQRSize.allCases) { sz in
                                    Text(sz.title).tag(sz)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.qrCodeSize) { _ in
                                vm.updatePreview()
                            }
                        }

                        HStack {
                            Text("Style")
                                .font(.caption)
                                .frame(width: 50, alignment: .leading)
                            Picker("", selection: $vm.qrCodeStyle) {
                                ForEach(InstaxQRStyle.allCases) { st in
                                    Text(st.shortTitle).tag(st)
                                        .help(st.title)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.qrCodeStyle) { _ in
                                vm.updatePreview()
                            }
                        }
                    }
                    .padding(.top, 4)

                    Text("💡 Scannable by any smartphone camera. Rendered crisp at hardware print DPI.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }

            GroupBox(label: Label("Date & Caption Overlay", systemImage: "character.textbox")) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Caption overlay (e.g. Kyoto 2026)...", text: $vm.captionText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: vm.captionText) { _ in
                            vm.updatePreview()
                        }

                    Toggle("Stamp Today's Date", isOn: $vm.showDateStamp)
                        .font(.caption)
                        .onChange(of: vm.showDateStamp) { _ in
                            vm.updatePreview()
                        }

                    if !vm.captionText.isEmpty {
                        Button("Clear Caption") {
                            vm.captionText = ""
                            vm.updatePreview()
                        }
                        .controlSize(.mini)
                    }
                }
                .padding(10)
            }
        }
    }

    // MARK: Bottom Status Bar

    private var footerStatusBar: some View {
        HStack(spacing: 12) {
            Image(systemName: vm.isErrorBanner ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundColor(vm.isErrorBanner ? .red : .accentColor)
            Text(vm.statusBanner)
                .font(.system(size: 12))
                .foregroundColor(vm.isErrorBanner ? .red : .primary)
                .lineLimit(2)

            Spacer()

            Button {
                vm.showDebugConsole = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "terminal.fill")
                    Text("Protocol Debug Console")
                    if !vm.logEntries.isEmpty {
                        Text("\(vm.logEntries.count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open real-time BLE protocol trace, command logging and hardware diagnostics (⌘D)")

            Button {
                vm.showHelpSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                    Text("Help")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open User Guide & Printing Help (⌘?)")

            Text(vm.bluetoothStateText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let img = NSImage(contentsOf: url) {
                        Task { @MainActor in
                            vm.addPhotoToQueue(img, name: url.lastPathComponent, select: true)
                            vm.statusBanner = "Added '\(url.lastPathComponent)' to print queue (\(vm.printQueue.count) total)."
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let img = image as? NSImage {
                        Task { @MainActor in
                            vm.addPhotoToQueue(img, name: "Apple Photos Image", select: true)
                            vm.statusBanner = "Added photo from Apple Photos to print queue (\(vm.printQueue.count) total)."
                        }
                    }
                }
            }
        }
        return handled
    }
}

// MARK: - Apple Photos & iCloud Library Picker Sheet (Shows ALL Photos)

struct PhotosLibrarySheetView: View {
    @ObservedObject var vm: InstaxAppViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 125, maximum: 160), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Top Header Bar
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Apple Photos & iCloud Library")
                            .font(.system(size: 16, weight: .bold))
                        Text("(\(vm.photoAssets.count) visible)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text("Browse your entire library. Photos stored in iCloud are automatically downloaded in full resolution when selected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Close") {
                    vm.showPhotosSheet = false
                }
                .controlSize(.regular)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Filter & Search Controls Bar
            HStack(spacing: 12) {
                if !vm.photoAlbums.isEmpty {
                    Picker("Album:", selection: $vm.selectedAlbumID) {
                        ForEach(vm.photoAlbums) { album in
                            Text("\(album.title) (\(album.count))").tag(album.id)
                        }
                    }
                    .frame(width: 270)
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by year or date (e.g. 2024, May)...", text: $vm.photosSearchQuery)
                        .textFieldStyle(.plain)
                    if !vm.photosSearchQuery.isEmpty {
                        Button(action: { vm.photosSearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Button(action: { vm.sortNewestFirst.toggle() }) {
                    Label(
                        vm.sortNewestFirst ? "Newest First" : "Oldest First",
                        systemImage: vm.sortNewestFirst ? "arrow.down" : "arrow.up"
                    )
                }
                .controlSize(.small)

                if !vm.photoAssets.isEmpty {
                    Button("Select All Visible") {
                        vm.selectAllFilteredAssets()
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main Content: Grid of ALL Photos
            if vm.photosAuthStatus == .authorized || vm.photosAuthStatus == .limited {
                if vm.photoAssets.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(vm.photosSearchQuery.isEmpty ? "No photos found in this album." : "No photos matching '\(vm.photosSearchQuery)'")
                            .font(.headline)
                        Button("Open macOS File / Media Browser...") {
                            vm.showPhotosSheet = false
                            vm.openFilePicker(allowMultiple: true)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(vm.photoAssets) { entry in
                                let selIndex = vm.selectedPhotoAssetIDs.firstIndex(of: entry.id)
                                let isSelected = (selIndex != nil)

                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.10))
                                        .aspectRatio(1.0, contentMode: .fit)

                                    if let thumb = vm.photoThumbnails[entry.id] {
                                        Image(nsImage: thumb)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .padding(4)
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }

                                    // Top Badges: Favorite Heart & Selection Checkmark
                                    HStack {
                                        if entry.isFavorite {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.pink)
                                                .padding(4)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        Spacer()
                                        if let order = selIndex {
                                            Text("\(order + 1)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(Color.indigo))
                                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                        } else {
                                            Circle()
                                                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                                                .background(Circle().fill(Color.black.opacity(0.35)))
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                                    .padding(5)
                                }
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.indigo : Color.clear, lineWidth: 3.5)
                                )
                                .onTapGesture {
                                    vm.togglePhotoAssetSelection(entry.id)
                                }
                                .onAppear {
                                    vm.requestThumbnailIfNeeded(for: entry)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.system(size: 46))
                        .foregroundColor(.indigo)
                    Text("Allow Access to Apple Photos / iCloud")
                        .font(.headline)
                    Text("To browse your Photos & iCloud library directly inside Instax Printer, grant Photos access in System Settings -> Privacy & Security -> Photos, or use the macOS Media Browser below.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)

                    HStack(spacing: 12) {
                        Button("Open Privacy Settings...") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Use macOS File / Media Browser...") {
                            vm.showPhotosSheet = false
                            vm.openFilePicker(allowMultiple: true)
                        }
                    }
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Sheet Bottom Action Bar
            HStack(spacing: 12) {
                if vm.isDownloadingICloudPhotos {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(vm.iCloudDownloadProgressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(vm.selectedPhotoAssetIDs.count) photo(s) selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    if !vm.selectedPhotoAssetIDs.isEmpty {
                        Button("Clear Selection") {
                            vm.selectedPhotoAssetIDs.removeAll()
                        }
                        .controlSize(.small)
                    }
                }

                Spacer()

                Button("Add Selected to Queue (\(vm.selectedPhotoAssetIDs.count))") {
                    vm.importSelectedPhotosFromICloud(andPrintImmediately: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(vm.selectedPhotoAssetIDs.isEmpty || vm.isDownloadingICloudPhotos)

                Button("Print Selected Direct (\(vm.selectedPhotoAssetIDs.count))") {
                    vm.importSelectedPhotosFromICloud(andPrintImmediately: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(vm.selectedPhotoAssetIDs.isEmpty || vm.isDownloadingICloudPhotos || vm.isPrinting)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 840, minHeight: 620)
    }
}

// MARK: - Protocol Debug & Diagnostics Console Sheet

struct DebugConsoleSheetView: View {
    @ObservedObject var vm: InstaxAppViewModel
    @Environment(\.dismiss) private var dismiss

    var filteredLogs: [LogMessage] {
        vm.logEntries.filter { msg in
            let matchesCategory: Bool
            switch vm.debugFilter {
            case .all:
                matchesCategory = true
            case .ble:
                matchesCategory = (msg.category == .ble)
            case .print:
                matchesCategory = (msg.category == .print)
            case .image:
                matchesCategory = (msg.category == .image)
            case .err:
                matchesCategory = (msg.category == .err)
            }
            if !matchesCategory { return false }
            if vm.logSearchQuery.isEmpty { return true }
            return msg.text.localizedCaseInsensitiveContains(vm.logSearchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Instax BLE Protocol & Diagnostics Console")
                        .font(.system(size: 16, weight: .bold))
                    Text("Real-time bidirectional packet traces, hardware registers, image pipeline & print telemetry")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    vm.copyLogsToClipboard()
                } label: {
                    Label("Copy Trace", systemImage: "doc.on.doc")
                }
                .controlSize(.regular)

                Button {
                    vm.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .controlSize(.regular)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Hardware Telemetry Banner (Cards)
            HStack(spacing: 12) {
                telemetryCard(
                    title: "CONNECTED DEVICE",
                    value: vm.isConnected && !vm.connectedDeviceName.isEmpty ? vm.connectedDeviceName : (vm.targetDeviceName.isEmpty ? "None" : vm.targetDeviceName),
                    detail: vm.status.modelNumber.isEmpty ? vm.selectedModel.displayName : "Model: \(vm.status.modelNumber)",
                    icon: "printer.fill",
                    color: vm.isConnected ? .green : .secondary
                )

                telemetryCard(
                    title: "FILM REMAINING",
                    value: vm.isConnected ? "\(vm.status.filmRemaining) / 10" : "--",
                    detail: vm.status.isCoverOpen ? "Door OPEN ⚠️" : "Door Closed ✓",
                    icon: "film.stack",
                    color: vm.status.filmRemaining > 2 ? .blue : (vm.status.filmRemaining > 0 ? .orange : .red)
                )

                telemetryCard(
                    title: "BATTERY LEVEL",
                    value: vm.isConnected ? "\(vm.status.batteryPercent)%" : "--",
                    detail: vm.status.isCharging ? "Charging ⚡️" : "Level \(vm.status.batteryLevel)/4",
                    icon: vm.status.isCharging ? "battery.100.bolt" : "battery.75",
                    color: vm.status.batteryPercent > 20 ? .green : .red
                )

                telemetryCard(
                    title: "PRINT RESOLUTION",
                    value: "\(vm.effectiveWidth) × \(vm.effectiveHeight)",
                    detail: "Max JPEG: \(vm.effectiveMaxJpegBytes / 1024) KB",
                    icon: "aspectratio",
                    color: .purple
                )

                telemetryCard(
                    title: "PROTOCOL LINK",
                    value: "MTU: \(vm.status.chunkSize > 0 ? vm.status.chunkSize : 1808)B",
                    detail: "Prints: \(vm.status.totalPrints)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .indigo
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Filter bar & Search
            HStack(spacing: 10) {
                Picker("Filter", selection: $vm.debugFilter) {
                    ForEach(LogCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                TextField("Search logs...", text: $vm.logSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)

                Toggle("Auto-scroll", isOn: $vm.isAutoScrollLogs)
                    .font(.caption)

                Spacer()

                // Quick Diagnostics Triggers
                Button("Query Status") {
                    vm.refreshStatus()
                }
                .controlSize(.small)
                .disabled(vm.isConnecting || vm.isPrinting)

                Button("Rainbow LED") {
                    vm.flashLEDOnce()
                }
                .controlSize(.small)
                .disabled(vm.isConnecting || vm.isPrinting)

                Button("Stop LED") {
                    vm.stopLEDNow()
                }
                .controlSize(.small)
                .disabled(vm.isConnecting || vm.isPrinting)

                Button("Eject Dark Slide") {
                    vm.ejectFilmCoverNow()
                }
                .controlSize(.small)
                .help("Eject the black protective sheet of a newly inserted film pack")
                .disabled(vm.isConnecting || vm.isPrinting)

                Button("Scan BLE") {

                    vm.scanForNearbyPrinters()
                }
                .controlSize(.small)
                .disabled(vm.isScanningPrinters)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Monospace Terminal Log View
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if filteredLogs.isEmpty {
                            Text("No log messages matching filter.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(16)
                        } else {
                            ForEach(filteredLogs) { msg in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(msg.timeString)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(Color.gray)
                                        .frame(width: 82, alignment: .leading)

                                    Text(msg.category.rawValue)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(msg.category.badgeColor.opacity(0.85))
                                        .cornerRadius(3)
                                        .frame(width: 48, alignment: .center)

                                    Text(msg.text)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(textColor(for: msg.text))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 2)
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .onChange(of: vm.logEntries.count) { _ in
                    if vm.isAutoScrollLogs, let last = filteredLogs.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private func telemetryCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func textColor(for line: String) -> Color {
        if line.contains("[TX]") {
            return Color(red: 0.4, green: 0.8, blue: 1.0) // Cyan
        } else if line.contains("[RX]") {
            return Color(red: 0.4, green: 0.95, blue: 0.5) // Emerald
        } else if line.contains("[PRINT]") {
            return Color(red: 1.0, green: 0.85, blue: 0.3) // Gold/Yellow
        } else if line.contains("[IMG]") {
            return Color(red: 0.85, green: 0.6, blue: 1.0) // Magenta/Lilac
        } else if line.contains("[ERR]") || line.contains("failed") || line.contains("rejected") {
            return Color(red: 1.0, green: 0.4, blue: 0.4) // Crimson Red
        }
        return Color(red: 0.88, green: 0.88, blue: 0.9)
    }
}

// MARK: - Custom Printer Name Sheet

struct CustomPrinterEntrySheet: View {
    @ObservedObject var vm: InstaxAppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "printer.dotmatrix.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect to Custom Instax Printer")
                        .font(.headline)
                    Text("Enter Bluetooth name (e.g. INSTAX-50271289) or device name prefix")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            TextField("INSTAX-XXXXXXXX", text: $vm.customPrinterInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save & Connect") {
                    let input = vm.customPrinterInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !input.isEmpty {
                        dismiss()
                        vm.selectPrinterAndConnect(input)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.customPrinterInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - User Guide & Help Sheet

struct HelpGuideSheetView: View {
    @ObservedObject var vm: InstaxAppViewModel
    @Environment(\.dismiss) private var dismiss

    var filteredTopics: [HelpTopic] {
        if vm.helpSearchQuery.isEmpty {
            return HelpTopic.allCases
        }
        return HelpTopic.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(vm.helpSearchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Instax Printer User Guide & Help")
                        .font(.system(size: 16, weight: .bold))
                    Text("Everything you need to print to Instax SQUARE Link, Link WIDE, and Mini")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Split View: Sidebar Topics + Content Area
            HStack(spacing: 0) {
                // Left Topic Navigation
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search topics...", text: $vm.helpSearchQuery)
                            .textFieldStyle(.plain)
                        if !vm.helpSearchQuery.isEmpty {
                            Button(action: { vm.helpSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(10)

                    Divider()

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(filteredTopics) { topic in
                                let isSelected = (vm.selectedHelpTopic == topic)
                                Button {
                                    vm.selectedHelpTopic = topic
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: topic.icon)
                                            .foregroundColor(isSelected ? .white : .accentColor)
                                            .frame(width: 20)
                                        Text(topic.rawValue)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? .white : .primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.accentColor : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                }
                .frame(width: 240)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Right Content View
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch vm.selectedHelpTopic {
                        case .quickStart:
                            quickStartContent
                        case .framing:
                            framingContent
                        case .printModes:
                            printModesContent
                        case .bulkQueue:
                            bulkQueueContent
                        case .multiPrinter:
                            multiPrinterContent
                        case .debugConsole:
                            debugConsoleContent
                        case .offlineBackup:
                            offlineBackupContent
                        case .troubleshooting:
                            troubleshootingContent
                        }
                    }
                    .padding(24)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(minWidth: 860, minHeight: 600)
    }

    // MARK: - Topic Content Views

    private var quickStartContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Quick Start Guide", icon: "bolt.fill", subtitle: "Turn on your printer and make your first print in seconds")

            guideBox("1. Prepare Printer", icon: "power") {
                Text("Turn on your Instax printer by pressing and holding the power button until the front LED glows.")
                Text("Important: If you previously paired the printer with the official iPhone or Android app, tap 'Disconnect' or temporarily turn off Bluetooth on your phone. Instax hardware only allows one active Bluetooth Low Energy connection at a time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            guideBox("2. Select & Connect", icon: "dot.radiowaves.left.and.right") {
                Text("In the top bar, click the **Printer Menu** (e.g. `INSTAX-50271289`).")
                Text("Your printer will appear in the **Nearby Discovered Printers** section with signal strength (RSSI). Click it to connect immediately. The app queries the printer hardware registers and shows your remaining film and battery status.")
            }

            guideBox("3. Add Photo & Adjust", icon: "photo") {
                Text("Drag and drop any image into the workspace, or click **Apple Photos / iCloud...** to select from your personal library.")
                Text("Use the Framing tab to pan, zoom, or rotate. You can drag the photo directly inside the preview square to pan.")
            }

            guideBox("4. Print", icon: "printer.fill") {
                Text("Click the green **Print Selected Photo** button (or press `⌘P`). The printer's LED will flash and eject your physical Instax photo in ~12 seconds!")
            }

            HStack(spacing: 12) {
                Button("Scan for Nearby Printers") {
                    vm.scanForNearbyPrinters()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Debug Console (⌘D)") {
                    dismiss()
                    vm.showDebugConsole = true
                }
            }
            .padding(.top, 8)
        }
    }

    private var framingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Framing & Aspect Ratios", icon: "crop", subtitle: "Understanding Crop vs Letterbox and film borders")

            guideBox("Fill (Crop) vs Fit (Letterbox)", icon: "aspectratio") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• **Fill (Crop):** Automatically zooms the photo to fill the entire square/wide printable area without empty spaces. You can drag the photo to center faces or subjects.")
                    Text("• **Fit (Letterbox):** Shrinks the image so the entire picture is visible without any cropping. You can choose a background letterbox color (white, black, or custom).")
                    Text("• **Stretch:** Distorts the photo to fit the canvas dimensions (not recommended for portraits).")
                }
            }

            guideBox("Pan, Zoom & Rotation", icon: "arrow.up.and.down.and.arrow.left.and.right") {
                Text("• Click and drag anywhere on the photo preview to smoothly pan horizontally and vertically.")
                Text("• Use the Zoom slider (0.4× to 3.0×) to magnify details.")
                Text("• Click Rotate ↺ / ↻ to rotate in 90° increments without losing image resolution.")
            }

            guideBox("Why are there no borders added to the photo preview?", icon: "info.circle.fill") {
                Text("Instax film cartridges already have physical borders built directly into the chemistry pack (white or decorative frame). Adding a virtual border inside the printed image creates a 'border within a border', which reduces the photo size. This app fills the true physical exposure area.")
            }
        }
    }

    private var printModesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Rich vs. Natural Print Modes", icon: "paintpalette.fill", subtitle: "Fujifilm hardware color simulation and 3D-LUTs")

            guideBox("instax-Rich Mode (Vibrant Pop)", icon: "sparkles") {
                Text("• Enhances color saturation, contrast, and highlights.")
                Text("• Ideal for sunny outdoor landscapes, vibrant food, sunsets, and smartphone captures.")
                Text("• Sets the printer hardware option byte to `0x00`.")
            }

            guideBox("instax-Natural Mode (Classic Film 3D-LUT)", icon: "camera.filters") {
                Text("• Emulates traditional classic analog Fujifilm instant film tones.")
                Text("• Employs the printer's onboard 3D-LUT color table (`0x08`) for softer highlights and natural skin tones.")
                Text("• Ideal for portraits, candid moments, indoor ambient lighting, and moody scenes.")
            }

            guideBox("Creative Filter Presets", icon: "slider.horizontal.3") {
                Text("In the **Color & Filters** tab in the sidebar, you can apply non-destructive filters: Original, B&W Mono, Warm Sepia, Vintage Film, Cool Fade, and Vivid Pop, plus fine-tune brightness, contrast, and saturation.")
            }
        }
    }

    private var bulkQueueContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Bulk Printing & Apple Photos / iCloud", icon: "square.stack.3d.up.fill", subtitle: "Batch print multiple photos with automatic film pacing")

            guideBox("Apple Photos & iCloud Integration", icon: "icloud.and.arrow.down") {
                Text("• Click **Apple Photos / iCloud...** in the toolbar or press `⇧⌘I`.")
                Text("• Browse your **full photo library**, including iCloud Shared Albums and Favorites.")
                Text("• The app downloads the full-resolution master file directly from iCloud PhotoKit.")
                Text("• Click multiple photos to select them, then click **Add Selected to Queue**.")
            }

            guideBox("Bulk Print Queue Strip", icon: "list.bullet.rectangle.portrait") {
                Text("• The strip at the bottom displays all queued photos with order numbers (#1, #2, ...).")
                Text("• Click **Bulk Print Queue** to print all pending items sequentially.")
                Text("• **Pacing & Cooling:** The app automatically waits 3 seconds between prints to let the thermal print head cool down and ensure crisp colors.")
                Text("• **Empty Cartridge Detection:** If film runs out (0/10) midway through a batch, the app safely pauses, prompts you to insert a new film cartridge, and lets you resume without re-printing duplicate photos.")
            }
        }
    }

    private var multiPrinterContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Multi-Printer Support", icon: "printer.fill", subtitle: "Instax SQUARE Link, Link WIDE / WIDE 2, and Mini Link 1/2/3 / Link+")

            guideBox("Automatic Resolution Adaptation", icon: "gearshape.2") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("When you connect to an Instax printer, the app queries hardware register `0x00, 0x02`:")
                    Text("• **Instax SQUARE Link:** Resolution is set to **800 × 800 px**.")
                    Text("• **Instax Link WIDE & WIDE 2:** Resolution is set to **1260 × 840 px**.")
                    Text("• **Instax Mini Link (1/2/3/Link+):** Resolution is set to **600 × 800 px** with safe buffer limits.")
                    Text("The canvas aspect ratio and JPEG compression buffer automatically adapt to your connected printer.")
                }
            }

            guideBox("Switching Between Printers", icon: "arrow.triangle.swap") {
                Text("• Open the **Printer Menu** in the top bar.")
                Text("• All detected Instax printers nearby appear with signal strength (dBm).")
                Text("• Click any printer to disconnect from the current one and pair with the new one.")
                Text("• Saved printers are remembered across app launches.")
            }
        }
    }

    private var debugConsoleContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Protocol Debug Console & CLI", icon: "terminal.fill", subtitle: "Behind-the-scenes Bluetooth packet inspection and terminal commands")

            guideBox("Live Protocol Debug Console (⌘D)", icon: "terminal") {
                Text("Click **Protocol Debug Console** in the bottom status bar or press `⌘D` to open real-time telemetry:")
                Text("• **[TX] (Cyan):** Outgoing Bluetooth commands with SID codes and byte packets.")
                Text("• **[RX] (Green):** Incoming responses from printer hardware with result codes.")
                Text("• **[PRINT] (Gold):** Image download chunks (1808-byte frames) and film ejection stages.")
                Text("• **[IMG] (Lilac):** Aspect ratio transforms and JPEG compression budgets.")
                Text("• Live hardware registers: Battery %, film remaining, film door open/closed, lifetime print count.")
            }

            guideBox("Standalone Terminal CLI", icon: "apple.terminal") {
                Text("The app includes a compiled terminal tool `instax-square` in your project folder:")
                Text("`./instax-square print photo.jpg --mode rich`")
                Text("Run `./instax-square --help` for full command-line arguments.")
            }

            Button("Open Debug Console Now (⌘D)") {
                dismiss()
                vm.showDebugConsole = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
    }

    private var offlineBackupContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Offline Backup & Firmware Safety", icon: "externaldrive.badge.checkmark", subtitle: "Why our software is 100% offline and why firmware flashing is dangerous")

            guideBox("100% Offline & Independent Guarantee", icon: "lock.shield.fill") {
                Text("• This application contains **zero cloud calls, zero analytics, zero telemetry, and zero user accounts**.")
                Text("• Direct Bluetooth connection from Mac to printer hardware.")
                Text("• Even if Fujifilm discontinues their servers or apps, this desktop app will keep printing forever.")
            }

            guideBox("⚠️ Why We Do NOT Include Firmware Flashing", icon: "exclamationmark.triangle.fill") {
                Text("• Instax printers have no USB recovery port or external recovery mode.")
                Text("• Any interrupted BLE firmware write will permanently **hard-brick** the printer hardware beyond repair.")
                Text("• Fujifilm firmware updates are cryptographically signed. If a firmware update is ever needed, use the official free mobile app once on your phone.")
            }

            guideBox("Emergency Offline Backup Archive", icon: "archivebox.fill") {
                Text("A complete standalone backup archive is saved on your Desktop: `Instax-Printer-Offline-Backup.zip`. It includes the App, the CLI binary, and a double-clickable `offline-print.command` script.")
            }

            Button("Reveal Offline Backup in Finder") {
                vm.revealOfflineBackupInFinder()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
    }

    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topicHeader(title: "Troubleshooting & FAQs", icon: "questionmark.circle.fill", subtitle: "Quick answers to common questions")

            guideBox("Printer Not Found in Bluetooth Scan", icon: "antenna.radiowaves.left.and.right.slash") {
                Text("1. Ensure printer is turned on (front LED is illuminated).")
                Text("2. Make sure printer is NOT currently connected to the iPhone/Android app. Close the phone app or tap Disconnect.")
                Text("3. Check that Mac Bluetooth is enabled in System Settings -> Privacy & Security -> Bluetooth.")
            }

            guideBox("LED Light Constantly Keeps Flashing", icon: "lightbulb.slash") {
                Text("Click the **Stop LED** button in the header bar or press `⇧⌘L`. This sends an immediate stop frame (`0x00, 0x01`) and restores the normal battery indicator LED.")
            }

            guideBox("Error: Film Door is Open", icon: "door.right.hand.open") {
                Text("The printer has a physical micro-switch on the back cover. Firmly snap the film compartment door shut until it clicks.")
            }

            guideBox("Error: Low Battery", icon: "battery.0") {
                Text("Instax printers require sufficient power to heat the exposure head and drive the ejection rollers. Plug in the USB cable to charge for 15 minutes before printing.")
            }
        }
    }

    // MARK: - View Helpers

    private func topicHeader(title: String, icon: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 6)
    }

    private func guideBox<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .font(.system(size: 12))
            .foregroundColor(.primary.opacity(0.9))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .cornerRadius(8)
    }
}

// MARK: - Application Entry Point

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenURLs: (([URL]) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        onOpenURLs?(urls)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        onOpenURLs?(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct InstaxSquareDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = InstaxAppViewModel()

    var body: some Scene {
        WindowGroup(viewModel.isConnected && !viewModel.connectedDeviceName.isEmpty ? "\(viewModel.connectedDeviceName) — Instax Printer" : "\(viewModel.selectedModel.displayName) — Instax Printer") {
            InstaxMainView(vm: viewModel)
                .onAppear {
                    appDelegate.onOpenURLs = { urls in
                        viewModel.addPhotoURLsToQueue(urls)
                    }
                }
                .onOpenURL { url in
                    if url.scheme?.lowercased() == "instax" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                            if let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {
                                let fUrl = URL(fileURLWithPath: fileParam)
                                viewModel.addPhotoURLsToQueue([fUrl])
                            }
                        }
                    } else {
                        viewModel.addPhotoURLsToQueue([url])
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Photos from Files...") {
                    viewModel.openFilePicker(allowMultiple: true)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Browse Apple Photos / iCloud...") {
                    viewModel.openApplePhotosPicker()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Save Current Preview...") {
                    viewModel.savePreviewToDisk()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Divider()

                Button("Toggle Protocol Debug Console") {
                    viewModel.showDebugConsole.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("Stop Printer LED Flashing") {
                    viewModel.stopLEDNow()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Print Selected Photo") {
                    viewModel.printSelectedImage()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button("Bulk Print Queue") {
                    viewModel.bulkPrintQueue()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("Instax Printer User Guide & Help...") {
                    viewModel.showHelpSheet = true
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Protocol Debug & Diagnostics Console...") {
                    viewModel.showDebugConsole = true
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("Stop Printer LED Flashing") {
                    viewModel.stopLEDNow()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Reveal Offline Backup Package in Finder") {
                    viewModel.revealOfflineBackupInFinder()
                }
            }
        }
    }
}

