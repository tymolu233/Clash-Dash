import SwiftUI
import MapKit

struct ConnectionMapView: View {
    let connections: [ClashConnection]
    @StateObject private var viewModel = ConnectionMapViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 180)
    )
    @State private var mapType: MKMapType = .standard
    @State private var showLocationDetails: IPLocation?
    
    var body: some View {
        ZStack {
            // 地图视图
            Map(coordinateRegion: $region,
                interactionModes: .all,
                showsUserLocation: false,
                userTrackingMode: .none,
                annotationItems: viewModel.connectionLocations) { location in
                MapAnnotation(coordinate: location.coordinate) {
                    LocationAnnotationView(location: location) {
                        showLocationDetails = location
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
                                region = MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
                                    span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 180)
                                )
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
        .sheet(item: $showLocationDetails) { location in
            LocationDetailView(location: location)
        }
        .task {
            await viewModel.loadLocations(for: connections)
        }
    }
}

// 位置标注视图
private struct LocationAnnotationView: View {
    let location: IPLocation
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                    )
                
                Text(location.city)
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
    let location: IPLocation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("城市", value: location.city)
                    LabeledContent("地区", value: location.regionName)
                    LabeledContent("国家", value: location.country)
                }
                
                Section("网络信息") {
                    LabeledContent("ISP", value: location.isp)
                    LabeledContent("组织", value: location.org)
                    LabeledContent("AS", value: location.as)
                }
                
                Section("地理位置") {
                    LabeledContent("经度", value: String(format: "%.4f", location.lon))
                    LabeledContent("纬度", value: String(format: "%.4f", location.lat))
                    LabeledContent("时区", value: location.timezone)
                }
            }
            .navigationTitle(location.city)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

@MainActor
class ConnectionMapViewModel: ObservableObject {
    @Published var connectionLocations: [IPLocation] = []
    private let locationService = IPLocationService.shared
    
    func loadLocations(for connections: [ClashConnection]) async {
        var locations: [IPLocation] = []
        var uniqueHosts = Set<String>()
        
        for connection in connections {
            if connection.isAlive && uniqueHosts.insert(connection.metadata.host).inserted {
                do {
                    let location = try await locationService.getLocation(for: connection.metadata.host)
                    locations.append(location)
                } catch {
                    print("Error loading location for \(connection.metadata.host): \(error)")
                }
            }
        }
        
        connectionLocations = locations
    }
} 