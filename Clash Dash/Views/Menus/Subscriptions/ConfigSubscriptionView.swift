import SwiftUI

struct ConfigSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ConfigSubscriptionViewModel
    let server: ClashServer
    
    @State private var showingAddSheet = false
    @State private var editingSubscription: ConfigSubscription?
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ConfigSubscriptionViewModel(server: server))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        SubscriptionLoadingView()
                    } else if viewModel.subscriptions.isEmpty {
                        SubscriptionEmptyView()
                    } else {
                        SubscriptionList(
                            subscriptions: viewModel.subscriptions,
                            server: server,
                            onEdit: { editingSubscription = $0 },
                            onToggle: { sub, enabled in
                                Task { await viewModel.toggleSubscription(sub, enabled: enabled) }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .navigationTitle("订阅管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: { dismiss() })
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        // 更新按钮
                        Button {
                            Task {
                                do {
                                    try await viewModel.updateAllSubscriptions()
                                } catch {
                                    print("更新失败: \(error)")
                                    viewModel.errorMessage = error.localizedDescription
                                    viewModel.showError = true
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(viewModel.isUpdating)
                        
                        // 添加按钮
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isUpdating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SubscriptionEditView(
                viewModel: viewModel,
                onSave: { subscription in
                    Task {
                        await viewModel.addSubscription(subscription)
                    }
                }
            )
        }
        .sheet(item: $editingSubscription) { subscription in
            SubscriptionEditView(
                viewModel: viewModel,
                subscription: subscription,
                onSave: { updatedSubscription in
                    Task {
                        await viewModel.updateSubscription(updatedSubscription)
                    }
                }
            )
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadSubscriptions()
        }
    }
}