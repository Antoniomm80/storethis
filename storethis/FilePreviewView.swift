import SwiftUI
import QuickLook

struct FilePreviewView: View {
    let object: GCSObject
    let gcsService: GCSService
    let bucket: String
    let onBack: () -> Void

    @State private var fileData: Data?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Text(object.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let fileData {
                    Button {
                        saveToTempAndOpen(data: fileData)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Open in default app")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading preview...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if let error {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            } else if let fileData {
                previewContent(for: fileData)
            }
        }
        .task {
            await loadFile()
        }
    }

    @ViewBuilder
    private func previewContent(for data: Data) -> some View {
        let contentType = object.contentType ?? ""

        if contentType.hasPrefix("image/") {
            imagePreview(data: data)
        } else if contentType == "application/pdf" {
            pdfPreview(data: data)
        } else if isTextType(contentType) {
            textPreview(data: data)
        } else {
            metadataPreview(data: data)
        }
    }

    private func imagePreview(data: Data) -> some View {
        ScrollView {
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                unsupportedView
            }
        }
    }

    private func pdfPreview(data: Data) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("PDF Document")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(object.formattedSize)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Open in Preview") {
                saveToTempAndOpen(data: data)
            }
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func textPreview(data: Data) -> some View {
        ScrollView {
            if let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                unsupportedView
            }
        }
    }

    private func metadataPreview(data: Data) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(object.displayName)
                .font(.caption)
                .fontWeight(.medium)
            if let contentType = object.contentType {
                Text(contentType)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(object.formattedSize)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Open in Default App") {
                saveToTempAndOpen(data: data)
            }
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var unsupportedView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unable to preview this file")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func isTextType(_ contentType: String) -> Bool {
        contentType.hasPrefix("text/")
            || contentType == "application/json"
            || contentType == "application/xml"
            || contentType == "application/javascript"
            || contentType == "application/x-yaml"
    }

    private func loadFile() async {
        isLoading = true
        error = nil

        do {
            fileData = try await gcsService.downloadObject(bucket: bucket, objectName: object.name)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func saveToTempAndOpen(data: Data) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(object.displayName)

        do {
            try data.write(to: tempFile)
            NSWorkspace.shared.open(tempFile)
        } catch {
            self.error = "Failed to open file: \(error.localizedDescription)"
        }
    }
}
