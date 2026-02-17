import Foundation

struct TranscriptionResponse: Decodable {
    let text: String
    let language: String?
}

final class TranscriptionClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://127.0.0.1:8766")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func transcribe(wavData: Data) async throws -> String {
        let url = baseURL.appendingPathComponent("transcribe")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TranscriptionError.serverError(statusCode)
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text
    }

    func isHealthy() async -> Bool {
        let url = baseURL.appendingPathComponent("health")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            if let json = try? JSONDecoder().decode([String: String].self, from: data) {
                return json["status"] == "ready"
            }
            return false
        } catch {
            return false
        }
    }
}

enum TranscriptionError: LocalizedError {
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        }
    }
}
