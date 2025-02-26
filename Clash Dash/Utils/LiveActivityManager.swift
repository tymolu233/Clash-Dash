import Foundation
import ActivityKit
import SwiftUI
import Shared
import BackgroundTasks

// 删除本地定义的ClashSpeedAttributes，使用共享的定义
@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    // 使用条件编译来处理iOS版本兼容性
    #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
    private var activity: Activity<ClashSpeedAttributes>?
    #endif
    
    private var updateTimer: Timer?
    private var currentServer: ClashServer?
    private var networkMonitor = NetworkMonitor()
    private var isMonitoring = false
    private var dispatchTimer: DispatchSourceTimer?
    
    private init() {
        // 在初始化时检查是否有未完成的活动，如果有则恢复监控
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            let activities = Activity<ClashSpeedAttributes>.activities
            if !activities.isEmpty {
                print("🔄 发现未完成的灵动岛活动，尝试恢复监控")
                // 如果有活动，尝试恢复第一个活动
                if let firstActivity = activities.first {
                    activity = firstActivity
                    print("✅ 恢复活动: \(firstActivity.id)")
                    
                    // 尝试从UserDefaults恢复服务器信息
                    if let serverData = UserDefaults.standard.data(forKey: "LiveActivityCurrentServer"),
                       let server = try? JSONDecoder().decode(ClashServer.self, from: serverData) {
                        currentServer = server
                        print("✅ 恢复服务器信息: \(server.name)")
                        
                        // 启动网络监控
                        networkMonitor.startMonitoring(server: server, viewId: "liveActivity")
                        isMonitoring = true
                        print("📊 网络监控已恢复")
                        
                        // 开始定时更新
                        startUpdates()
                        print("⏱️ 定时更新已恢复")
                    }
                }
            }
        }
        #endif
    }
    
    // 启动灵动岛活动
    func startActivity(for server: ClashServer) {
        // 检查iOS版本
        guard #available(iOS 16.1, *) else {
            print("⚠️ 当前iOS版本不支持灵动岛活动")
            return
        }
        
        print("🔍 开始启动灵动岛活动")
        print("📱 设备信息: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        
        // 停止现有活动
        stopActivity()
        
        // 保存当前服务器
        self.currentServer = server
        print("🖥️ 服务器信息: \(server.name) (\(server.url))")
        
        // 将服务器信息保存到UserDefaults，以便应用重启时恢复
        if let serverData = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(serverData, forKey: "LiveActivityCurrentServer")
            print("💾 服务器信息已保存到UserDefaults")
        }
        
        // 检查系统是否支持灵动岛
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ 设备不支持灵动岛活动 (areActivitiesEnabled: false)")
            return
        }
        
        print("✅ 设备支持灵动岛活动 (areActivitiesEnabled: true)")
        
        // 启动网络监控
        networkMonitor.startMonitoring(server: server, viewId: "liveActivity")
        isMonitoring = true
        print("📊 网络监控已启动")
        
        // 创建活动属性
        let attributes = ClashSpeedAttributes(
            serverAddress: server.url,
            serverName: server.name
        )
        
        // 初始状态
        let initialState = ClashSpeedAttributes.ContentState(
            uploadSpeed: "0 B/s",
            downloadSpeed: "0 B/s",
            activeConnections: 0,
            serverName: server.name
        )
        
        print("📋 活动属性已创建")
        print("🔤 服务器名称: \(attributes.serverName)")
        print("🔤 服务器地址: \(attributes.serverAddress)")
        
        // 启动活动
        do {
            #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
            if #available(iOS 16.1, *) {
                print("🚀 请求创建灵动岛活动...")
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: initialState,
                    pushType: nil
                )
                print("✅ 成功启动灵动岛活动")
                print("🆔 活动ID: \(activity?.id ?? "未知")")
                
                // 开始定时更新
                startUpdates()
                print("⏱️ 定时更新已启动")
                
                // 检查活动状态
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                    if let activity = activity {
                        print("📊 活动状态: \(activity.activityState)")
                    } else {
                        print("⚠️ 活动对象为空")
                    }
                    
                    // 检查所有活动
                    let allActivities = Activity<ClashSpeedAttributes>.activities
                    print("📊 当前活动数量: \(allActivities.count)")
                    for (index, act) in allActivities.enumerated() {
                        print("📊 活动[\(index)]: ID=\(act.id), 状态=\(act.activityState)")
                    }
                }
            }
            #endif
        } catch {
            print("❌ 启动灵动岛活动失败: \(error.localizedDescription)")
            print("❌ 错误详情: \(error)")
        }
    }
    
    // 停止灵动岛活动
    func stopActivity() {
        print("🛑 开始停止灵动岛活动")
        
        // 停止定时器
        updateTimer?.invalidate()
        updateTimer = nil
        
        // 停止 DispatchSourceTimer
        if let dispatchTimer = dispatchTimer {
            dispatchTimer.cancel()
            self.dispatchTimer = nil
            print("⏱️ 调度定时器已停止")
        }
        
        // 停止网络监控
        if isMonitoring {
            networkMonitor.stopMonitoring()
            isMonitoring = false
            print("📊 网络监控已停止")
        }
        
        // 清除保存的服务器信息
        UserDefaults.standard.removeObject(forKey: "LiveActivityCurrentServer")
        print("🧹 UserDefaults中的服务器信息已清除")
        
        // 结束活动
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            print("🔍 查找活动进行停止...")
            let activities = Activity<ClashSpeedAttributes>.activities
            print("📊 找到 \(activities.count) 个活动")
            
            Task {
                for (index, activity) in activities.enumerated() {
                    print("🛑 正在停止活动[\(index)]: ID=\(activity.id)")
                    await activity.end(dismissalPolicy: .immediate)
                    print("✅ 活动[\(index)]已停止")
                }
            }
            
            activity = nil
            print("🧹 活动引用已清除")
        }
        #endif
        
        currentServer = nil
        print("🧹 服务器引用已清除")
    }
    
    // 开始定时更新
    private func startUpdates() {
        // 停止现有定时器
        updateTimer?.invalidate()
        updateTimer = nil
        
        // 停止现有的 DispatchSourceTimer
        if let dispatchTimer = dispatchTimer {
            dispatchTimer.cancel()
            self.dispatchTimer = nil
        }
        
        print("⏱️ 创建新的定时更新机制")
        
        // 使用更可靠的定时器实现
        let timerSource = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timerSource.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
        timerSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // 在主线程上执行更新
            DispatchQueue.main.async {
                Task { @MainActor in
                    print("⏱️ 定时器触发更新")
                    self.updateActivity()
                    
                    // 每次更新后检查活动状态
                    #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
                    if #available(iOS 16.1, *) {
                        if let activity = self.activity {
                            if activity.activityState == .dismissed {
                                print("⚠️ 活动已被系统关闭，尝试重新创建")
                                if let server = self.currentServer {
                                    self.startActivity(for: server)
                                }
                            }
                        } else if self.currentServer != nil {
                            // 如果有服务器但没有活动，尝试恢复
                            print("⚠️ 活动对象为空但有服务器信息，尝试恢复")
                            let activities = Activity<ClashSpeedAttributes>.activities
                            if !activities.isEmpty {
                                self.activity = activities.first
                                print("✅ 已恢复活动: \(activities.first?.id ?? "未知")")
                            } else if let server = self.currentServer {
                                // 如果没有活动但有服务器，尝试重新创建
                                print("⚠️ 没有找到活动，尝试重新创建")
                                self.startActivity(for: server)
                            }
                        }
                    }
                    #endif
                }
            }
        }
        
        // 启动定时器
        timerSource.resume()
        
        // 保存定时器引用
        self.dispatchTimer = timerSource
        
        print("✅ 定时更新机制已启动")
        
        // 注册后台任务，确保应用在后台也能更新灵动岛
        registerBackgroundTask()
    }
    
    // 注册后台任务
    private func registerBackgroundTask() {
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            print("📱 尝试提交后台任务请求")
            
            // 使用 BGProcessingTask 来确保后台更新
            let request = BGProcessingTaskRequest(identifier: "ym.si.clashdash.updateLiveActivity")
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30秒后开始
            
            do {
                // 先取消所有现有的相同标识符的任务请求
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "ym.si.clashdash.updateLiveActivity")
                
                // 然后提交新的请求
                try BGTaskScheduler.shared.submit(request)
                print("✅ 后台任务请求提交成功")
            } catch {
                print("❌ 后台任务请求提交失败: \(error.localizedDescription)")
                
                // 尝试诊断问题
                if let bgError = error as? BGTaskScheduler.Error {
                    switch bgError.code {
                    case .notPermitted:
                        print("⚠️ 应用没有权限执行后台任务，请检查Info.plist配置")
                    case .tooManyPendingTaskRequests:
                        print("⚠️ 已有太多待处理的任务请求")
                    case .unavailable:
                        print("⚠️ 后台任务调度器当前不可用")
                    @unknown default:
                        print("⚠️ 未知的后台任务调度器错误: \(bgError.code.rawValue)")
                    }
                }
            }
        }
        #endif
    }
    
    // 处理后台任务
    func handleBackgroundTask(_ task: BGTask) {
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            print("🔄 执行后台任务更新灵动岛")
            
            // 创建一个后台任务来更新活动
            let updateTask = Task { @MainActor in
                // 检查是否有活动需要更新
                if Activity<ClashSpeedAttributes>.activities.isEmpty {
                    print("⚠️ 没有活动需要更新，任务完成")
                    task.setTaskCompleted(success: true)
                    return
                }
                
                print("📊 发现 \(Activity<ClashSpeedAttributes>.activities.count) 个活动需要更新")
                
                // 如果当前没有活动对象但有系统活动，尝试恢复
                if self.activity == nil && !Activity<ClashSpeedAttributes>.activities.isEmpty {
                    self.activity = Activity<ClashSpeedAttributes>.activities.first
                    print("✅ 已恢复活动: \(self.activity?.id ?? "未知")")
                    
                    // 尝试从UserDefaults恢复服务器信息
                    if let serverData = UserDefaults.standard.data(forKey: "LiveActivityCurrentServer"),
                       let server = try? JSONDecoder().decode(ClashServer.self, from: serverData) {
                        self.currentServer = server
                        print("✅ 恢复服务器信息: \(server.name)")
                        
                        // 启动网络监控
                        if !self.isMonitoring {
                            self.networkMonitor.startMonitoring(server: server, viewId: "liveActivity")
                            self.isMonitoring = true
                            print("📊 网络监控已恢复")
                        }
                    }
                }
                
                // 执行更新
                self.updateActivity()
                
                // 完成后标记任务完成
                task.setTaskCompleted(success: true)
                print("✅ 后台任务完成")
                
                // 重新注册后台任务
                self.registerBackgroundTask()
            }
            
            // 设置任务过期处理
            task.expirationHandler = {
                updateTask.cancel()
                print("⚠️ 后台任务已过期")
            }
        }
        #endif
    }
    
    // 更新活动状态
    private func updateActivity() {
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        guard #available(iOS 16.1, *) else {
            print("⚠️ 当前iOS版本不支持灵动岛活动，跳过更新")
            return
        }
        
        guard let server = currentServer else {
            print("⚠️ 没有当前服务器信息，跳过更新")
            return
        }
        
        guard let activity = activity else {
            print("⚠️ 没有活动对象，跳过更新")
            
            // 检查是否有未关联的活动
            let activities = Activity<ClashSpeedAttributes>.activities
            if !activities.isEmpty {
                print("🔍 发现 \(activities.count) 个未关联的活动，尝试恢复")
                self.activity = activities.first
                print("✅ 已恢复活动: \(activities.first?.id ?? "未知")")
            } else {
                print("❌ 没有找到任何活动")
            }
            return
        }
        
        // 检查活动状态
        print("📊 活动状态: \(activity.activityState)")
        if activity.activityState == .dismissed {
            print("⚠️ 活动已被系统关闭，尝试重新创建")
            if let server = currentServer {
                Task {
                    startActivity(for: server)
                }
            }
            return
        }
        
        // 使用NetworkMonitor获取实时速度
        let uploadSpeed = networkMonitor.uploadSpeed
        let downloadSpeed = networkMonitor.downloadSpeed
        let activeConnections = networkMonitor.activeConnections
        
        print("📊 当前网络状态: ↑\(uploadSpeed) ↓\(downloadSpeed) 连接:\(activeConnections)")
        
        // 创建新状态
        let newState = ClashSpeedAttributes.ContentState(
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            activeConnections: activeConnections,
            serverName: server.name
        )
        
        // 更新活动
        Task {
            do {
                await activity.update(using: newState)
                print("✅ 活动已更新: ↑\(uploadSpeed) ↓\(downloadSpeed) 连接:\(activeConnections)")
            } catch {
                print("❌ 更新活动失败: \(error.localizedDescription)")
                
                // 如果更新失败，检查活动状态
                if activity.activityState == .dismissed {
                    print("⚠️ 活动已被系统关闭，尝试重新创建")
                    if let server = currentServer {
                        startActivity(for: server)
                    }
                }
            }
        }
        #endif
    }
    
    // 检查指定服务器的灵动岛活动是否正在运行
    func isActivityRunning(for server: ClashServer) -> Bool {
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            // 检查是否有活动正在运行
            let activities = Activity<ClashSpeedAttributes>.activities
            
            // 检查是否有匹配当前服务器的活动
            let isRunning = activities.contains { activity in
                return activity.attributes.serverAddress == server.url
            }
            
            print("🔍 检查服务器[\(server.name)]的活动状态: \(isRunning ? "运行中" : "未运行")")
            return isRunning
        }
        #endif
        return false
    }
    
    // 检查是否有任何灵动岛活动正在运行
    func isAnyActivityRunning() -> Bool {
        #if canImport(ActivityKit) && os(iOS) && compiler(>=5.7)
        if #available(iOS 16.1, *) {
            let isRunning = !Activity<ClashSpeedAttributes>.activities.isEmpty
            print("🔍 检查是否有任何活动运行: \(isRunning ? "是" : "否")")
            return isRunning
        }
        #endif
        return false
    }
} 
