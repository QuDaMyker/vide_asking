import Foundation
import os.log

protocol Log {
    func info(_ message: String)
    func debug(_ message: String)
    func error(_ message: String)
}

class AppLogger: Log {
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier!, category: "App")

    func info(_ message: String) {
        logger.info("\(message)")
    }

    func debug(_ message: String) {
        logger.debug("\(message)")
    }

    func error(_ message: String) {
        logger.error("\(message)")
    }
}
