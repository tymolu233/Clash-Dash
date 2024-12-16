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
                            onEdit: { editingSubscription = $0 },
                            onToggle: { subscription, enabled in
                                Task {
                                    await viewModel.toggleSubscription(subscription, enabled: enabled)
                                }
                            },
                            onUpdate: { subscription in
                                Task {
                                    await viewModel.updateSubscription(subscription)
                                }
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
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await viewModel.loadSubscriptions()
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
                onSave: { updated in
                    Task {
                        await viewModel.updateSubscription(updated)
                    }
                }
            )
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}