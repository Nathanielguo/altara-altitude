import SwiftUI

@main
struct AltaraApp: App {
    @State private var observation = ObservationService()
    @State private var places = PlaceStore()
    @State private var live = LiveObservation()
    @AppStorage("appearance") private var appearance = "dark"
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(observation).environment(places).environment(live)
                .tint(.glacier)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)
        }
    }
}
