//
//  APIInterceptor.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 7/11/25.
//

import Alamofire
import Foundation

final class APIInterceptor: RequestInterceptor, EventMonitor {

    weak var logoutHandler: LogoutHandler?
    private let retryLimit = 1

    /// Mỗi request sẽ có retryCount riêng, lưu bằng ID
    private var retryCounts: [UUID: Int] = [:]

    // ✅ FIX: Make accessToken thread-safe with a lock
    private let lock = NSLock()
    private var _accessToken: String?
    
    var accessToken: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _accessToken
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _accessToken = newValue
        }
    }

    func updateAccessToken(_ token: String) {
        self.accessToken = token
        print("🔐 Updated access token = \(token)")
    }

    // MARK: - PRINT BODY
    private func printBodyData(request: URLRequest) {
        if let bodyData = request.httpBody {
            if let json = try? JSONSerialization.jsonObject(with: bodyData),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let jsonString = String(data: pretty, encoding: .utf8) {
                print("📦 [Body]:\n\(jsonString)")
            }
        } else {
            print("📦 [Body] Empty")
        }
    }

    // MARK: - ADAPT (Add Authorization)
    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var request = urlRequest

        // ✅ FIX: Access token safely
        let token = self.accessToken
        
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("✅ Authorization header set: Bearer \(token.prefix(20))...")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No access token available")
            #endif
        }

        #if DEBUG
        print("➡️ [Request] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        print("🔑 token = \(token ?? "nil")")
        // Print all headers to verify Authorization is included
        if let headers = request.allHTTPHeaderFields {
            print("📋 [Headers]: \(headers)")
        }
        printBodyData(request: request)
        #endif

        completion(.success(request))
    }

    // MARK: - RETRY
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard
            let response = request.task?.response as? HTTPURLResponse,
            response.statusCode == 401
        else {
            completion(.doNotRetry)
            return
        }

        let requestID = request.id

        /// Lấy retryCount của riêng request này
        let currentRetry = retryCounts[requestID] ?? 0

        // ❌ Không refresh token — API dev của bạn KHÔNG support refresh => logout luôn
        print("❗️401 Detected → Logout user")

        Task { @MainActor in
            self.logoutHandler?.logout()
        }

        // reset counter
        retryCounts.removeValue(forKey: requestID)

        completion(.doNotRetry)
    }

    // MARK: - EventMonitor
    let queue = DispatchQueue(label: "com.rocket.interceptor")

    func requestDidResume(_ request: Request) {
        retryCounts[request.id] = 0
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        retryCounts.removeValue(forKey: request.id)
    }

    func requestDidFinish(_ request: Request) {
        guard let url = request.request?.url else { return }

        #if DEBUG
        print("✅ [Completed] → \(url.absoluteString)")
        #endif
    }

    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        guard let url = request.request?.url?.absoluteString else { return }

        #if DEBUG
        if let status = response.response?.statusCode {
            print("⬅️ [Response] \(status) from \(url)")
        }

        if let data = response.data {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let jsonString = String(data: pretty, encoding: .utf8) {
                print("📥 Response:\n\(jsonString)")
            } else if let raw = String(data: data, encoding: .utf8) {
                print("📥 Raw:\n\(raw)")
            }
        }
        #endif
    }
}
