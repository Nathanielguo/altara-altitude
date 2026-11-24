import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(ObservationService.self) private var observation
    @Environment(LiveObservation.self) private var live
    @AppStorage("unit") private var unitRaw = AltitudeUnit.meters.rawValue
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("coordinateFormat") private var coordinateRaw = CoordinateFormat.decimal.rawValue
    @AppStorage("motionEnabled") private var motionEnabled = true
    @State private var showInfo = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(.rect(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("岚标 / Altara").font(.title3.weight(.semibold))
                        Text("你的随身高度仪").font(.subheadline).foregroundStyle(.secondary)
                        Text("V0.2 · PERSONAL EDITION").font(.system(size: 9, design: .monospaced)).tracking(1).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            Section {
                Picker("海拔单位", selection: $unitRaw) {
                    ForEach(AltitudeUnit.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("坐标格式", selection: $coordinateRaw) {
                    ForEach(CoordinateFormat.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("外观", selection: $appearance) {
                    Text("随系统").tag("system"); Text("深色山海").tag("dark"); Text("浅色晨光").tag("light")
                }
                Toggle("界面动态效果", isOn: $motionEnabled)
            } header: { Text("显示与单位") } footer: { Text("山景动效离屏或进入后台后暂停；低电量模式和“减弱动态效果”会停用持续装饰动画。玻璃控件跟随系统的透明度与辅助功能设置。") }
            Section("观测与传感器") {
                LabeledContent("气压计", value: observation.sensorMessage)
                Button("以此刻重置相对高度") { observation.resetRelative() }
                    .disabled(!observation.isRunning)
                Button("测量与精度说明") { showInfo = true }
            }
            Section {
                if live.activity == nil {
                    Button("在锁屏显示本次观测", systemImage: "waveform.path") {
                        if let sample = observation.snapshot { live.start(sample, unit: AltitudeUnit(rawValue: unitRaw) ?? .meters) }
                    }.disabled(observation.snapshot?.isFresh() != true)
                } else {
                    Button("结束锁屏观测", systemImage: "stop.circle") { live.end() }
                }
                if let error = live.error { Text(error).font(.caption).foregroundStyle(.orange) }
            } header: { Text("实时活动") } footer: {
                Text("此版本在 App 前台观测时更新锁屏与支持机型的灵动岛。离开 App 后显示最近读数与时间，超过两分钟标记为旧读数；不会持续在后台定位。")
            }
            Section {
                Label("桌面：长按空白处 → 编辑 → 添加小组件 → 岚标", systemImage: "square.grid.2x2")
                Label("锁屏：长按锁屏 → 自定 → 添加小组件 → 岚标", systemImage: "lock.rectangle")
                Button("请求更新已有小组件") { WidgetCenter.shared.reloadAllTimelines() }
                if !SnapshotStore.sharedAvailable {
                    Label("共享容器尚未生效。自行签名时，需要为主 App 和扩展配置同一个 App Group。", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } header: { Text("小组件") } footer: { Text("刷新时间由系统决定；小组件会注明观测时间，无有效数据时显示占位。锁屏坐标可被他人看到，请按需添加。") }
            Section {
                Text("无需账号 · 没有广告 · 收藏仅存本机").foregroundStyle(.secondary)
                Text("Wi-Fi 版 iPad 没有内置 GPS/GNSS。定位可用不代表能够取得有效海拔；气压与相对高度取决于设备传感器。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden).background(Color.canvas)
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInfo) { MeasurementInfoView() }
    }
}

struct MeasurementInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("海拔不是楼层高度") {
                    Text("系统定位提供相对海平面的海拔估计。它可能有数米到数十米甚至更大的误差，室内、遮挡和设备能力都会影响结果。")
                    Text("界面同时显示系统报告的垂直精度。无效的海拔不会替换为零；旧读数会注明观测时间。")
                }
                Section("气压与相对高度") {
                    Text("设备气压计提供气压和相对于本次观测起点的高度变化。气象与环境气压变化会影响结果；相对高度不是累计爬升，也不是独立校准后的海拔。")
                }
                Section("坐标与地图") {
                    Text("数字坐标按系统定位的 WGS 84 输出。地图交由 Apple MapKit 展示；不要直接把 WGS 84 数值当作其他地图坐标系使用。地图背景是示意山景，不代表你所在地的实际地形。")
                }
                Section("小组件与锁屏") {
                    Text("小组件是系统调度的观测快照，不是持续运行的定位仪。超过两分钟的观测会标记为旧读数；点击可回到 App 重新观测。")
                }
            }.navigationTitle("认识你的读数").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
