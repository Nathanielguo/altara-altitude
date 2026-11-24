import ActivityKit
import Foundation
import Observation

@MainActor @Observable
final class LiveObservation {
    var activity: Activity<ObservationAttributes>?
    var error: String?
    private var lastUpdate = Date.distantPast
    init() { activity = Activity<ObservationAttributes>.activities.first }
    func start(_ sample: AltitudeSnapshot, unit: AltitudeUnit) {
        guard sample.isFresh(), sample.validCoordinate else { error = "请先获取真实位置。"; return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { error = "请在系统设置中允许实时活动。"; return }
        do {
            activity = try Activity.request(attributes: ObservationAttributes(),
                content: ActivityContent(state: state(sample, unit), staleDate: sample.date.addingTimeInterval(120)), pushType: nil)
            lastUpdate = Date()
            error = nil
        } catch { self.error = "实时活动启动失败：\(error.localizedDescription)" }
    }
    func update(_ sample: AltitudeSnapshot?, unit: AltitudeUnit) {
        guard let activity, let sample, sample.isFresh(),
              Date().timeIntervalSince(lastUpdate) > 15 else { return }
        lastUpdate = Date()
        Task { await activity.update(ActivityContent(state: state(sample, unit), staleDate: sample.date.addingTimeInterval(120))) }
    }
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
    private func state(_ sample: AltitudeSnapshot, _ unit: AltitudeUnit) -> ObservationAttributes.ContentState {
        .init(altitude: sample.validAltitude ? sample.altitude : nil, latitude: sample.latitude,
              longitude: sample.longitude, date: sample.date, unit: unit.rawValue, accuracy: sample.verticalAccuracy)
    }
}
