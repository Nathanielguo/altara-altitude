import SwiftUI

struct RootView: View {
    @Environment(ObservationService.self) private var observation
    @Environment(LiveObservation.self) private var live
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("unit") private var unitRaw = AltitudeUnit.meters.rawValue
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            Tab("观测", systemImage: "mountain.2", value: 0) { NavigationStack { DashboardView() } }
            Tab("地点", systemImage: "map", value: 1) { NavigationStack { PlacesView() } }
            Tab("设置", systemImage: "slider.horizontal.3", value: 2) { NavigationStack { SettingsView() } }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onOpenURL { url in
            if url.scheme == "altara" { selection = url.host == "places" ? 1 : 0 }
        }
        .task { observation.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { observation.start() }
            else if phase == .background { observation.stop() }
        }
        .onChange(of: observation.snapshot) { _, sample in
            live.update(sample, unit: AltitudeUnit(rawValue: unitRaw) ?? .meters)
        }
        .onChange(of: unitRaw) { _, value in
            SnapshotStore.defaults.set(value, forKey: "unit")
            live.update(observation.snapshot, unit: AltitudeUnit(rawValue: value) ?? .meters)
        }
    }
}
