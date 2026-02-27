/*
 * Network Error Handler
 * 网络请求错误处理工具 - 统一的错误处理和重试机制
 */

import Foundation

class NetworkErrorHandler {

    // MARK: - Error Types

    enum NetworkError: LocalizedError {
        case invalidURL
        case noConnection
        case timeout
        case serverError(statusCode: Int, message: String?)
        case unauthorized
        case rateLimited
        case invalidResponse
        case decodingError
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的请求地址"
            case .noConnection:
                return "网络连接不可用，请检查网络设置"
            case .timeout:
                return "请求超时，请稍后重试"
            case .serverError(let code, let message):
                return message ?? "服务器错误 (\(code))"
            case .unauthorized:
                return "API Key 无效或已过期，请检查设置"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            case .invalidResponse:
                return "服务器返回格式错误"
            case .decodingError:
                return "数据解析失败"
            case .unknown(let error):
                return error.localizedDescription
            }
        }

        var isRetryable: Bool {
            switch self {
            case .noConnection, .timeout, .rateLimited, .serverError:
                return true
            case .invalidURL, .unauthorized, .invalidResponse, .decodingError, .unknown:
                return false
            }
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let defaultRetryCount = 3
        static let baseRetryDelay: TimeInterval = 1.0
        static let maxRetryDelay: TimeInterval = 10.0
    }

    // MARK: - Public Methods

    /// 执行带重试的网络请求
    /// - Parameters:
    ///   - request: URLRequest
    ///   - retryCount: 重试次数
    /// - Returns: 返回的数据
    static func executeWithRetry(
        _ request: URLRequest,
        retryCount: Int = Constants.defaultRetryCount
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                let result = try await URLSession.shared.data(for: request)
                return result
            } catch {
                lastError = error

                // 如果是最后一次尝试，不再等待
                if attempt < retryCount - 1 {
                    let networkError = self.classifyError(error)
                    if networkError.isRetryable {
                        let delay = self.calculateRetryDelay(attempt: attempt)
                        print("⚠️ [Network] Request failed (attempt \(attempt + 1)), retrying in \(delay)s...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
            }
        }

        throw lastError ?? NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }

    /// 分类错误类型
    static func classifyError(_ error: Error) -> NetworkError {
        let nsError = error as NSError

        // 检查是否是网络连接错误
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost:
                return .noConnection
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorUserCancelledAuthentication,
                 NSURLErrorUserAuthenticationRequired:
                return .unauthorized
            default:
                return .unknown(error)
            }
        }

        // 检查是否是HTTP错误
        if let httpResponse = error.userInfo[HTTPURLResponseKey] as? HTTPURLResponse {
            return classifyHTTPError(httpResponse)
        }

        return .unknown(error)
    }

    /// 分类HTTP错误
    static func classifyHTTPError(_ response: HTTPURLResponse) -> NetworkError {
        switch response.statusCode {
        case 401, 403:
            return .unauthorized
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(statusCode: response.statusCode, message: nil)
        case 400, 404, 422:
            return .invalidResponse
        default:
            return .serverError(statusCode: response.statusCode, message: nil)
        }
    }

    /// 从HTTP响应中提取错误信息
    static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // 尝试不同的错误字段
        if let error = json["error"] as? [String: Any] {
            return error["message"] as? String
        }

        if let message = json["message"] as? String {
            return message
        }

        if let error = json["error"] as? String {
            return error
        }

        return nil
    }

    // MARK: - Private Helpers

    /// 计算重试延迟（指数退避）
    private static func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = Constants.baseRetryDelay * pow(2.0, Double(attempt))
        return min(delay, Constants.maxRetryDelay)
    }
}

// MARK: - URLRequest Extension

extension URLRequest {

    /// 创建带有默认配置的URLRequest
    /// - Parameters:
    ///   - url: URL
    ///   - method: HTTP方法
    ///   - apiKey: API Key
    /// - timeout: 超时时间
    /// - Returns: URLRequest
    static func create(
        url: URL,
        method: String = "GET",
        apiKey: String? = nil,
        timeout: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout

        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }
}

// MARK: - URLSession Extension

extension URLSession {

    /// 带重试的data请求
    func dataWithRetry(for request: URLRequest, retryCount: Int = 3) async throws -> (Data, URLResponse) {
        return try await NetworkErrorHandler.executeWithRetry(request, retryCount: retryCount)
    }
}
