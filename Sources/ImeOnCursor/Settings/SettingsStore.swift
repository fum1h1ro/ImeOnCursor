import Combine
import Foundation

enum DisplayMode: Codable, Equatable {
    case alwaysShow
    case timedShow(seconds: Double)
    case hidden

    private enum CodingKeys: String, CodingKey {
        case type, seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "alwaysShow":
            self = .alwaysShow
        case "timedShow":
            let seconds = try container.decodeIfPresent(Double.self, forKey: .seconds) ?? 3.0
            self = .timedShow(seconds: seconds)
        case "hidden":
            self = .hidden
        default:
            self = .timedShow(seconds: 3.0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .alwaysShow:
            try container.encode("alwaysShow", forKey: .type)
        case .timedShow(let seconds):
            try container.encode("timedShow", forKey: .type)
            try container.encode(seconds, forKey: .seconds)
        case .hidden:
            try container.encode("hidden", forKey: .type)
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var modes: [String: DisplayMode] = [:]

    private let defaults = UserDefaults.standard
    private let storageKey = "inputSourceDisplayModes"

    init() {
        load()
    }

    func mode(for sourceID: String) -> DisplayMode {
        modes[sourceID] ?? .timedShow(seconds: 3.0)
    }

    func setMode(_ mode: DisplayMode, for sourceID: String) {
        modes[sourceID] = mode
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DisplayMode].self, from: data)
        else { return }
        modes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
