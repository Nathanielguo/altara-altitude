import SwiftUI
import WidgetKit
import ActivityKit

struct ObservationLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ObservationAttributes.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label(context.isStale ? "岚标 · 旧读数" : "岚标 · 最近观测", systemImage: "mountain.2")
                        .font(.caption)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value(context.state)).font(.system(size: 36, weight: .light, design: .rounded))
                        Text(unit(context.state).symbol).font(.subheadline)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(CoordinateFormat.decimal.text(context.state.latitude, latitude: true))
                    Text(CoordinateFormat.decimal.text(context.state.longitude, latitude: false))
                    Text("\(Text(context.state.date, style: .relative))前")
                }.font(.system(.caption2, design: .monospaced))
            }.padding(18)
                .activityBackgroundTint(Color(red: 0.04, green: 0.11, blue: 0.15))
                .activitySystemActionForegroundColor(.white).foregroundStyle(.white)
                .widgetURL(URL(string: "altara://observe"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("岚标", systemImage: "mountain.2").font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(value(context.state)) \(unit(context.state).symbol)").font(.title3)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text("\(CoordinateFormat.decimal.text(context.state.latitude, latitude: true)) · \(CoordinateFormat.decimal.text(context.state.longitude, latitude: false))")
                            .font(.system(.caption, design: .monospaced))
                        HStack {
                            Text(context.isStale ? "旧读数 · 打开 App 更新" : "最近观测")
                            Text("\(Text(context.state.date, style: .relative))前")
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "mountain.2").foregroundStyle(.mint)
            } compactTrailing: {
                Text("\(value(context.state))\(unit(context.state).symbol)").font(.caption2).monospacedDigit()
            } minimal: {
                Image(systemName: "mountain.2").foregroundStyle(.mint)
            }.widgetURL(URL(string: "altara://observe"))
        }
    }
    private func unit(_ state: ObservationAttributes.ContentState) -> AltitudeUnit { AltitudeUnit(rawValue: state.unit) ?? .meters }
    private func value(_ state: ObservationAttributes.ContentState) -> String { unit(state).text(state.altitude) }
}
