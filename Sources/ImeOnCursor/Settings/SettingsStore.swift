import AppKit
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
    @Published private(set) var bandEnabled: Bool = false
    @Published private(set) var bandPositions: Set<BandPosition> = [.top]
    @Published private(set) var bandThickness: CGFloat = 4
    @Published private(set) var bandColors: [String: String] = [:]

    private let defaults = UserDefaults.standard
    private let storageKey = "inputSourceDisplayModes"
    private let bandEnabledKey = "bandEnabled"
    private let bandPositionsKey = "inputSourceBandPositions"
    private let bandThicknessKey = "inputSourceBandThickness"
    private let bandColorsKey = "inputSourceBandColors"

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

    func setBandEnabled(_ enabled: Bool) {
        bandEnabled = enabled
        defaults.set(enabled, forKey: bandEnabledKey)
    }

    func setBandPositions(_ positions: Set<BandPosition>) {
        bandPositions = positions
        defaults.set(positions.map { $0.rawValue }, forKey: bandPositionsKey)
    }

    func setBandThickness(_ thickness: CGFloat) {
        bandThickness = thickness
        defaults.set(Double(thickness), forKey: bandThicknessKey)
    }

    func bandColor(for sourceID: String) -> NSColor? {
        guard let hex = bandColors[sourceID] else { return nil }
        return NSColor(hexRGB: hex)
    }

    func setBandColor(_ color: NSColor?, for sourceID: String) {
        if let color {
            bandColors[sourceID] = color.hexRGBString
        } else {
            bandColors.removeValue(forKey: sourceID)
        }
        saveBandColors()
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: DisplayMode].self, from: data) {
            modes = decoded
        }
        bandEnabled = defaults.bool(forKey: bandEnabledKey)
        if let raw = defaults.array(forKey: bandPositionsKey) as? [String] {
            let decoded = Set(raw.compactMap { BandPosition(rawValue: $0) })
            if !decoded.isEmpty { bandPositions = decoded }
        }
        let savedThickness = defaults.double(forKey: bandThicknessKey)
        if savedThickness > 0 { bandThickness = CGFloat(savedThickness) }
        if let data = defaults.data(forKey: bandColorsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            bandColors = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func saveBandColors() {
        guard let data = try? JSONEncoder().encode(bandColors) else { return }
        defaults.set(data, forKey: bandColorsKey)
    }
}
