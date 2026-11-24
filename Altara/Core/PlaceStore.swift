import Foundation
import Observation

@MainActor @Observable
final class PlaceStore {
    var places: [SavedPlace] = []
    var error: String?
    private let url: URL
    private var canWrite = true
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = folder.appendingPathComponent("saved-places-v1.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                places = try JSONDecoder().decode([SavedPlace].self, from: Data(contentsOf: url))
            }
        } catch {
            canWrite = false // Preserve an unreadable archive rather than overwriting it.
            self.error = "地点存档无法读取，原文件已保留：\(error.localizedDescription)"
        }
    }
    @discardableResult func add(name: String, note: String, sample: AltitudeSnapshot) -> Bool {
        guard canWrite, sample.validCoordinate else {
            error = canWrite ? "请获取真实位置后再保存。" : "存档不可写，原文件已保留。"
            return false
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = SavedPlace(name: trimmed.isEmpty ? "未命名地点" : trimmed, note: note, snapshot: sample)
        let updated = [entry] + places
        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: url, options: .atomic)
            places = updated
            error = nil
            return true
        } catch { self.error = "保存失败：\(error.localizedDescription)"; return false }
    }
}
