import Foundation

extension URLSession {
    /// 返回一个支持自签证书的共享 URLSession 实例
    static var secure: URLSession {
        return URLSessionManager.shared.session
    }
    
    /// 创建一个支持自签证书的自定义 URLSession 实例
    static func makeSecure(timeoutInterval: TimeInterval = 30) -> URLSession {
        return URLSessionManager.shared.makeCustomSession(timeoutInterval: timeoutInterval)
    }
} 