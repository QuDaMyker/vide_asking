import Foundation

protocol CheckSessionUseCase {
    func execute() -> Bool
}

class DefaultCheckSessionUseCase: CheckSessionUseCase {
    private let sessionRepository: SessionRepository

    init(sessionRepository: SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    func execute() -> Bool {
        return sessionRepository.isLoggedIn()
    }
}
