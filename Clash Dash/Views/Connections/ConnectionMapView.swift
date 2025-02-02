import SwiftUI
import MapKit

struct ConnectionMapView: View {
    let connections: [ClashConnection]
    let isActiveMode: Bool
    let searchText: String
    let selectedDevices: Set<String>
    
    @StateObject private var viewModel = ConnectionMapViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0), // 中国地理中心点
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)    // 适合查看整个中国的缩放级别
    )
    
    // 重置视图的区域
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    )
    
    @State private var mapType: MKMapType = .standard
    @State private var showLocationDetails: LocationCluster?
    
    var filteredConnections: [ClashConnection] {
        connections.filter { connection in
            // 根据活跃状态过滤
            let stateMatches = isActiveMode ? connection.isAlive : !connection.isAlive
            
            // 根据设备过滤
            let deviceMatches = !selectedDevices.contains(connection.metadata.sourceIP)
            
            // 根据搜索文本过滤
            let searchMatches = searchText.isEmpty || {
                let searchTerm = searchText.lowercased()
                let metadata = connection.metadata
                
                // 检查源 IP 和端口
                if "\(metadata.sourceIP):\(metadata.sourcePort)".lowercased().contains(searchTerm) {
                    return true
                }
                
                // 检查主机名
                if metadata.host.lowercased().contains(searchTerm) {
                    return true
                }
                
                return false
            }()
            
            return stateMatches && deviceMatches && searchMatches
        }
    }
    
    var body: some View {
        ZStack {
            // 地图视图
            Map(coordinateRegion: $region,
                interactionModes: .all,
                showsUserLocation: false,
                userTrackingMode: .none,
                annotationItems: viewModel.locationClusters) { cluster in
                MapAnnotation(coordinate: cluster.coordinate) {
                    LocationAnnotationView(cluster: cluster) {
                        showLocationDetails = cluster
                    }
                }
            }
            
            // 地图控制按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 地图样式切换
                        Button {
                            withAnimation {
                                mapType = mapType == .standard ? .hybrid : .standard
                            }
                        } label: {
                            Image(systemName: mapType == .standard ? "map" : "map.fill")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        // 重置视图
                        Button {
                            withAnimation {
                                region = defaultRegion
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $showLocationDetails) { cluster in
            LocationDetailView(cluster: cluster)
        }
        .task(id: filteredConnections.map { $0.id }) {
            await viewModel.loadLocations(for: filteredConnections)
        }
    }
}

// 位置聚合模型
struct LocationCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let locations: [LocationInfo]
    
    var count: Int { locations.count }
    var mainLocation: LocationInfo { locations[0] }
    
    struct LocationInfo {
        let location: IPLocation
        let sourceIP: String
        let destinationIP: String
    }
}

// 位置标注视图
private struct LocationAnnotationView: View {
    let cluster: LocationCluster
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                    
                    if cluster.count > 1 {
                        Text("\(cluster.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                    }
                }
                
                Text(cluster.mainLocation.location.city)
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
            }
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// 位置详情视图
private struct LocationDetailView: View {
    let cluster: LocationCluster
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(cluster.locations, id: \.destinationIP) { info in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // 基本信息
                            Group {
                                LabeledContent("源 IP", value: info.sourceIP)
                                LabeledContent("目标 IP", value: info.destinationIP)
                                LabeledContent("城市", value: info.location.city)
                                LabeledContent("地区", value: info.location.regionName)
                                LabeledContent("国家", value: info.location.country)
                            }
                            
                            Divider()
                            
                            // 网络信息
                            Group {
                                LabeledContent("ISP", value: info.location.isp)
                                LabeledContent("组织", value: info.location.org)
                                LabeledContent("AS", value: info.location.as)
                            }
                            
                            Divider()
                            
                            // 地理位置
                            Group {
                                LabeledContent("经度", value: String(format: "%.4f", info.location.lon))
                                LabeledContent("纬度", value: String(format: "%.4f", info.location.lat))
                                LabeledContent("时区", value: info.location.timezone)
                            }
                        }
                    }
                }
            }
            .navigationTitle(cluster.mainLocation.destinationIP)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

@MainActor
class ConnectionMapViewModel: ObservableObject {
    @Published var locationClusters: [LocationCluster] = []
    private let locationService = IPLocationService.shared
    
    func loadLocations(for connections: [ClashConnection]) async {
        var locationInfos: [LocationCluster.LocationInfo] = []
        var uniqueHosts = Set<String>()
        
        // 获取所有位置信息
        for connection in connections {
            if uniqueHosts.insert(connection.metadata.host).inserted {
                do {
                    let location = try await locationService.getLocation(for: connection.metadata.host)
                    let info = LocationCluster.LocationInfo(
                        location: location,
                        sourceIP: connection.metadata.sourceIP,
                        destinationIP: connection.metadata.host
                    )
                    locationInfos.append(info)
                } catch {
                    print("Error loading location for \(connection.metadata.host): \(error)")
                }
            }
        }
        
        // 按照坐标聚合
        var clusters: [LocationCluster] = []
        var processedLocations = Set<String>()
        
        for info in locationInfos {
            if processedLocations.contains(info.location.query) { continue }
            
            // 查找相同坐标的位置
            let sameLocations = locationInfos.filter { otherInfo in
                !processedLocations.contains(otherInfo.location.query) &&
                abs(otherInfo.location.lat - info.location.lat) < 0.01 &&
                abs(otherInfo.location.lon - info.location.lon) < 0.01
            }
            
            // 创建聚合
            let cluster = LocationCluster(
                coordinate: info.location.coordinate,
                locations: sameLocations
            )
            clusters.append(cluster)
            
            // 标记已处理的位置
            sameLocations.forEach { processedLocations.insert($0.location.query) }
        }
        
        locationClusters = clusters
    }
} 