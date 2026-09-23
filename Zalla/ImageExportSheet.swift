import SwiftUI

struct ImageExportSheet: View {
    let request: ImageExportRequest
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ImageExportFormat = .png
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var status: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Export as") {
                    Picker("Format", selection: $selected) {
                        ForEach(ImageExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label("Save to Photos", systemImage: "photo")
                    }
                    .disabled(busy)

                    Button {
                        Task { await share() }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(busy)
                } footer: {
                    Text("Image export is free. Long-press an image on a page to open this sheet.")
                }
                if let status {
                    Section {
                        Text(status).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ActivityShareSheet(items: [shareURL])
                }
            }
        }
    }

    private func saveToPhotos() async {
        busy = true
        defer { busy = false }
        do {
            try await ImageExporter.saveToPhotos(data: request.data, format: selected)
            status = "Saved \(selected.rawValue) to Photos."
        } catch {
            status = error.localizedDescription
        }
    }

    private func share() async {
        busy = true
        defer { busy = false }
        do {
            shareURL = try ImageExporter.writeTemporary(data: request.data, format: selected)
            showShare = true
        } catch {
            status = error.localizedDescription
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
