import SwiftUI

extension Color {
    static let glacier = Color(red: 0.24, green: 0.86, blue: 0.80)
    static let ink = Color(red: 0.025, green: 0.065, blue: 0.10)
    static let canvas = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.025, green: 0.055, blue: 0.085, alpha: 1)
            : UIColor(red: 0.94, green: 0.96, blue: 0.96, alpha: 1)
    })
    static let panel = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.06, green: 0.10, blue: 0.14, alpha: 1) : .white
    })
}

struct InstrumentPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.06)))
    }
}

struct SectionHeading: View {
    var title: String
    var caption: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MountainBackdrop: View {
    var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("motionEnabled") private var motionEnabled = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || !motionEnabled || lowPower || !isVisible || scenePhase != .active)) { timeline in
            let phase = reduceMotion || !motionEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate / 14
            GeometryReader { geo in
                ZStack {
                    Color.ink
                    Image("MountainLandscape")
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width + 28, height: geo.size.height)
                        .offset(x: CGFloat(sin(phase)) * 9)
                        .opacity(reduceTransparency ? 0.65 : 0.88)
                    Canvas { context, size in
                        for index in 0..<8 {
                            var path = Path()
                            let base = size.height * 0.18 + Double(index) * 19
                            path.move(to: CGPoint(x: -20, y: base))
                            path.addCurve(to: CGPoint(x: size.width + 20, y: base + 42),
                                control1: CGPoint(x: size.width * 0.37, y: base - 90 + sin(phase + Double(index) / 5) * 12),
                                control2: CGPoint(x: size.width * 0.65, y: base + 90))
                            context.stroke(path, with: .color(.glacier.opacity(0.06)), lineWidth: 0.7)
                        }
                    }
                    LinearGradient(colors: [.ink.opacity(0.45), .clear, .ink.opacity(0.1), .ink], startPoint: .top, endPoint: .bottom)
                }
            }.clipped()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }
}
