import Foundation

@main struct AltitudeLogicTests {
    static func main() {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            guard condition() else { fatalError("FAIL: \(message)") }
        }
        expect(abs(AltitudeUnit.feet.convert(100) - 328.0839895) < 0.0001, "meters to feet")
        expect(AltitudeUnit.meters.text(-14) == "-14", "below sea-level altitude is valid")
        expect(AltitudeUnit.meters.text(nil) == "—", "missing is not zero")
        expect(AltitudeUnit.meters.text(.nan) == "—", "nonfinite data hidden")
        expect(AltitudeUnit.feet.text(.infinity) == "—", "infinite data hidden")
        expect(CoordinateFormat.decimal.text(-31.5, latitude: true) == "31.50000° S", "southern latitude")
        expect(CoordinateFormat.decimal.text(-121.5, latitude: false) == "121.50000° W", "western longitude")
        expect(CoordinateFormat.dms.text(12.999999, latitude: true) == "13° 0′ 0″ N", "DMS rollover")
        expect(CoordinateFormat.dms.text(90, latitude: true) == "90° 0′ 0″ N", "polar coordinate")
        expect(CoordinateFormat.decimal.text(91, latitude: true) == "—", "latitude bounds")
        expect(CoordinateFormat.dms.text(.nan, latitude: false) == "—", "invalid coordinate")
        let now = Date()
        var sample = AltitudeSnapshot(date: now, latitude: 0, longitude: 0, altitude: 0,
            horizontalAccuracy: 5, verticalAccuracy: 0, source: "test")
        expect(sample.validCoordinate, "zero latitude and longitude valid")
        expect(sample.validAltitude, "zero sea level and zero uncertainty valid")
        expect(sample.isFresh(at: now), "new reading fresh")
        expect(!sample.isFresh(at: now.addingTimeInterval(121)), "old reading stale")
        expect(!sample.isFresh(at: now.addingTimeInterval(-6)), "future reading rejected")
        sample.verticalAccuracy = -1
        expect(!sample.validAltitude, "negative vertical accuracy means unavailable")
        sample.verticalAccuracy = 8; sample.altitude = nil
        expect(!sample.validAltitude, "coordinate-only fix not altitude")
        sample.altitude = .infinity
        expect(!sample.validAltitude, "nonfinite altitude rejected")
        sample.horizontalAccuracy = -1
        expect(!sample.validCoordinate, "invalid horizontal accuracy rejected")
        sample.horizontalAccuracy = 5; sample.longitude = 181
        expect(!sample.validCoordinate, "longitude bounds")
        sample.longitude = .nan
        expect(!sample.validCoordinate, "nonfinite coordinate rejected")
        let stored = AltitudeSnapshot(date: now, latitude: 31, longitude: 121, altitude: nil,
            horizontalAccuracy: 5, verticalAccuracy: nil, source: "system location")
        let roundtrip = try! JSONDecoder().decode(AltitudeSnapshot.self, from: JSONEncoder().encode(stored))
        expect(roundtrip == stored, "coordinate-only readings survive persistence without invented altitude")
        var legacy = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as! [String: Any]
        legacy["isDemo"] = false
        let migrated = try! JSONDecoder().decode(AltitudeSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(migrated == stored, "previous-version real readings remain readable")
        print("PASS: \(checks) altitude, coordinate, validity and freshness checks")
    }
}
