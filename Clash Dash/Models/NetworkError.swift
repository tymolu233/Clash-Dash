import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse(message: String)
    case unauthorized(message: String)
    case serverError(Int)
    case missingDependencies(String)
    case timeout(message: String)
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse(let message):
            return message
        case .unauthorized(let message):
            return message
        case .serverError(let code):
            return "服务器错误: \(code)"
        case .missingDependencies(let message):
            return message
        case .timeout(let message):
            return message
        }
    }
} 