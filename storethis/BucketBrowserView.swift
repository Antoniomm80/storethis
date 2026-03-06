import SwiftUI

struct BucketBrowserView: View {
    let gcsService: GCSService
    let bucket: String
    let onRefresh: () -> Void
    let onDelete: (String) -> Void

    @State private var selectedObject: GCSObject?

    var body: some View {
        if let object = selectedObject {
            FilePreviewView(
                object: object,
                gcsService: gcsService,
                bucket: bucket,
                onBack: { selectedObject = nil }
            )
        } else {
            browserContent
        }
    }

    private var browserContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Navigation header
            HStack {
                if !gcsService.currentPrefix.isEmpty {
                    Button {
                        gcsService.navigateUp()
                        onRefresh()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Text(breadcrumb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(gcsService.isLoading)
            }
            .padding(.horizontal, 4)

            Divider()

            if gcsService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding()
            } else if gcsService.prefixes.isEmpty && gcsService.objects.isEmpty {
                HStack {
                    Spacer()
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Folders
                        ForEach(gcsService.prefixes, id: \.self) { prefix in
                            let folderObject = GCSObject(
                                name: prefix,
                                bucket: bucket,
                                size: nil,
                                contentType: nil,
                                updated: nil
                            )
                            FileRowView(object: folderObject) {}
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    gcsService.navigateToFolder(prefix)
                                    onRefresh()
                                }
                        }

                        // Files
                        ForEach(gcsService.objects) { object in
                            if !object.isFolder {
                                FileRowView(object: object) {
                                    onDelete(object.name)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selectedObject = object
                                }
                            }
                        }
                    }
                }
            }

            if let error = gcsService.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var breadcrumb: String {
        if gcsService.currentPrefix.isEmpty {
            return bucket
        }
        return "\(bucket)/\(gcsService.currentPrefix)"
    }
}
