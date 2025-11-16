//
//  NetworkLogger.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Detailed HTTP request/response logging with metrics
//

import Foundation
import Alamofire

// MARK: - Network Logger

class NetworkLogger: EventMonitor {
    
    // MARK: - Properties
    
    let queue = DispatchQueue(label: "com.app.network.logger")
    
    var isEnabled: Bool = true
    var logLevel: LogLevel = .verbose
    
    // MARK: - Log Level
    
    enum LogLevel: Int {
        case none = 0
        case error = 1
        case info = 2
        case verbose = 3
        
        var emoji: String {
            switch self {
            case .none: return ""
            case .error: return "❌"
            case .info: return "ℹ️"
            case .verbose: return "🔍"
            }
        }
    }
    
    // MARK: - Event Monitor Methods
    
    func requestDidResume(_ request: Request) {
        guard isEnabled, logLevel.rawValue >= LogLevel.verbose.rawValue else { return }
        
        logRequest(request)
    }
    
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        guard isEnabled else { return }
        
        logResponse(response, request: request)
    }
    
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {
        guard isEnabled, logLevel.rawValue >= LogLevel.error.rawValue else { return }
        
        logError(error, request: request)
    }
    
    // MARK: - Logging Methods
    
    private func logRequest(_ request: Request) {
        var output = [String]()
        
        output.append("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        output.append("📤 REQUEST")
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Method and URL
        if let httpMethod = request.request?.httpMethod,
           let url = request.request?.url?.absoluteString {
            output.append("🔹 \(httpMethod) \(url)")
        }
        
        // Headers
        if let headers = request.request?.allHTTPHeaderFields, !headers.isEmpty {
            output.append("\n📋 Headers:")
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                // Hide sensitive headers
                let displayValue = isSensitiveHeader(key) ? "***" : value
                output.append("   \(key): \(displayValue)")
            }
        }
        
        // Body
        if let body = request.request?.httpBody {
            output.append("\n📦 Body:")
            if let jsonString = prettyPrintJSON(data: body) {
                output.append(jsonString)
            } else if let bodyString = String(data: body, encoding: .utf8) {
                output.append(bodyString)
            } else {
                output.append("   <Binary data: \(body.count) bytes>")
            }
        }
        
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        print(output.joined(separator: "\n"))
    }
    
    private func logResponse<Value>(_ response: DataResponse<Value, AFError>, request: DataRequest) {
        var output = [String]()
        
        output.append("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Status code emoji and text
        if let statusCode = response.response?.statusCode {
            let emoji = statusCodeEmoji(statusCode)
            output.append("\(emoji) RESPONSE: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))")
        } else {
            output.append("📥 RESPONSE")
        }
        
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Request info
        if let httpMethod = request.request?.httpMethod,
           let url = request.request?.url?.absoluteString {
            output.append("🔹 \(httpMethod) \(url)")
        }
        
        // Timing
        if let metrics = response.metrics {
            let duration = metrics.taskInterval.duration
            output.append("⏱️  Duration: \(String(format: "%.3f", duration))s")
        }
        
        // Headers
        if let headers = response.response?.allHeaderFields as? [String: Any], !headers.isEmpty {
            output.append("\n📋 Response Headers:")
            for (key, value) in headers.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                output.append("   \(key): \(value)")
            }
        }
        
        // Response body
        output.append("\n📦 Response Body:")
        switch response.result {
        case .success:
            if let data = response.data {
                if let jsonString = prettyPrintJSON(data: data) {
                    output.append(jsonString)
                } else if let bodyString = String(data: data, encoding: .utf8) {
                    output.append(bodyString)
                } else {
                    output.append("   <Binary data: \(data.count) bytes>")
                }
            } else {
                output.append("   <No data>")
            }
            
        case .failure(let error):
            output.append("   ❌ Error: \(error.localizedDescription)")
            
            if let data = response.data,
               let errorString = String(data: data, encoding: .utf8) {
                output.append("\n   Error Data:")
                output.append("   \(errorString)")
            }
        }
        
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        print(output.joined(separator: "\n"))
    }
    
    private func logError(_ error: AFError, request: Request) {
        var output = [String]()
        
        output.append("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        output.append("❌ REQUEST ERROR")
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if let url = request.request?.url?.absoluteString {
            output.append("🔹 URL: \(url)")
        }
        
        output.append("📛 Error: \(error.localizedDescription)")
        
        if let underlyingError = error.underlyingError {
            output.append("📛 Underlying: \(underlyingError.localizedDescription)")
        }
        
        output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        print(output.joined(separator: "\n"))
    }
    
    // MARK: - Helper Methods
    
    private func prettyPrintJSON(data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        
        // Indent each line
        let lines = prettyString.components(separatedBy: "\n")
        let indented = lines.map { "   " + $0 }.joined(separator: "\n")
        return indented
    }
    
    private func isSensitiveHeader(_ header: String) -> Bool {
        let sensitiveHeaders = ["authorization", "x-api-key", "x-auth-token"]
        return sensitiveHeaders.contains(header.lowercased())
    }
    
    private func statusCodeEmoji(_ statusCode: Int) -> String {
        switch statusCode {
        case 200...299:
            return "✅"
        case 300...399:
            return "🔄"
        case 400...499:
            return "⚠️"
        case 500...599:
            return "❌"
        default:
            return "📥"
        }
    }
}

// MARK: - Simple Logger (Without Alamofire Dependency)

class SimpleNetworkLogger {
    
    static let shared = SimpleNetworkLogger()
    
    var isEnabled: Bool = true
    
    private init() {}
    
    func log(request: URLRequest) {
        guard isEnabled else { return }
        
        print("\n📤 REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
        
        if let headers = request.allHTTPHeaderFields {
            print("Headers: \(headers)")
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
    }
    
    func log(response: URLResponse?, data: Data?, error: Error?) {
        guard isEnabled else { return }
        
        if let httpResponse = response as? HTTPURLResponse {
            let emoji = httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? "✅" : "❌"
            print("\n\(emoji) RESPONSE: \(httpResponse.statusCode)")
        }
        
        if let data = data,
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("Body: \(prettyString)")
        }
        
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Log File Manager

class LogFileManager {
    
    static let shared = LogFileManager()
    
    private let fileManager = FileManager.default
    private lazy var logDirectory: URL = {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let logDir = urls[0].appendingPathComponent("Logs", isDirectory: true)
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir
    }()
    
    private init() {}
    
    func writeLog(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "network_\(dateFormatter.string(from: Date())).log"
        
        let fileURL = logDirectory.appendingPathComponent(filename)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if fileManager.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
    
    func clearOldLogs(olderThan days: Int = 7) {
        guard let files = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 86400))
        
        for fileURL in files {
            if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modificationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
