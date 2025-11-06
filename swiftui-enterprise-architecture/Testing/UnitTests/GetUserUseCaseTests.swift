import XCTest
@testable import swiftui_enterprise_architecture

class GetUserUseCaseTests: XCTestCase {

    var getUserUseCase: GetUserUseCase!
    var mockUserRepository: MockUserRepository!

    override func setUp() {
        super.setUp()
        mockUserRepository = MockUserRepository()
        getUserUseCase = DefaultGetUserUseCase(userRepository: mockUserRepository)
    }

    func testGetUserSuccessfully() async throws {
        // Given
        let user = User(id: "1", name: "Test User", email: "test@example.com")
        mockUserRepository.user = user

        // When
        let result = try await getUserUseCase.execute(id: "1")

        // Then
        XCTAssertEqual(result.id, user.id)
    }
}
