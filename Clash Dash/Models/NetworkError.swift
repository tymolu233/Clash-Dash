import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized(message: String)
    case serverError(Int)
    case missingDependencies(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的服务器响应，请检查服务器配置"
        case .unauthorized(let message):
            return message
        case .serverError(let code):
            return "服务器错误（状态码：\(code)）"
        case .missingDependencies(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 