//
//  NetworkLogger.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Comprehensive HTTP request/response logging
//

import Foundation
import Alamofire

// MARK: - Network Logger

class NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.app.networklogger")
    private let logger: AppLogger
    private let shouldLogBody: Bool
    private let shouldLogHeaders: Bool
    
    init(
        logger: AppLogger = .shared,
        shouldLogBody: Bool = true,
        shouldLogHeaders: Bool = true
    ) {
        self.logger = logger
        self.shouldLogBody = shouldLogBody
        self.shouldLogHeaders = shouldLogHeaders
    }
    
    // MARK: - Request Did Resume
    
    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else { return }
        
        logger.info("🚀 REQUEST STARTED")
        logger.info("URL: \(urlRequest.url?.absoluteString ?? "N/A")")
        logger.info("Method: \(urlRequest.httpMethod ?? "N/A")")
        logger.info("Request ID: \(urlRequest.value(forHTTPHeaderField: "X-Request-ID") ?? "N/A")")
        
        if shouldLogHeaders, let headers = urlRequest.allHTTPHeaderFields, !headers.isEmpty {
            logger.info("Headers:")
            headers.forEach { key, value in
                // Mask sensitive headers
                let maskedValue = shouldMaskHeader(key) ? "***MASKED***" : value
                logger.info("  \(key): \(maskedValue)")
            }
        }
        
        if shouldLogBody, let body = urlRequest.httpBody {
            if let bodyString = String(data: body, encoding: .utf8) {
                logger.info("Body: \(bodyString.prettyJSON)")
            } else {
                logger.info("Body: <binary data, \(body.count) bytes>")
            }
        }
        
        logger.info("─────────────────────────────────")
    }
    
    // MARK: - Request Did Finish
    
    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        let duration = request.metrics?.taskInterval.duration ?? 0
        
        logger.info("📥 RESPONSE RECEIVED")
        logger.info("URL: \(request.request?.url?.absoluteString ?? "N/A")")
        logger.info("Status Code: \(response.response?.statusCode ?? 0)")
        logger.info("Duration: \(String(format: "%.2f", duration))s")
        
        if shouldLogHeaders, let headers = response.response?.allHeaderFields as? [String: Any], !headers.isEmpty {
            logger.info("Headers:")
            headers.forEach { key, value in
                logger.info("  \(key): \(value)")
            }
        }
        
        switch response.result {
        case .success:
            logger.info("✅ SUCCESS")
            if shouldLogBody, let data = response.data {
                logResponseBody(data: data)
            }
            
        case .failure(let error):
            logger.error("❌ FAILURE")
            logger.error("Error: \(error.localizedDescription)")
            
            if let underlyingError = error.underlyingError {
                logger.error("Underlying Error: \(underlyingError.localizedDescription)")
            }
            
            if shouldLogBody, let data = response.data {
                logResponseBody(data: data, isError: true)
            }
        }
        
        // Log metrics
        if let metrics = request.metrics {
            logMetrics(metrics)
        }
        
        logger.info("═════════════════════════════════")
    }
    
    // MARK: - Request Did Fail
    
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {
        logger.error("🔴 REQUEST FAILED EARLY")
        logger.error("URL: \(request.request?.url?.absoluteString ?? "N/A")")
        logger.error("Error: \(error.localizedDescription)")
        
        if let underlyingError = error.underlyingError {
            logger.error("Underlying Error: \(underlyingError.localizedDescription)")
        }
        
        logger.error("═════════════════════════════════")
    }
    
    // MARK: - Private Helpers
    
    private func logResponseBody(data: Data, isError: Bool = false) {
        if let bodyString = String(data: data, encoding: .utf8) {
            let prefix = isError ? "Error Body:" : "Response Body:"
            logger.info("\(prefix) \(bodyString.prettyJSON)")
        } else {
            logger.info("Response Body: <binary data, \(data.count) bytes>")
        }
    }
    
    private func logMetrics(_ metrics: URLSessionTaskMetrics) {
        logger.debug("📊 METRICS")
        logger.debug("Total Duration: \(String(format: "%.2f", metrics.taskInterval.duration))s")
        
        if let transactionMetrics = metrics.transactionMetrics.last {
            if let fetchStart = transactionMetrics.fetchStartDate,
               let domainLookupStart = transactionMetrics.domainLookupStartDate {
                let dnsTime = domainLookupStart.timeIntervalSince(fetchStart)
                logger.debug("DNS Lookup: \(String(format: "%.2f", dnsTime))s")
            }
            
            if let connectStart = transactionMetrics.connectStartDate,
               let connectEnd = transactionMetrics.connectEndDate {
                let connectTime = connectEnd.timeIntervalSince(connectStart)
                logger.debug("Connection Time: \(String(format: "%.2f", connectTime))s")
            }
            
            if let secureConnectionStart = transactionMetrics.secureConnectionStartDate,
               let secureConnectionEnd = transactionMetrics.secureConnectionEndDate {
                let sslTime = secureConnectionEnd.timeIntervalSince(secureConnectionStart)
                logger.debug("SSL Handshake: \(String(format: "%.2f", sslTime))s")
            }
            
            if let requestStart = transactionMetrics.requestStartDate,
               let requestEnd = transactionMetrics.requestEndDate {
                let requestTime = requestEnd.timeIntervalSince(requestStart)
                logger.debug("Request Time: \(String(format: "%.2f", requestTime))s")
            }
            
            if let responseStart = transactionMetrics.responseStartDate,
               let responseEnd = transactionMetrics.responseEndDate {
                let responseTime = responseEnd.timeIntervalSince(responseStart)
                logger.debug("Response Time: \(String(format: "%.2f", responseTime))s")
            }
        }
    }
    
    private func shouldMaskHeader(_ key: String) -> Bool {
        let sensitiveHeaders = [
            "Authorization",
            "X-API-Key",
            "Cookie",
            "Set-Cookie",
            "Proxy-Authorization"
        ]
        return sensitiveHeaders.contains(where: { key.caseInsensitiveCompare($0) == .orderedSame })
    }
}

// MARK: - App Logger

class AppLogger {
    static let shared = AppLogger()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private let logQueue = DispatchQueue(label: "com.app.logger")
    private var logFileURL: URL?
    
    enum Level: String {
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARN"
        case error = "❌ ERROR"
        case debug = "🐛 DEBUG"
        
        var prefix: String {
            return rawValue
        }
    }
    
    init() {
        setupLogFile()
    }
    
    // MARK: - Public Methods
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func debug(_ message: String) {
        #if DEBUG
        log(message, level: .debug)
        #endif
    }
    
    // MARK: - Private Methods
    
    private func log(_ message: String, level: Level) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let logMessage = "[\(timestamp)] [\(level.prefix)] \(message)"
            
            // Console logging
            print(logMessage)
            
            // File logging
            self.writeToFile(logMessage)
        }
    }
    
    private func setupLogFile() {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }
        
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        logFileURL = logsDirectory.appendingPathComponent("network-\(dateString).log")
    }
    
    private func writeToFile(_ message: String) {
        #if DEBUG
        guard let fileURL = logFileURL else { return }
        
        let messageWithNewline = message + "\n"
        
        if let data = messageWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
        #endif
    }
    
    // MARK: - Log Management
    
    func getLogFileURL() -> URL? {
        return logFileURL
    }
    
    func clearLogs() {
        guard let fileURL = logFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - String Extensions

extension String {
    var prettyJSON: String {
        guard let data = self.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return self
        }
        return prettyString
    }
}

extension Dictionary {
    var prettyPrinted: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "\(self)"
        }
        return string
    }
}
