import SwiftUI

struct ClientTagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ConnectionsViewModel
    @ObservedObject var tagViewModel: ClientTagViewModel
    @State private var searchText = ""
    
    private var uniqueActiveConnections: [ClashConnection] {
        let activeConnections = viewModel.connections.filter { $0.isAlive }
        var uniqueIPs: Set<String> = []
        var uniqueConnections: [ClashConnection] = []
        
        for connection in activeConnections {
            let ip = connection.metadata.sourceIP
            if uniqueIPs.insert(ip).inserted {
                uniqueConnections.append(connection)
            }
        }
        
        return uniqueConnections
    }
    
    private var filteredTags: [ClientTag] {
        if searchText.isEmpty {
            return tagViewModel.tags
        }
        return tagViewModel.tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.ip.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredConnections: [ClashConnection] {
        if searchText.isEmpty {
            return uniqueActiveConnections
        }
        return uniqueActiveConnections.filter { 
            $0.metadata.sourceIP.localizedCaseInsensitiveContains(searchText) ||
            ($0.metadata.process ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        searchBar
                            .padding(.horizontal)
                        
                        if !filteredTags.isEmpty {
                            savedTagsSection
                        }
                        
                        if !filteredConnections.isEmpty {
                            activeConnectionsSection
                        }
                        
                        if filteredTags.isEmpty && filteredConnections.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("客户端标签")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $tagViewModel.showingSheet) {
                if let editingTag = tagViewModel.editingTag {
                    TagSheet(tag: editingTag, viewModel: tagViewModel, mode: .edit)
                } else if let ip = tagViewModel.selectedIP {
                    TagSheet(ip: ip, viewModel: tagViewModel, mode: .add)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索标签或IP", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    private var savedTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("已保存标签", systemImage: "tag.fill")
                    .font(.headline)
                Spacer()
                Text("\(filteredTags.count)个")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(filteredTags) { tag in
                    TagCard(tag: tag, viewModel: tagViewModel)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
    }
    
    private var activeConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("活跃连接", systemImage: "network")
                    .font(.headline)
                Spacer()
                Text("\(filteredConnections.count)个")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(filteredConnections) { connection in
                    ActiveConnectionCard(connection: connection, viewModel: tagViewModel)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("未找到匹配结果")
                .font(.headline)
            Text("尝试使用其他关键词搜索")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

struct TagCard: View {
    let tag: ClientTag
    @ObservedObject var viewModel: ClientTagViewModel
    @State private var offset: CGFloat = 0
    @State private var showingDeleteAlert = false
    @State private var isSwiped = false
    
    var body: some View {
        ZStack {
            // 背景按钮层
            HStack(spacing: 1) {
                Spacer()
                actionButtons
            }
            
            // 卡片内容
            cardContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .padding(.horizontal)
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                withAnimation {
                    viewModel.removeTag(tag)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除\"\(tag.name)\"标签吗？")
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            tagIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.system(.headline, design: .rounded))
                Text(tag.ip)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .opacity(isSwiped ? 0 : 0.5)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    private var tagIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.1))
            Image(systemName: "tag.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .frame(width: 28, height: 28)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 1) {
            Button {
                withAnimation(.spring()) {
                    offset = 0
                    isSwiped = false
                }
                viewModel.editTag(tag)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
            }
            
            Button {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 50, height: 50)
                    .background(Color.red)
                    .foregroundColor(.white)
            }
        }
        .cornerRadius(10)
        .opacity(isSwiped ? 1 : 0)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard value.translation.width < 0 else { return }
                withAnimation(.interactiveSpring()) {
                    offset = max(value.translation.width, -100)
                    isSwiped = offset < -30
                }
            }
            .onEnded { value in
                withAnimation(.spring()) {
                    if value.translation.width < -50 {
                        offset = -100
                        isSwiped = true
                    } else {
                        offset = 0
                        isSwiped = false
                    }
                }
            }
    }
}

struct ActiveConnectionCard: View {
    let connection: ClashConnection
    @ObservedObject var viewModel: ClientTagViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            connectionIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.metadata.sourceIP)
                    .font(.system(.headline, design: .monospaced))
                if let process = connection.metadata.process, !process.isEmpty {
                    Text(process)
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                viewModel.showAddTagSheet(for: connection.metadata.sourceIP)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var connectionIcon: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.1))
            Image(systemName: "network")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
        }
        .frame(width: 28, height: 28)
    }
}

struct TagSheet: View {
    enum Mode {
        case add
        case edit
    }
    
    let mode: Mode
    let ip: String
    @ObservedObject var viewModel: ClientTagViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(ip: String, viewModel: ClientTagViewModel, mode: Mode) {
        self.ip = ip
        self.viewModel = viewModel
        self.mode = mode
        _tagName = State(initialValue: "")
    }
    
    init(tag: ClientTag, viewModel: ClientTagViewModel, mode: Mode) {
        self.ip = tag.ip
        self.viewModel = viewModel
        self.mode = mode
        _tagName = State(initialValue: tag.name)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("标签名称", text: $tagName)
                        .textInputAutocapitalization(.never)
                        .focused($isTextFieldFocused)
                    
                    HStack {
                        Text("IP地址")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(ip)
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text(mode == .add ? "添加新标签" : "编辑标签")
                } footer: {
                    Text("为设备添加一个易记的标签名称，方便后续识别")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle(mode == .add ? "新建标签" : "编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.saveTag(name: tagName, ip: ip)
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .disabled(tagName.isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// 标签数据模型
struct ClientTag: Identifiable, Codable {
    let id: UUID
    var name: String
    var ip: String
    
    init(id: UUID = UUID(), name: String, ip: String) {
        self.id = id
        self.name = name
        self.ip = ip
    }
}

// 标签管理 ViewModel
class ClientTagViewModel: ObservableObject {
    @Published var tags: [ClientTag] = []
    @Published var showingSheet = false
    @Published var selectedIP: String?
    @Published var editingTag: ClientTag?
    
    private let saveKey = "ClientTags"
    
    init() {
        loadTags()
    }
    
    func showAddTagSheet(for ip: String) {
        selectedIP = ip
        editingTag = nil
        showingSheet = true
    }
    
    func editTag(_ tag: ClientTag) {
        editingTag = tag
        selectedIP = nil
        showingSheet = true
    }
    
    func saveTag(name: String, ip: String) {
        if let editingTag = editingTag {
            // 编辑现有标签
            if let index = tags.firstIndex(where: { $0.id == editingTag.id }) {
                tags[index].name = name
            }
        } else {
            // 添加新标签
            if let existingIndex = tags.firstIndex(where: { $0.ip == ip }) {
                tags[existingIndex].name = name
            } else {
                let tag = ClientTag(name: name, ip: ip)
                tags.append(tag)
            }
        }
        saveTags()
        self.editingTag = nil
    }
    
    func removeTag(_ tag: ClientTag) {
        tags.removeAll { $0.id == tag.id }
        saveTags()
    }
    
    func hasTag(for ip: String) -> Bool {
        tags.contains { $0.ip == ip }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func loadTags() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ClientTag].self, from: data) {
            tags = decoded
        }
    }
}

#Preview {
    ClientTagView(viewModel: ConnectionsViewModel(), tagViewModel: ClientTagViewModel())
} 
