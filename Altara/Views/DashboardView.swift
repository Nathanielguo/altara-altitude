import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(ObservationService.self) private var observation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("motionEnabled") private var motionEnabled = true
    @AppStorage("unit") private var unitRaw = AltitudeUnit.meters.rawValue
    @AppStorage("coordinateFormat") private var coordinateRaw = CoordinateFormat.decimal.rawValue
    @State private var showSave = false
    @State private var showInfo = false
    @State private var copied = false
    @State private var historyRevealed = false
    @State private var heroVisible = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var unit: AltitudeUnit { AltitudeUnit(rawValue: unitRaw) ?? .meters }
    private var format: CoordinateFormat { CoordinateFormat(rawValue: coordinateRaw) ?? .decimal }
    private var sample: AltitudeSnapshot? { observation.snapshot }
    private var motionActive: Bool { !reduceMotion && motionEnabled && !lowPower && scenePhase == .active }
    private var altitudeText: String { unit.text(sample?.validAltitude == true ? sample?.altitude : nil) }
    private var pressureText: String { observation.pressure.map { String(format: "%.1f", $0) } ?? "—" }
    private var relativeText: String { observation.relativeAltitude.map { String(format: "%+.1f", unit.convert($0)) } ?? "—" }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if geometry.size.width >= 760 {
                        HStack(alignment: .top, spacing: 24) {
                            hero.frame(maxWidth: .infinity)
                            VStack(spacing: 18) { metrics; permissionCard }
                                .frame(width: min(390, geometry.size.width * 0.38))
                        }
                    } else {
                        hero
                        permissionCard
                        metrics
                    }
                    history
                    HStack(spacing: 8) {
                        Image(systemName: "location.circle")
                        Text("位置留在你的设备上，核心观测无需联网。")
                    }.font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .padding(.horizontal, geometry.size.width >= 760 ? 28 : 20)
                .padding(.top, 8).padding(.bottom, 28)
                .frame(maxWidth: 1220).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .background(Color.canvas)
        .navigationTitle("岚标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("测量说明", systemImage: "info") { showInfo = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存地点", systemImage: "bookmark") { showSave = true }
                    .disabled(!(sample?.isFresh() ?? false))
            }
        }
        .sheet(isPresented: $showSave) { SavePlaceView() }
        .sheet(isPresented: $showInfo) { MeasurementInfoView() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ALTARA / FIELD NOTES").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2.5).foregroundStyle(.secondary)
                Text("此刻，自有高度。").font(.title2.weight(.semibold))
            }
            Spacer(minLength: 12)
            Image(systemName: "mountain.2.fill").font(.title2).foregroundStyle(Color.glacier)
                .symbolEffect(.breathe, options: .repeating, isActive: observation.isRunning && motionActive && heroVisible)
                .accessibilityHidden(true)
        }.padding(.vertical, 8)
    }
    private var hero: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: observation.isRunning ? "location.fill" : "location.slash")
                    .font(.system(size: 10)).foregroundStyle(Color.glacier)
                    .symbolEffect(.pulse, isActive: observation.isRunning && motionActive && heroVisible)
                TimelineView(.periodic(from: .now, by: 15)) { _ in
                    Text(observation.status).font(.caption.weight(.medium))
                }
                Spacer()
                Text("WGS 84")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).opacity(0.55)
            }.padding(18)
            Spacer(minLength: 6)
            Text("当前海拔").font(.subheadline).foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(altitudeText)
                    .font(.system(size: 88, weight: .light, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.35).lineLimit(1)
                    .contentTransition(motionActive ? .numericText() : .identity)
                    .animation(motionActive ? .spring(response: 0.55, dampingFraction: 1) : nil, value: altitudeText)
                Menu {
                    ForEach(AltitudeUnit.allCases, id: \.rawValue) { value in Button(value.title) { unitRaw = value.rawValue } }
                } label: {
                    Text(unit.symbol).font(.title2.weight(.light)).foregroundStyle(.white.opacity(0.65))
                        .padding(.vertical, 8)
                }.accessibilityLabel("海拔单位，\(unit.title)")
            }.padding(.horizontal, 28)
            TimelineView(.periodic(from: .now, by: 15)) { _ in
                HStack(spacing: 6) {
                    Image(systemName: sample?.validAltitude == true ? "scope" : "antenna.radiowaves.left.and.right")
                    if let sample, sample.validAltitude, let accuracy = sample.verticalAccuracy {
                        Text("精度 ±\(unit.text(accuracy)) \(unit.symbol)")
                        Text("·")
                        Text(sample.isFresh() ? "最近观测" : "旧读数")
                    } else { Text("等待有效海拔") }
                }.font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 22)
            coordinates
                .padding(.horizontal, 16).padding(.bottom, 16)
                .environment(\.colorScheme, .dark)
        }
        .foregroundStyle(.white)
        .frame(minHeight: 360)
        .background { MountainBackdrop(isVisible: heroVisible) }
        .clipShape(.rect(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(.white.opacity(0.10)))
        .accessibilityElement(children: .contain)
        .onScrollVisibilityChange(threshold: 0.05) { heroVisible = $0 }
    }
    @ViewBuilder private var permissionCard: some View {
        if !observation.canLocate {
            InstrumentPanel {
                Label("从你的位置开始", systemImage: "location").font(.headline)
                Text(observation.message).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
                Button(observation.isDenied ? "打开系统设置" : "允许定位") {
                    if observation.isDenied, let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    else { observation.request() }
                }.buttonStyle(.glassProminent).tint(.glacier)
            }
        } else if sample?.validAltitude != true {
            InstrumentPanel {
                Label("海拔暂不可用", systemImage: "antenna.radiowaves.left.and.right").font(.subheadline.weight(.semibold))
                Text(observation.message).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
    }
    private var coordinates: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("经纬度", systemImage: "scope").font(.caption.weight(.semibold))
                Spacer()
                Button(copied ? "已复制" : "复制坐标", systemImage: copied ? "checkmark" : "square.on.square") {
                    guard let sample else { return }
                    UIPasteboard.general.string = "\(format.text(sample.latitude, latitude: true)), \(format.text(sample.longitude, latitude: false))"
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 36).disabled(sample == nil)
                    .contentTransition(motionActive ? .symbolEffect(.replace) : .identity)
                    .animation(motionActive ? .snappy(duration: 0.25) : nil, value: copied)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { coordinateValue(latitude: true); Spacer(minLength: 8); coordinateValue(latitude: false) }
                VStack(alignment: .leading, spacing: 12) { coordinateValue(latitude: true); coordinateValue(latitude: false) }
            }
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                HStack {
                    if let sample {
                        Text("水平精度 ±\(Int(sample.horizontalAccuracy.rounded())) m")
                        Spacer()
                        Text("\(Text(sample.date, style: .relative))前")
                    } else { Text("允许定位后显示真实坐标") }
                }.font(.caption2).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 14)
        .background(Color.ink.opacity(0.78), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08)))
    }
    private func coordinateValue(latitude: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(latitude ? "纬度 / LATITUDE" : "经度 / LONGITUDE")
                .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(0.8).foregroundStyle(.secondary)
            Text(sample.map { format.text(latitude ? $0.latitude : $0.longitude, latitude: latitude) } ?? "—")
                .font(.system(.body, design: .monospaced).weight(.medium)).lineLimit(1).minimumScaleFactor(0.65)
                .textSelection(.enabled)
        }
    }
    private var metrics: some View {
        HStack(alignment: .top, spacing: 14) {
            InstrumentPanel {
                Label("气压", systemImage: "barometer").font(.caption).foregroundStyle(.secondary)
                Text(pressureText)
                    .font(.system(.title2, design: .rounded).weight(.medium)).monospacedDigit().padding(.top, 10)
                    .contentTransition(motionActive ? .numericText() : .identity)
                    .animation(motionActive ? .easeInOut(duration: 0.35) : nil, value: pressureText)
                Text("hPa · 设备传感器").font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 2)
            }
            InstrumentPanel {
                Label("相对高度", systemImage: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                Text(relativeText)
                    .font(.system(.title2, design: .rounded).weight(.medium)).monospacedDigit().padding(.top, 10)
                    .contentTransition(motionActive ? .numericText() : .identity)
                    .animation(motionActive ? .easeInOut(duration: 0.35) : nil, value: relativeText)
                Text("\(unit.symbol) · 本次观测起点").font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 2)
            }
        }
    }
    private var history: some View {
        InstrumentPanel {
            SectionHeading(title: "高度的轨迹", caption: "本次前台观测")
            if points.count >= 2 {
                Chart(points) { point in
                    AreaMark(x: .value("时间", point.date), yStart: .value("基线", chartMinimum), yEnd: .value("高度", point.value))
                        .foregroundStyle(LinearGradient(colors: [.glacier.opacity(0.25), .glacier.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("时间", point.date), y: .value("高度", point.value))
                        .foregroundStyle(Color.glacier).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: chartMinimum...chartMaximum)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(.primary.opacity(0.05)); AxisValueLabel() } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.hour().minute()) } }
                .frame(height: 135).padding(.top, 20)
                .mask(alignment: .leading) {
                    GeometryReader { geometry in
                        Rectangle().frame(width: geometry.size.width * (historyRevealed || !motionActive ? 1 : 0))
                    }
                }
                .onAppear {
                    withAnimation(motionActive ? .easeOut(duration: 0.85) : nil) { historyRevealed = true }
                }
                .accessibilityLabel("海拔历史曲线，单位\(unit.title)，\(points.count)个采样点")
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.path").font(.largeTitle).foregroundStyle(Color.glacier.opacity(0.7))
                    Text("让高度留下轨迹").font(.subheadline)
                    Text("获取有效海拔后，曲线会随前台观测逐步绘制。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).frame(minHeight: 145)
            }
            Text("\(unit.symbol) · 定位误差可能导致曲线波动，不能直接视作累计爬升。")
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 12)
        }
    }
    private struct Point: Identifiable { var id: Int; var date: Date; var value: Double }
    private var points: [Point] {
        return observation.history.enumerated().compactMap { index, sample in
            guard sample.validAltitude, let altitude = sample.altitude else { return nil }
            return Point(id: index, date: sample.date, value: unit.convert(altitude))
        }
    }
    private var chartMinimum: Double { (points.map(\.value).min() ?? 0) - max(2, unit.convert(2)) }
    private var chartMaximum: Double { (points.map(\.value).max() ?? 10) + max(2, unit.convert(2)) }
}
