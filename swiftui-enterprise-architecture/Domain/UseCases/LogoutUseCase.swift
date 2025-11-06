import Foundation

protocol LogoutUseCase {
    func execute()
}

class DefaultLogoutUseCase: LogoutUseCase {
    private let sessionRepository: SessionRepository

    init(sessionRepository: SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    func execute() {
        sessionRepository.logout()
    }
}
