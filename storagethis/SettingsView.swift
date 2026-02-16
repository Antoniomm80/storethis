import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("bucketName") private var bucketName: String = ""
    @State private var authService: AuthenticationService
    @State private var showFileImporter = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var statusMessage = ""

    init(authService: AuthenticationService) {
        _authService = State(initialValue: authService)
    }

    var body: some View {
        Form {
            Section("Service Account Key") {
                HStack {
                    if authService.hasKeyFile {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Key file configured")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("No key file")
                    }

                    Spacer()

                    if authService.hasKeyFile {
                        Button("Remove") {
                            authService.removeKeyFile()
                            connectionStatus = .idle
                        }
                    }

                    Button("Select JSON Key...") {
                        showFileImporter = true
                    }
                }
            }

            Section("Bucket") {
                TextField("Bucket name", text: $bucketName)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Connection") {
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(bucketName.isEmpty || !authService.hasKeyFile)

                    Spacer()

                    switch connectionStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure:
                        Label(statusMessage, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 320)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                try authService.importKeyFile(from: url)
            } catch {
                statusMessage = error.localizedDescription
                connectionStatus = .failure
            }
        case .failure(let error):
            statusMessage = error.localizedDescription
            connectionStatus = .failure
        }
    }

    private func testConnection() {
        connectionStatus = .testing
        Task {
            do {
                try await authService.authenticate()
                let gcs = GCSService(authService: authService)
                await gcs.listObjects(bucket: bucketName)
                if let error = gcs.error {
                    statusMessage = error
                    connectionStatus = .failure
                } else {
                    connectionStatus = .success
                }
            } catch {
                statusMessage = error.localizedDescription
                connectionStatus = .failure
            }
        }
    }

    private enum ConnectionStatus {
        case idle, testing, success, failure
    }
}
