import SwiftUI
import PDFKit
import PencilKit
import UIKit

/// Build 48: Edit PDF, part of Zalla Unlock. Fill forms, add text, sign, highlight, undo, and save a copy.
/// Everything stays on this device. Nothing is uploaded.
enum PDFEditorGate {
    enum Action: Equatable {
        case edit
        case needsUnlock
    }

    static func action(unlocked: Bool) -> Action { unlocked ? .edit : .needsUnlock }

    static func isPDF(_ url: URL) -> Bool { url.pathExtension.lowercased() == "pdf" }

    /// Name for the saved copy: "Lease.pdf" becomes "Lease edited.pdf".
    static func copyName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return "\(base.isEmpty ? "Document" : base) edited.pdf"
    }
}

/// The one saved signature, kept as a PNG in Application Support on this device only.
/// Burn It All leaves it alone, like bookmarks and downloads, because it's something you made, not browsing data.
/// Reset the App deletes it, and so does Delete saved signature in the editor.
struct SignatureStore {
    let directory: URL

    static let shared = SignatureStore(
        directory: (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Signature", isDirectory: true)
    )

    var fileURL: URL { directory.appendingPathComponent("signature.png") }

    var hasSignature: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func load() -> Data? { try? Data(contentsOf: fileURL) }

    @discardableResult
    func save(_ png: Data) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: fileURL, options: [.atomic, .completeFileProtection])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = fileURL
            try? url.setResourceValues(values)
            return true
        } catch {
            return false
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// A PDF handed to Zalla from Files or the share sheet, or picked in Downloads.
struct PDFDocumentItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    /// Copies an incoming file into a private temporary folder, so Zalla never edits the original in place.
    static func incoming(_ url: URL) -> PDFDocumentItem? {
        guard url.isFileURL, PDFEditorGate.isPDF(url) else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("IncomingPDF", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            return PDFDocumentItem(url: target)
        } catch {
            return nil
        }
    }
}

/// A signature placed on a page. Drawn by hand because PDFKit has no image annotation; the saved copy is flattened.
final class SignatureAnnotation: PDFAnnotation {
    let image: UIImage

    init(image: UIImage, bounds: CGRect) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}

enum PDFEditTool: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case text = "Text"
    case sign = "Sign"
    case highlight = "Highlight"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fill: return "character.cursor.ibeam"
        case .text: return "textbox"
        case .sign: return "signature"
        case .highlight: return "highlighter"
        }
    }
}

@MainActor
final class PDFEditorModel: ObservableObject {
    let url: URL
    let document: PDFDocument?
    weak var pdfView: PDFView?
    @Published private(set) var added: [PDFAnnotation] = []
    @Published var message: String?

    init(url: URL) {
        self.url = url
        self.document = PDFDocument(url: url)
    }

    private var currentPage: PDFPage? { pdfView?.currentPage ?? document?.page(at: 0) }

    private func remember(_ annotation: PDFAnnotation, on page: PDFPage) {
        page.addAnnotation(annotation)
        added.append(annotation)
    }

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let page = currentPage else { return }
        let box = page.bounds(for: .mediaBox)
        let width = min(260, box.width * 0.6)
        let rect = CGRect(x: box.midX - width / 2, y: box.midY - 15, width: width, height: 30)
        let note = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        note.contents = trimmed
        note.font = UIFont.systemFont(ofSize: 14)
        note.fontColor = .black
        note.color = .clear
        remember(note, on: page)
        message = "Text added. Drag it to move it, or pinch to resize."
    }

    func placeSignature(_ image: UIImage) {
        guard let page = currentPage, image.size.width > 0 else { return }
        let box = page.bounds(for: .mediaBox)
        let width = min(200, box.width * 0.4)
        let height = width * image.size.height / image.size.width
        let rect = CGRect(x: box.midX - width / 2, y: box.minY + box.height * 0.2, width: width, height: height)
        remember(SignatureAnnotation(image: image, bounds: rect), on: page)
        message = "Signature placed. Drag it into place and pinch to resize."
    }

    func highlightSelection() {
        guard let selection = pdfView?.currentSelection else {
            message = "Select some text first, then tap Highlight."
            return
        }
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let mark = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight, withProperties: nil)
                mark.color = UIColor.systemYellow.withAlphaComponent(0.45)
                remember(mark, on: page)
            }
        }
        pdfView?.clearSelection()
    }

    var canUndo: Bool { !added.isEmpty }

    func undo() {
        guard let last = added.popLast() else { return }
        last.page?.removeAnnotation(last)
    }

    /// Writes a flattened copy, so the signature and text look the same in every PDF app. The original stays as it was.
    func exportCopy() -> URL? {
        guard let document else { return nil }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(PDFEditorGate.copyName(for: url))
        try? FileManager.default.removeItem(at: target)
        let first = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: first)
        do {
            try renderer.writePDF(to: target) { context in
                for index in 0..<document.pageCount {
                    guard let page = document.page(at: index) else { continue }
                    let box = page.bounds(for: .mediaBox)
                    context.beginPage(withBounds: CGRect(origin: .zero, size: box.size), pageInfo: [:])
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.translateBy(x: 0, y: box.height)
                    cg.scaleBy(x: 1, y: -1)
                    cg.translateBy(x: -box.minX, y: -box.minY)
                    page.draw(with: .mediaBox, to: cg)
                    cg.restoreGState()
                }
            }
            return target
        } catch {
            return nil
        }
    }

    /// Drag and pinch for text boxes and signatures you added.
    func annotation(at point: CGPoint, in view: PDFView) -> (PDFAnnotation, PDFPage)? {
        guard let page = view.page(for: point, nearest: false) else { return nil }
        let pagePoint = view.convert(point, to: page)
        for item in added.reversed() where item.page == page && item.bounds.insetBy(dx: -12, dy: -12).contains(pagePoint) {
            if item is SignatureAnnotation || item.type == PDFAnnotationSubtype.freeText.rawValue.replacingOccurrences(of: "/", with: "") {
                return (item, page)
            }
        }
        return nil
    }
}

