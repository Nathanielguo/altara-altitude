import SwiftUI
import WidgetKit
import CoreLocation

struct AltitudeEntry: TimelineEntry {
    var date: Date
    var sample: AltitudeSnapshot?
    var placeholder = false
    var unit: AltitudeUnit = .meters
    var stale: Bool { sample.map { !$0.isFresh(at: date) } ?? true }
}

struct AltitudeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AltitudeEntry { .init(date: .now, sample: nil, placeholder: true) }
    func getSnapshot(in context: Context, completion: @escaping (AltitudeEntry) -> Void) {
        completion(.init(date: .now, sample: context.isPreview ? nil : SnapshotStore.read(), placeholder: context.isPreview, unit: SnapshotStore.unit))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AltitudeEntry>) -> Void) {
        Task { @MainActor in
            WidgetLocationRequest.request { location in
                var sample = SnapshotStore.read()
                if let location, location.horizontalAccuracy >= 0,
                   abs(location.timestamp.timeIntervalSinceNow) < 60 {
                    let valid = location.verticalAccuracy >= 0 && location.altitude.isFinite
                    let fresh = AltitudeSnapshot(date: location.timestamp, latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude, altitude: valid ? location.altitude : nil,
                        horizontalAccuracy: location.horizontalAccuracy,
                        verticalAccuracy: valid ? location.verticalAccuracy : nil, source: "小组件系统定位")
                    if fresh.validCoordinate { sample = fresh; SnapshotStore.write(fresh) }
                }
                let now = Date()
                var entries = [AltitudeEntry(date: now, sample: sample, unit: SnapshotStore.unit)]
                if let sample, sample.date.addingTimeInterval(120) > now {
                    entries.append(.init(date: sample.date.addingTimeInterval(120), sample: sample, unit: SnapshotStore.unit))
                }
                completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
            }
        }
    }
}

// A single bounded location request. The widget never runs a continuous location loop.
@MainActor
final class WidgetLocationRequest: NSObject, @preconcurrency CLLocationManagerDelegate {
    private static var pending: [UUID: WidgetLocationRequest] = [:]
    private let id = UUID()
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?
    static func request(completion: @escaping (CLLocation?) -> Void) {
        let request = WidgetLocationRequest()
        request.completion = completion
        request.manager.delegate = request
        guard request.manager.isAuthorizedForWidgetUpdates else { completion(nil); return }
        pending[request.id] = request
        request.manager.desiredAccuracy = kCLLocationAccuracyBest
        request.manager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { request.finish(nil) }
    }
    private func finish(_ location: CLLocation?) {
        guard let completion else { return }
        self.completion = nil
        manager.stopUpdatingLocation()
        Self.pending[id] = nil
        completion(location)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { finish(locations.last) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
}

struct AltitudeWidgetView: View {
    let entry: AltitudeEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var altitude: String { entry.unit.text(entry.sample?.validAltitude == true ? entry.sample?.altitude : nil) }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("\(altitude) \(entry.unit.symbol)\(entry.stale ? " · 待更新" : "")", systemImage: "mountain.2")
            case .accessoryCircular:
                VStack(spacing: 1) {
                    Image(systemName: "mountain.2").font(.caption)
                    Text(altitude).font(.system(.headline, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
                    Text(entry.stale ? "待更新" : entry.unit.symbol).font(.system(size: 8))
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "mountain.2")
                        Text("\(altitude) \(entry.unit.symbol)").fontWeight(.semibold)
                        if entry.stale { Text("旧读数").font(.caption2) }
                    }
                    if let sample = entry.sample {
                        Text("\(String(format: "%.4f", sample.latitude)), \(String(format: "%.4f", sample.longitude))")
                            .font(.system(size: 10, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.6)
                    } else { Text("打开岚标开始观测").font(.caption2) }
                }
            default: homeWidget
            }
        }
        .widgetURL(URL(string: "altara://observe"))
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                ZStack {
                    Color(red: 0.025, green: 0.07, blue: 0.10)
                    if renderingMode == .fullColor {
                        Image("MountainLandscape").resizable().scaledToFill().opacity(0.38)
                        LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    }
                }
            }
        }
    }
    private var homeWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("岚标", systemImage: "mountain.2").font(.caption.weight(.medium))
                Spacer()
                if entry.placeholder { Text("预览").font(.caption2) }
                else if entry.stale { Text("待更新").font(.caption2) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(altitude).font(.system(size: family == .systemSmall ? 42 : 48, weight: .light, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
                    .widgetAccentable()
                Text(entry.unit.symbol).font(.callout)
                if family == .systemMedium { Spacer(); coordinateLines }
            }
            if family == .systemSmall { coordinateLines }
            Spacer(minLength: 0)
            if let sample = entry.sample {
                HStack(spacing: 3) {
                    if entry.stale { Text("旧读数 ·") }
                    Text("\(Text(sample.date, style: .relative))前")
                    if family == .systemMedium, let accuracy = sample.verticalAccuracy { Text("· ±\(entry.unit.text(accuracy)) \(entry.unit.symbol)") }
                }.font(.system(size: 10)).opacity(0.65)
            } else { Text("打开 App 开始观测").font(.caption2).opacity(0.7) }
        }
        .foregroundStyle(renderingMode == .fullColor ? Color.white : Color.primary)
    }
    private var coordinateLines: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let sample = entry.sample {
                Text(CoordinateFormat.decimal.text(sample.latitude, latitude: true))
                Text(CoordinateFormat.decimal.text(sample.longitude, latitude: false))
            } else { Text("纬度 —"); Text("经度 —") }
        }.font(.system(size: 10, design: .monospaced)).opacity(0.8).lineLimit(1).minimumScaleFactor(0.6)
    }
}

struct AltaraWidget: Widget {
    let kind = "AltaraAltitude"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AltitudeProvider()) { AltitudeWidgetView(entry: $0) }
            .configurationDisplayName("此刻的高度")
            .description("海拔、坐标与观测时间。刷新由系统安排。")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main struct AltaraWidgets: WidgetBundle {
    var body: some Widget { AltaraWidget(); ObservationLiveWidget() }
}
