import CoreLocation
import CoreMotion
import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class ObservationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let location = CLLocationManager()
    private let altimeter = CMAltimeter()
    private var lastWidgetReload = Date.distantPast
    var snapshot: AltitudeSnapshot?
    var history: [AltitudeSnapshot] = []
    var authorization: CLAuthorizationStatus = .notDetermined
    var isRunning = false
    var message = "允许定位，开始认识此刻的高度。"
    var pressure: Double?
    var relativeAltitude: Double?
    var sensorMessage = "正在检测气压计"

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 2
        authorization = location.authorizationStatus
        snapshot = SnapshotStore.read()
        sensorMessage = CMAltimeter.isRelativeAltitudeAvailable() ? "气压计就绪" : "此设备不提供气压计数据"
    }
    var canLocate: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }
    var status: String {
        if isDenied { return "定位未授权" }
        if !isRunning { return "观测已暂停" }
        guard let snapshot, snapshot.isFresh() else { return "正在获取位置" }
        return snapshot.validAltitude ? "正在观测" : "位置已获取 · 海拔不可用"
    }
    func request() {
        if authorization == .notDetermined { location.requestWhenInUseAuthorization() }
        else if canLocate { start() }
    }
    func start() {
        guard canLocate, !isRunning else { return }
        isRunning = true
        message = "正在获取卫星定位，户外开阔处通常更准确。"
        location.startUpdatingLocation()
        startPressure()
    }
    func stop() {
        location.stopUpdatingLocation()
        altimeter.stopRelativeAltitudeUpdates()
        isRunning = false
        pressure = nil
        relativeAltitude = nil
    }
    func resetRelative() {
        altimeter.stopRelativeAltitudeUpdates()
        relativeAltitude = nil
        if isRunning { startPressure() }
    }
    private func startPressure() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                if error != nil { self.sensorMessage = "气压计不可用，请检查运动与健身权限"; return }
                guard let data else { return }
                self.pressure = data.pressure.doubleValue * 10 // kPa → hPa
                self.relativeAltitude = data.relativeAltitude.doubleValue
                self.sensorMessage = "设备气压计 · 相对高度"
                // Do not advance the location timestamp when only pressure changes.
                if var sample = self.snapshot {
                    sample.pressure = self.pressure
                    sample.relativeAltitude = self.relativeAltitude
                    self.snapshot = sample
                }
            }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if canLocate { start() }
        else {
            stop()
            message = isDenied ? "请在系统设置中允许精确位置访问。" : "允许定位，开始认识此刻的高度。"
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning,
              let point = locations.last, point.horizontalAccuracy >= 0,
              abs(point.timestamp.timeIntervalSinceNow) < 30 else { return }
        let validAltitude = point.verticalAccuracy >= 0 && point.altitude.isFinite
        let sample = AltitudeSnapshot(date: point.timestamp,
            latitude: point.coordinate.latitude, longitude: point.coordinate.longitude,
            altitude: validAltitude ? point.altitude : nil,
            horizontalAccuracy: point.horizontalAccuracy,
            verticalAccuracy: validAltitude ? point.verticalAccuracy : nil,
            pressure: pressure, relativeAltitude: relativeAltitude, source: "系统定位 · WGS 84")
        guard sample.validCoordinate else { return }
        snapshot = sample
        message = validAltitude ? "系统定位海拔，精度受环境与设备影响。" : "当前位置无有效海拔，Wi-Fi 版 iPad 或室内环境可能出现此状态。"
        if sample.validAltitude, history.last.map({ sample.date.timeIntervalSince($0.date) >= 3 }) ?? true {
            history.append(sample)
            if history.count > 240 { history.removeFirst(history.count - 240) }
        }
        SnapshotStore.write(sample)
        if Date().timeIntervalSince(lastWidgetReload) > 60 {
            WidgetCenter.shared.reloadAllTimelines()
            lastWidgetReload = Date()
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown {
            message = "暂时无法定位，请移至开阔处并稍候。"
        } else { message = "定位暂不可用：\(error.localizedDescription)" }
    }
}