/// PDFKit's view. Form fields fill natively when you tap them.
private struct PDFKitView: UIViewRepresentable {
    @ObservedObject var model: PDFEditorModel
    let editing: Bool

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = model.document
        view.backgroundColor = .secondarySystemBackground
        model.pdfView = view
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.editing = editing
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let model: PDFEditorModel
        weak var view: PDFView?
        var editing = false
        private var dragging: (PDFAnnotation, PDFPage)?
        private var startBounds: CGRect = .zero

        init(model: PDFEditorModel) { self.model = model }

        nonisolated func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            MainActor.assumeIsolated {
                guard editing, let view else { return false }
                return model.annotation(at: recognizer.location(in: view), in: view) != nil
            }
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view else { return }
            switch recognizer.state {
            case .began:
                dragging = model.annotation(at: recognizer.location(in: view), in: view)
                startBounds = dragging?.0.bounds ?? .zero
            case .changed:
                guard let drag = dragging else { return }
                let item = drag.0
                let page = drag.1
                let origin = view.convert(CGPoint.zero, to: page)
                let moved = view.convert(recognizer.translation(in: view), to: page)
                item.bounds = startBounds.offsetBy(dx: moved.x - origin.x, dy: moved.y - origin.y)
            default:
                dragging = nil
            }
        }

        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view else { return }
            switch recognizer.state {
            case .began:
                dragging = model.annotation(at: recognizer.location(in: view), in: view)
                startBounds = dragging?.0.bounds ?? .zero
            case .changed:
                guard let item = dragging?.0 else { return }
                let scale = max(0.3, min(4, recognizer.scale))
                let size = CGSize(width: startBounds.width * scale, height: startBounds.height * scale)
                item.bounds = CGRect(x: startBounds.midX - size.width / 2, y: startBounds.midY - size.height / 2,
                                     width: size.width, height: size.height)
            default:
                dragging = nil
            }
        }
    }
}

