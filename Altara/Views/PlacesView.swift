import SwiftUI
import MapKit

struct PlacesView: View {
    @Environment(PlaceStore.self) private var store
    @Environment(ObservationService.self) private var observation
    @AppStorage("unit") private var unitRaw = AltitudeUnit.meters.rawValue
    @State private var showSave = false
    @State private var selected: SavedPlace?
    @State private var camera: MapCameraPosition = .automatic
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR PERSONAL ATLAS").font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                        Text("把此刻，留在地图上。").font(.title2.weight(.semibold))
                    }
                    Map(position: $camera) {
                        if observation.canLocate { UserAnnotation() }
                        ForEach(store.places) { place in
                            Annotation(place.name, coordinate: .init(latitude: place.snapshot.latitude, longitude: place.snapshot.longitude)) {
                                Button { selected = place } label: {
                                    Image(systemName: "mountain.2.fill").padding(10)
                                        .foregroundStyle(Color.ink).background(Color.glacier, in: .circle)
                                }.accessibilityLabel("查看\(place.name)")
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls { MapCompass(); MapScaleView(); if observation.canLocate { MapUserLocationButton() } }
                    .frame(height: geometry.size.width > 700 ? 380 : 290)
                    .clipShape(.rect(cornerRadius: 28))
                    .overlay(alignment: .bottomLeading) {
                        Text("地图需要网络 · 收藏保存在本机")
                            .font(.caption2).padding(10).background(.regularMaterial, in: .capsule).padding(12)
                    }
                    SectionHeading(title: "我的地点", caption: "\(store.places.count) 个记忆坐标")
                    if let error = store.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                    }
                    if store.places.isEmpty {
                        ContentUnavailableView {
                            Label("第一处，留给此刻", systemImage: "bookmark")
                        } description: {
                            Text("保存当前位置、海拔和一段备注。\n这些地点仅储存在这台设备上。")
                        } actions: {
                            Button("保存当前位置") { showSave = true }
                                .buttonStyle(.glassProminent).disabled(!canSave)
                        }.padding(.vertical, 12)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(store.places) { place in
                                Button { selected = place } label: {
                                    InstrumentPanel {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(place.name).font(.headline).foregroundStyle(.primary)
                                                Text(place.snapshot.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text("\((AltitudeUnit(rawValue: unitRaw) ?? .meters).text(place.snapshot.altitude)) \((AltitudeUnit(rawValue: unitRaw) ?? .meters).symbol)")
                                                .font(.system(.title3, design: .rounded)).foregroundStyle(.primary)
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(22).frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }
        }
        .background(Color.canvas).navigationTitle("地点").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("保存地点", systemImage: "plus") { showSave = true }.disabled(!canSave) } }
        .sheet(isPresented: $showSave) { SavePlaceView() }
        .sheet(item: $selected) { PlaceDetailView(place: $0) }
    }
    private var canSave: Bool { observation.snapshot?.isFresh() == true }
}

struct SavePlaceView: View {
    @Environment(ObservationService.self) private var observation
    @Environment(PlaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var sample: AltitudeSnapshot?
    var body: some View {
        NavigationStack {
            Form {
                Section("给这处坐标一个名字") {
                    TextField("例如：山顶的风", text: $name).autocorrectionDisabled()
                    TextField("此刻的记忆（选填）", text: $note, axis: .vertical).lineLimit(3...5)
                }
                if let sample {
                    Section("保存的是这次观测快照") {
                        LabeledContent("纬度", value: CoordinateFormat.decimal.text(sample.latitude, latitude: true))
                        LabeledContent("经度", value: CoordinateFormat.decimal.text(sample.longitude, latitude: false))
                        LabeledContent("海拔", value: "\(AltitudeUnit.meters.text(sample.altitude)) m")
                        LabeledContent("观测时间") { Text(sample.date, style: .time) }
                    }
                }
                if let error = store.error { Text(error).foregroundStyle(.orange) }
            }
            .navigationTitle("收藏此刻").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let sample, store.add(name: name, note: note, sample: sample) { dismiss() }
                    }.disabled(sample == nil)
                }
            }
            .onAppear { if sample == nil { sample = observation.snapshot } }
        }.presentationDetents([.medium, .large])
    }
}

struct PlaceDetailView: View {
    let place: SavedPlace
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("海拔", value: "\(AltitudeUnit.meters.text(place.snapshot.altitude)) m")
                    LabeledContent("纬度", value: CoordinateFormat.decimal.text(place.snapshot.latitude, latitude: true))
                    LabeledContent("经度", value: CoordinateFormat.decimal.text(place.snapshot.longitude, latitude: false))
                    LabeledContent("观测时间") { Text(place.snapshot.date.formatted(date: .abbreviated, time: .shortened)) }
                    if let accuracy = place.snapshot.verticalAccuracy { LabeledContent("垂直精度", value: "±\(Int(accuracy)) m") }
                }
                if !place.note.isEmpty { Section("备注") { Text(place.note).textSelection(.enabled) } }
                Section {
                    ShareLink(item: "\(place.name)\n海拔 \(AltitudeUnit.meters.text(place.snapshot.altitude)) m\nWGS 84: \(place.snapshot.latitude), \(place.snapshot.longitude)\n\(place.snapshot.date.formatted())") {
                        Label("分享地点", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        let item = MKMapItem(location: CLLocation(latitude: place.snapshot.latitude, longitude: place.snapshot.longitude), address: nil)
                        item.name = place.name
                        item.openInMaps()
                    } label: { Label("在 Apple 地图中查看", systemImage: "map") }
                }
            }.navigationTitle(place.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
