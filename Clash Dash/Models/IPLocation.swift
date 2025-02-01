import Foundation
import CoreLocation

struct IPLocation: Codable, Identifiable {
    let id = UUID()
    let query: String
    let status: String
    let country: String
    let countryCode: String
    let region: String
    let regionName: String
    let city: String
    let zip: String
    let lat: Double
    let lon: Double
    let timezone: String
    let isp: String
    let org: String
    let `as`: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// 用于缓存的扩展
extension IPLocation {
    static func cacheKey(for ip: String) -> String {
        "ip_location_\(ip)"
    }
} 