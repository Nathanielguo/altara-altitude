import ActivityKit
import Foundation

struct ObservationAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var altitude: Double?
        var latitude: Double
        var longitude: Double
        var date: Date
        var unit: String
        var accuracy: Double?
    }
    var name: String = "岚标观测"
}
