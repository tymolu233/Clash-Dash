import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case missingDependencies(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .unauthorized:
            return "认证失败"
        case .serverError(let code):
            return "服务器错误（状态码：\(code)）"
        case .missingDependencies(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 