import Foundation

protocol APIClient {
    func request<T: Decodable>(url: URL, responseType: T.Type) async throws -> T
}

class DefaultAPIClient: APIClient {
    func request<T: Decodable>(url: URL, responseType: T.Type) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
