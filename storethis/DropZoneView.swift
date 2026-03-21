import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let uploadState: UploadState
    let onDrop: ([URL]) -> Void
    var localization: LocalizationManager = .shared

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            switch uploadState {
            case .idle:
                Image(systemName: "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(localization.localized("dropzone.idle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .uploading(let fileName, _):
                ProgressView()
                    .controlSize(.small)
                Text(localization.localized("dropzone.uploading", fileName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            case .success(let fileName):
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text(localization.localized("dropzone.success", fileName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                onDrop(urls)
            }
        }

        return true
    }
}
