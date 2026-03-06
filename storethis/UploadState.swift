import Foundation

enum UploadState: Equatable {
    case idle
    case uploading(fileName: String, progress: Double)
    case success(fileName: String)
    case error(message: String)
}
