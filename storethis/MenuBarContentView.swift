import SwiftUI

struct MenuBarContentView: View {
    @State var authService: AuthenticationService
    @State var gcsService: GCSService
    @State var profileManager: ProfileManager

    private var bucketName: String {
        profileManager.activeProfile?.bucketName ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.secondary)
                Text("StoreThis")
                    .font(.headline)

                Spacer()

                if profileManager.profiles.count > 1 {
                    Picker("", selection: Binding(
                        get: { profileManager.activeProfileId ?? UUID() },
                        set: { profileManager.switchProfile(to: $0) }
                    )) {
                        ForEach(profileManager.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 100)
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if !isConfigured {
                unconfiguredView
            } else {
                configuredView
            }
        }
        .frame(width: 320, height: 400)
        .task {
            if isConfigured {
                await refreshBucket()
            }
        }
    }

    private var isConfigured: Bool {
        authService.hasKeyFile && !bucketName.isEmpty
    }

    private var unconfiguredView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "gearshape")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Not Configured")
                .font(.headline)
            Text("Open Settings (Cmd+,) to configure your GCS bucket and service account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var configuredView: some View {
        VStack(spacing: 0) {
            // Drop zone
            DropZoneView(uploadState: gcsService.uploadState) { urls in
                Task {
                    for url in urls {
                        await gcsService.uploadFile(
                            bucket: bucketName,
                            fileURL: url,
                            prefix: gcsService.currentPrefix
                        )
                        await refreshBucket()
                    }
                }
            }
            .padding(12)

            Divider()

            // Bucket browser
            BucketBrowserView(
                gcsService: gcsService,
                bucket: bucketName,
                onRefresh: {
                    Task { await refreshBucket() }
                },
                onDelete: { objectName in
                    Task {
                        try? await gcsService.deleteObject(bucket: bucketName, objectName: objectName)
                        await refreshBucket()
                    }
                }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func refreshBucket() async {
        await gcsService.listObjects(bucket: bucketName, prefix: gcsService.currentPrefix)
    }
}
