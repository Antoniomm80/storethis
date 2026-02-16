import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var authService: AuthenticationService
    @State private var profileManager: ProfileManager
    @State private var showFileImporter = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var statusMessage = ""
    @State private var newProfileName = ""
    @State private var showNewProfileSheet = false
    @State private var renamingProfile: SettingsProfile?

    init(authService: AuthenticationService, profileManager: ProfileManager) {
        _authService = State(initialValue: authService)
        _profileManager = State(initialValue: profileManager)
    }

    private var activeProfile: SettingsProfile? {
        profileManager.activeProfile
    }

    var body: some View {
        Form {
            profileSection

            if activeProfile != nil {
                serviceAccountSection
                bucketSection
                connectionSection
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showNewProfileSheet) {
            newProfileSheet
        }
        .sheet(item: $renamingProfile) { profile in
            renameProfileSheet(profile)
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                if profileManager.profiles.isEmpty {
                    Text("No profiles")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Active Profile", selection: Binding(
                        get: { profileManager.activeProfileId ?? UUID() },
                        set: { profileManager.switchProfile(to: $0) }
                    )) {
                        ForEach(profileManager.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                }

                Spacer()

                Button {
                    showNewProfileSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Profile")

                if let profile = activeProfile {
                    Button {
                        renamingProfile = profile
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .help("Rename Profile")

                    Button {
                        profileManager.deleteProfile(profile.id)
                        connectionStatus = .idle
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("Delete Profile")
                    .disabled(profileManager.profiles.count <= 1)
                }
            }
        }
    }

    // MARK: - Service Account Section

    private var serviceAccountSection: some View {
        Section("Service Account Key") {
            HStack {
                if let profile = activeProfile, profileManager.hasKeyFile(for: profile) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Key file configured")
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("No key file")
                }

                Spacer()

                if let profile = activeProfile, profileManager.hasKeyFile(for: profile) {
                    Button("Remove") {
                        profileManager.removeKeyFile(for: profile.id)
                        connectionStatus = .idle
                    }
                }

                Button("Select JSON Key...") {
                    showFileImporter = true
                }
            }
        }
    }

    // MARK: - Bucket Section

    private var bucketSection: some View {
        Section("Bucket") {
            TextField("Bucket name", text: Binding(
                get: { activeProfile?.bucketName ?? "" },
                set: { newValue in
                    guard var profile = activeProfile else { return }
                    profile.bucketName = newValue
                    profileManager.updateProfile(profile)
                }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled((activeProfile?.bucketName.isEmpty ?? true) ||
                          !(activeProfile.map { profileManager.hasKeyFile(for: $0) } ?? false))

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

    // MARK: - Sheets

    private var newProfileSheet: some View {
        VStack(spacing: 16) {
            Text("New Profile")
                .font(.headline)
            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            HStack {
                Button("Cancel") {
                    newProfileName = ""
                    showNewProfileSheet = false
                }
                Button("Create") {
                    let profile = profileManager.createProfile(name: newProfileName)
                    profileManager.switchProfile(to: profile.id)
                    newProfileName = ""
                    showNewProfileSheet = false
                    connectionStatus = .idle
                }
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func renameProfileSheet(_ profile: SettingsProfile) -> some View {
        RenameProfileView(profile: profile, profileManager: profileManager) {
            renamingProfile = nil
        }
    }

    // MARK: - Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let profileId = activeProfile?.id else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                try profileManager.importKeyFile(from: url, for: profileId)
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
                await gcs.listObjects(bucket: activeProfile?.bucketName ?? "")
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

// MARK: - Rename Profile View

private struct RenameProfileView: View {
    let profile: SettingsProfile
    let profileManager: ProfileManager
    let onDismiss: () -> Void
    @State private var name: String

    init(profile: SettingsProfile, profileManager: ProfileManager, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.profileManager = profileManager
        self.onDismiss = onDismiss
        _name = State(initialValue: profile.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Profile")
                .font(.headline)
            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            HStack {
                Button("Cancel") { onDismiss() }
                Button("Rename") {
                    var updated = profile
                    updated.name = name
                    profileManager.updateProfile(updated)
                    onDismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
