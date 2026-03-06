import Foundation

@Observable
final class GCSService {
    let authService: AuthenticationService

    private(set) var objects: [GCSObject] = []
    private(set) var prefixes: [String] = []
    private(set) var isLoading = false
    private(set) var uploadState: UploadState = .idle
    private(set) var currentPrefix: String = ""
    private(set) var error: String?

    private static let baseURL = "https://storage.googleapis.com/storage/v1"
    private static let uploadURL = "https://storage.googleapis.com/upload/storage/v1"

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    func listObjects(bucket: String, prefix: String = "", delimiter: String = "/") async {
        isLoading = true
        error = nil
        currentPrefix = prefix

        do {
            let token = try await authService.getValidToken()

            var components = URLComponents(string: "\(Self.baseURL)/b/\(bucket)/o")!
            components.queryItems = [
                URLQueryItem(name: "delimiter", value: delimiter),
                URLQueryItem(name: "prefix", value: prefix),
            ]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GCSError.requestFailed(errorBody)
            }

            let listResponse = try JSONDecoder().decode(GCSListResponse.self, from: data)
            objects = listResponse.items ?? []
            prefixes = listResponse.prefixes ?? []
        } catch {
            self.error = error.localizedDescription
            objects = []
            prefixes = []
        }

        isLoading = false
    }

    func uploadFile(bucket: String, fileURL: URL, prefix: String = "") async {
        let fileName = fileURL.lastPathComponent
        let objectName = prefix.isEmpty ? fileName : "\(prefix)\(fileName)"
        uploadState = .uploading(fileName: fileName, progress: 0)

        do {
            let token = try await authService.getValidToken()
            let fileData = try Data(contentsOf: fileURL)

            let encodedName = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
            var components = URLComponents(string: "\(Self.uploadURL)/b/\(bucket)/o")!
            components.queryItems = [
                URLQueryItem(name: "uploadType", value: "media"),
                URLQueryItem(name: "name", value: objectName),
            ]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.httpBody = fileData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GCSError.requestFailed(errorBody)
            }

            uploadState = .success(fileName: fileName)

            // Auto-reset after a delay
            try? await Task.sleep(for: .seconds(3))
            if case .success = uploadState {
                uploadState = .idle
            }
        } catch {
            uploadState = .error(message: error.localizedDescription)
        }
    }

    func deleteObject(bucket: String, objectName: String) async throws {
        let token = try await authService.getValidToken()

        let encodedName = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let url = URL(string: "\(Self.baseURL)/b/\(bucket)/o/\(encodedName)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 || httpResponse.statusCode == 200
        else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GCSError.requestFailed(errorBody)
        }
    }

    func downloadObject(bucket: String, objectName: String) async throws -> Data {
        let token = try await authService.getValidToken()

        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        let encodedName = objectName.addingPercentEncoding(withAllowedCharacters: allowed) ?? objectName
        let url = URL(string: "\(Self.baseURL)/b/\(bucket)/o/\(encodedName)?alt=media")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GCSError.requestFailed(errorBody)
        }

        return data
    }

    func navigateToFolder(_ folderPrefix: String) {
        currentPrefix = folderPrefix
    }

    func navigateUp() {
        guard !currentPrefix.isEmpty else { return }
        var parts = currentPrefix.dropLast().components(separatedBy: "/")
        parts.removeLast()
        currentPrefix = parts.isEmpty ? "" : parts.joined(separator: "/") + "/"
    }

    enum GCSError: Error, LocalizedError {
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .requestFailed(let detail): return "GCS request failed: \(detail)"
            }
        }
    }
}