/// Draw a signature with a finger or Apple Pencil.
private struct SignaturePad: UIViewRepresentable {
    let canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

private struct SignatureSheet: View {
    let onUse: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var saveForLater = true
    @State private var hasSaved = SignatureStore.shared.hasSignature

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if hasSaved, let data = SignatureStore.shared.load(), let saved = UIImage(data: data) {
                    VStack(spacing: 8) {
                        Image(uiImage: saved).resizable().scaledToFit().frame(height: 80)
                            .padding(8).background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                        HStack {
                            Button("Use saved signature") { onUse(saved); dismiss() }
                                .buttonStyle(.borderedProminent)
                            Button("Delete saved signature", role: .destructive) {
                                SignatureStore.shared.delete()
                                hasSaved = false
                            }
                        }
                    }
                    Text("Or draw a new one below.").font(.footnote).foregroundStyle(.secondary)
                }
                SignaturePad(canvas: canvas)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.3)))
                Toggle("Save this signature on this iPhone", isOn: $saveForLater)
                Text("Your signature never leaves this device.").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { Button("Clear") { canvas.drawing = PKDrawing() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        let drawing = canvas.drawing
                        guard !drawing.bounds.isEmpty else { return }
                        let image = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 3)
                        if saveForLater, let png = image.pngData() { SignatureStore.shared.save(png) }
                        onUse(image)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// The editor. Without Zalla Unlock it opens the PDF to read, with a locked Edit PDF button.
struct PDFEditorView: View {
    let url: URL
    @StateObject private var model: PDFEditorModel
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tool: PDFEditTool = .fill
    @State private var editing = false
    @State private var showUnlock = false
    @State private var showSignature = false
    @State private var askText = false
    @State private var textDraft = ""
    @State private var shareURL: URL?

    init(url: URL) {
        self.url = url
        _model = StateObject(wrappedValue: PDFEditorModel(url: url))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.document == nil {
                    ContentUnavailableView("Can't open this PDF", systemImage: "doc.questionmark",
                                           description: Text("The file may be damaged or password protected."))
                } else {
                    PDFKitView(model: model, editing: editing)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if editing { toolBar }
            }
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    if editing {
                        Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                            .disabled(!model.canUndo)
                            .accessibilityLabel("Undo")
                        Button("Save a Copy") { shareURL = model.exportCopy() }
                    } else if model.document != nil {
                        Button {
                            switch PDFEditorGate.action(unlocked: unlock.isUnlocked) {
                            case .edit: editing = true
                            case .needsUnlock: showUnlock = true
                            }
                        } label: {
                            Label("Edit PDF", systemImage: unlock.isUnlocked ? "pencil.tip.crop.circle" : "lock.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            .sheet(isPresented: $showUnlock) { ZallaUnlockSheet() }
            .sheet(isPresented: $showSignature) { SignatureSheet { model.placeSignature($0) } }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ActivityShareSheet(items: [shareURL]) }
            }
            .alert("Add text", isPresented: $askText) {
                TextField("Text", text: $textDraft)
                Button("Add") { model.addText(textDraft); textDraft = "" }
                Button("Cancel", role: .cancel) { textDraft = "" }
            }
        }
    }

    private var toolBar: some View {
        VStack(spacing: 6) {
            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            HStack {
                ForEach(PDFEditTool.allCases) { item in
                    Button {
                        tool = item
                        switch item {
                        case .fill: model.message = "Tap any form field to type in it."
                        case .text: askText = true
                        case .sign: showSignature = true
                        case .highlight: model.highlightSelection()
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol)
                            Text(item.rawValue).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(tool == item ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Build 49: the private temporary copy used when Edit PDF is tapped on a PDF in a tab.
enum PDFTabCopy {
    static func looksLikePDF(_ data: Data) -> Bool {
        data.count > 4 && data.prefix(1024).range(of: Data("%PDF".utf8)) != nil
    }

    static var folder: URL { FileManager.default.temporaryDirectory.appendingPathComponent("TabPDF", isDirectory: true) }

    static func safeName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        let base = cleaned.isEmpty ? "Document" : cleaned
        return base.lowercased().hasSuffix(".pdf") ? base : base + ".pdf"
    }

    static func write(_ data: Data, name: String) -> URL? {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(safeName(name))
        do {
            try data.write(to: target, options: [.atomic, .completeFileProtection])
            return target
        } catch {
            return nil
        }
    }
}

/// Build 49: Download and Edit PDF, floating over a PDF shown in a tab.
struct PDFTabActions: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject private var unlock = ZallaUnlock.shared
    @State private var editing: PDFDocumentItem?
    @State private var showUnlock = false
    @State private var working = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 8) {
            if let notice = tab.downloadNotice {
                Text(notice)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .transition(.opacity)
            }
            if tab.isShowingPDF {
                HStack(spacing: 10) {
                    Button {
                        browser.downloadPage(in: tab)
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    Button {
                        edit()
                    } label: {
                        if working {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Edit PDF", systemImage: unlock.isUnlocked ? "pencil.tip.crop.circle" : "lock.fill")
                        }
                    }
                    .disabled(working)
                    .accessibilityLabel(unlock.isUnlocked ? "Edit PDF" : "Edit PDF, needs Zalla Unlock")
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .padding(6)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .sheet(isPresented: $showUnlock) { ZallaUnlockSheet() }
        .fullScreenCover(item: $editing) { item in PDFEditorView(url: item.url) }
        .alert("Couldn't open this PDF for editing", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try Download, then Edit PDF from Downloads.")
        }
    }

    @MainActor
    private func edit() {
        guard PDFEditorGate.action(unlocked: unlock.isUnlocked) == .edit else {
            showUnlock = true
            return
        }
        working = true
        Task {
            let copy = await tab.fetchPDFCopy()
            working = false
            if let copy { editing = PDFDocumentItem(url: copy) } else { failed = true }
        }
    }
}
