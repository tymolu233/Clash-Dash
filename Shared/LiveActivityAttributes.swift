import Foundation
import ActivityKit

// 定义灵动岛活动的属性
public struct ClashSpeedAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var uploadSpeed: String
        public var downloadSpeed: String
        public var activeConnections: Int
        public var serverName: String
        
        public init(uploadSpeed: String, downloadSpeed: String, activeConnections: Int, serverName: String) {
            self.uploadSpeed = uploadSpeed
            self.downloadSpeed = downloadSpeed
            self.activeConnections = activeConnections
            self.serverName = serverName
        }
    }
    
    public var serverAddress: String
    public var serverName: String
    
    public init(serverAddress: String, serverName: String) {
        self.serverAddress = serverAddress
        self.serverName = serverName
    }
} 