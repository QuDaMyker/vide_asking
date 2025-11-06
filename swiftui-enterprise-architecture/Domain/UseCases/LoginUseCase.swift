import Foundation

protocol LoginUseCase {
    func execute()
}

class DefaultLoginUseCase: LoginUseCase {
    private let sessionRepository: SessionRepository

    init(sessionRepository: SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    func execute() {
        sessionRepository.login()
    }
}
