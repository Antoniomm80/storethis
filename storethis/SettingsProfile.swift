import Foundation

struct SettingsProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var bucketName: String
    var keyFileName: String

    init(id: UUID = UUID(), name: String, bucketName: String = "", keyFileName: String? = nil) {
        self.id = id
        self.name = name
        self.bucketName = bucketName
        self.keyFileName = keyFileName ?? "\(id.uuidString).json"
    }
}
