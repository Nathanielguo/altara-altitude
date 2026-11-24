import Foundation

// Kept Foundation-only so conversion/validation logic can be tested without a device.
enum AltitudeUnit: String, CaseIterable, Codable {
    case meters, feet
    var symbol: String { self == .meters ? "m" : "ft" }
    var title: String { self == .meters ? "米" : "英尺" }
    func convert(_ meters: Double) -> Double { self == .meters ? meters : meters * 3.280839895 }
    func text(_ meters: Double?) -> String {
        guard let meters, meters.isFinite else { return "—" }
        return String(format: "%.0f", convert(meters).rounded())
    }
}

enum CoordinateFormat: String, CaseIterable {
    case decimal, dms
    var title: String { self == .decimal ? "十进制度" : "度分秒" }
    func text(_ value: Double, latitude: Bool) -> String {
        guard value.isFinite, abs(value) <= (latitude ? 90 : 180) else { return "—" }
        let hemisphere = latitude ? (value < 0 ? "S" : "N") : (value < 0 ? "W" : "E")
        if self == .decimal { return String(format: "%.5f° %@", abs(value), hemisphere) }
        let seconds = Int((abs(value) * 3600).rounded())
        return "\(seconds / 3600)° \((seconds % 3600) / 60)′ \(seconds % 60)″ \(hemisphere)"
    }
}

struct AltitudeSnapshot: Codable, Equatable {
    var date: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double
    var verticalAccuracy: Double?
    var pressure: Double?
    var relativeAltitude: Double?
    var source: String

    var validCoordinate: Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
            && horizontalAccuracy.isFinite && horizontalAccuracy >= 0
    }
    var validAltitude: Bool {
        guard let altitude, let verticalAccuracy else { return false }
        return altitude.isFinite && verticalAccuracy.isFinite && verticalAccuracy >= 0
    }
    func isFresh(at now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(date)
        return age >= -5 && age < 120
    }

}

struct SavedPlace: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var note: String
    var snapshot: AltitudeSnapshot
}

// The group must be provisioned for BOTH the app and widget when signing.
enum SnapshotStore {
    static let group = "group.com.nathaniel.altara"
    static let key = "latestAltitude.v1"
    static var sharedAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
    }
    static var defaults: UserDefaults {
        sharedAvailable ? (UserDefaults(suiteName: group) ?? .standard) : .standard
    }
    static func read() -> AltitudeSnapshot? {
        guard let data = defaults.data(forKey: key),
              let sample = try? JSONDecoder().decode(AltitudeSnapshot.self, from: data),
              sample.validCoordinate else { return nil }
        return sample
    }
    static func write(_ sample: AltitudeSnapshot) {
        guard sample.validCoordinate,
              let data = try? JSONEncoder().encode(sample) else { return }
        defaults.set(data, forKey: key)
    }
    static var unit: AltitudeUnit { AltitudeUnit(rawValue: defaults.string(forKey: "unit") ?? "") ?? .meters }
}
