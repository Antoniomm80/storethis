import Foundation

@Observable
final class ProfileManager {
    private(set) var profiles: [SettingsProfile] = []
    var activeProfileId: UUID? {
        didSet {
            if let id = activeProfileId {
                UserDefaults.standard.set(id.uuidString, forKey: "activeProfileId")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeProfileId")
            }
        }
    }

    var activeProfile: SettingsProfile? {
        get { profiles.first { $0.id == activeProfileId } }
        set {
            guard let newValue else { return }
            if let index = profiles.firstIndex(where: { $0.id == newValue.id }) {
                profiles[index] = newValue
                saveProfiles()
            }
        }
    }

    private let authService: AuthenticationService

    private static var appSupportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("storethis")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var keysDirectory: URL {
        let url = appSupportDirectory.appendingPathComponent("keys")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var profilesFileURL: URL {
        appSupportDirectory.appendingPathComponent("profiles.json")
    }

    init(authService: AuthenticationService) {
        self.authService = authService
        loadProfiles()
        migrateIfNeeded()

        if let savedId = UserDefaults.standard.string(forKey: "activeProfileId"),
           let uuid = UUID(uuidString: savedId),
           profiles.contains(where: { $0.id == uuid }) {
            activeProfileId = uuid
        } else {
            activeProfileId = profiles.first?.id
        }

        if let profile = activeProfile {
            applyProfile(profile)
        }
    }

    // MARK: - Profile CRUD

    @discardableResult
    func createProfile(name: String) -> SettingsProfile {
        let profile = SettingsProfile(name: name)
        profiles.append(profile)
        saveProfiles()
        if profiles.count == 1 {
            switchProfile(to: profile.id)
        }
        return profile
    }

    func deleteProfile(_ id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        // Remove the key file
        let keyURL = Self.keysDirectory.appendingPathComponent(profile.keyFileName)
        try? FileManager.default.removeItem(at: keyURL)

        profiles.removeAll { $0.id == id }
        saveProfiles()

        if activeProfileId == id {
            let newActive = profiles.first?.id
            if let newActive {
                switchProfile(to: newActive)
            } else {
                activeProfileId = nil
                authService.resetState()
            }
        }
    }

    func updateProfile(_ profile: SettingsProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        saveProfiles()
        if profile.id == activeProfileId {
            applyProfile(profile)
        }
    }

    func switchProfile(to id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        activeProfileId = id
        applyProfile(profile)
    }

    // MARK: - Key File Management

    func keyFileURL(for profile: SettingsProfile) -> URL {
        Self.keysDirectory.appendingPathComponent(profile.keyFileName)
    }

    func hasKeyFile(for profile: SettingsProfile) -> Bool {
        FileManager.default.fileExists(atPath: keyFileURL(for: profile).path)
    }

    func importKeyFile(from sourceURL: URL, for profileId: UUID) throws {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }
        let destination = Self.keysDirectory.appendingPathComponent(profile.keyFileName)
        let data = try Data(contentsOf: sourceURL)
        // Validate
        _ = try JSONDecoder().decode(ServiceAccountKey.self, from: data)
        try data.write(to: destination, options: .atomic)
        updateProfile(profile)

        if profileId == activeProfileId {
            authService.switchKeyFile(url: destination)
        }
    }

    func removeKeyFile(for profileId: UUID) {
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return }
        let keyURL = keyFileURL(for: profile)
        try? FileManager.default.removeItem(at: keyURL)

        if profileId == activeProfileId {
            authService.resetState()
        }
    }

    // MARK: - Persistence

    func loadProfiles() {
        guard FileManager.default.fileExists(atPath: Self.profilesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.profilesFileURL)
            profiles = try JSONDecoder().decode([SettingsProfile].self, from: data)
        } catch {
            profiles = []
        }
    }

    func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: Self.profilesFileURL, options: .atomic)
        } catch {
            // Silently fail - profiles will be in memory only
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        guard profiles.isEmpty else { return }

        let legacyKeyURL = Self.appSupportDirectory.appendingPathComponent("service-account-key.json")
        let legacyBucket = UserDefaults.standard.string(forKey: "bucketName") ?? ""
        let hasLegacyKey = FileManager.default.fileExists(atPath: legacyKeyURL.path)

        guard hasLegacyKey || !legacyBucket.isEmpty else { return }

        let profile = SettingsProfile(name: "Default", bucketName: legacyBucket)
        profiles.append(profile)

        if hasLegacyKey {
            let newKeyURL = Self.keysDirectory.appendingPathComponent(profile.keyFileName)
            try? FileManager.default.copyItem(at: legacyKeyURL, to: newKeyURL)
        }

        saveProfiles()
        activeProfileId = profile.id
    }

    // MARK: - Private

    private func applyProfile(_ profile: SettingsProfile) {
        let keyURL = keyFileURL(for: profile)
        if FileManager.default.fileExists(atPath: keyURL.path) {
            authService.switchKeyFile(url: keyURL)
        } else {
            authService.resetState()
        }
    }
}
