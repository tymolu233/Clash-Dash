//
//  Clash_Dash.swift
//  Clash Dash
//
//  Created by Mou Yan on 11/19/24.
//

import SwiftUI
import Network
import BackgroundTasks

@main
struct Clash_Dash: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var bindingManager = WiFiBindingManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // 确保在应用启动时初始化BGTaskScheduler
        configureBackgroundTasks()
        
        // 请求本地网络访问权限
        Task { @MainActor in
            let localNetworkAuthorization = LocalNetworkAuthorization()
            _ = await localNetworkAuthorization.requestAuthorization()
            // print("Local network authorization status: \(authorized)")
        }
    }
    
    // 配置后台任务
    private func configureBackgroundTasks() {
        print("🔧 配置后台任务系统")
        
        // 确保在主线程上调用
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                configureBackgroundTasks()
            }
            return
        }
        
        // 注册后台任务处理器
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "ym.si.clashdash.updateLiveActivity", using: nil) { task in
            print("🔄 收到后台任务请求: \(task)")
            
            // 将任务转发给 LiveActivityManager 处理
            LiveActivityManager.shared.handleBackgroundTask(task)
        }
        
        print("✅ 后台任务处理器注册成功")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
                .environmentObject(bindingManager)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        // 应用进入后台时，调度后台任务
                        scheduleBackgroundTasks()
                    } else if newPhase == .active {
                        // 应用进入前台时，可以执行一些恢复操作
                        print("📱 应用进入前台")
                    }
                }
        }
    }
    
    // 调度后台任务
    private func scheduleBackgroundTasks() {
        print("📅 尝试调度后台任务")
        
        // 创建处理任务请求
        let request = BGProcessingTaskRequest(identifier: "ym.si.clashdash.updateLiveActivity")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // 设置较短的延迟时间，确保在应用进入后台后尽快执行
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15) // 15秒后开始
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ 后台任务调度成功，将在\(request.earliestBeginDate?.timeIntervalSinceNow ?? 0)秒后执行")
        } catch {
            print("❌ 后台任务调度失败: \(error.localizedDescription)")
            print("❌ 错误详情: \(error)")
            
            // 尝试诊断问题
            if let bgError = error as? BGTaskScheduler.Error {
                switch bgError.code {
                case .notPermitted:
                    print("⚠️ 应用没有权限执行后台任务，请检查Info.plist中的BGTaskSchedulerPermittedIdentifiers配置")
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
}
