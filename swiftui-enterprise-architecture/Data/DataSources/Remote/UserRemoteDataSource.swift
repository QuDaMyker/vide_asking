import Foundation

protocol UserRemoteDataSource {
    func getUser(id: String) async throws -> UserDTO
}

class DefaultUserRemoteDataSource: UserRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func getUser(id: String) async throws -> UserDTO {
        // Logic to fetch user from a remote API
        // Example:
        // let url = URL(string: "https://api.example.com/users/\(id)")!
        // return try await apiClient.request(url: url, responseType: UserDTO.self)
        return UserDTO(id: "1", name: "John Doe", email: "john.doe@example.com")
    }
}
