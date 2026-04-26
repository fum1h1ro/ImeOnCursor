import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let knownSources: [InputSourceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(
                "IME切り替え時にカラー帯を表示",
                isOn: Binding(get: { store.bandEnabled }, set: { store.setBandEnabled($0) })
            )
            .padding([.top, .horizontal])

            if store.bandEnabled {
                BandSettingsSection(store: store)
                    .padding([.horizontal, .bottom])
            }

            Divider()

            if knownSources.isEmpty {
                Text("IMEを切り替えるとここに表示されます")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(knownSources, id: \.id) { source in
                    SourceRow(source: source, store: store)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 200)
    }
}

// MARK: - Band Settings

private struct BandSettingsSection: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("表示位置").font(.callout).foregroundColor(.secondary)
            HStack(spacing: 16) {
                ForEach(BandPosition.allCases, id: \.self) { pos in
                    Toggle(pos.label, isOn: positionBinding(for: pos))
                        .toggleStyle(.checkbox)
                }
            }

            HStack {
                Text("太さ:").foregroundColor(.secondary).font(.callout)
                Slider(value: thicknessBinding, in: 1...20, step: 1)
                Text("\(Int(store.bandThickness))pt")
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.top, 8)
    }

    private func positionBinding(for pos: BandPosition) -> Binding<Bool> {
        Binding(
            get: { store.bandPositions.contains(pos) },
            set: { isOn in
                var positions = store.bandPositions
                if isOn { positions.insert(pos) } else { positions.remove(pos) }
                store.setBandPositions(positions)
            }
        )
    }

    private var thicknessBinding: Binding<Double> {
        Binding(
            get: { Double(store.bandThickness) },
            set: { store.setBandThickness(CGFloat($0)) }
        )
    }
}

// MARK: - Source Row

private struct SourceRow: View {
    let source: InputSourceInfo
    @ObservedObject var store: SettingsStore

    @State private var selectedMode: ModeSelection = .timedShow
    @State private var timedSeconds: Double = 3.0

    private enum ModeSelection: String, CaseIterable {
        case alwaysShow = "常時表示"
        case timedShow = "切り替え後N秒"
        case hidden = "非表示"
    }

    private var bandColorBinding: Binding<Color> {
        Binding(
            get: {
                let nsColor = store.bandColor(for: source.id)
                    ?? BandWindowController.autoColor(for: source.id)
                return Color(nsColor)
            },
            set: { store.setBandColor(NSColor($0), for: source.id) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                InputSourceIconView(info: source, size: 28, cornerRadius: 6)
                Text(source.localizedName)
                    .fontWeight(.medium)
                Spacer()
                if store.bandEnabled {
                    ColorPicker("", selection: bandColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 36)
                }
                Picker("", selection: $selectedMode) {
                    ForEach(ModeSelection.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: selectedMode) { _ in applyMode() }
            }

            if selectedMode == .timedShow {
                HStack {
                    Text("表示時間:")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Slider(value: $timedSeconds, in: 1...10, step: 0.5)
                        .onChange(of: timedSeconds) { _ in applyMode() }
                    Text(String(format: "%.1f秒", timedSeconds))
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
        .onAppear { syncFromStore() }
    }

    private func syncFromStore() {
        switch store.mode(for: source.id) {
        case .alwaysShow:
            selectedMode = .alwaysShow
        case .timedShow(let s):
            selectedMode = .timedShow
            timedSeconds = s
        case .hidden:
            selectedMode = .hidden
        }
    }

    private func applyMode() {
        switch selectedMode {
        case .alwaysShow:
            store.setMode(.alwaysShow, for: source.id)
        case .timedShow:
            store.setMode(.timedShow(seconds: timedSeconds), for: source.id)
        case .hidden:
            store.setMode(.hidden, for: source.id)
        }
    }
}

// MARK: - InputSourceIconView

struct InputSourceIconView: View {
    let info: InputSourceInfo
    let size: CGFloat
    var cornerRadius: CGFloat? = nil

    private var radius: CGFloat { cornerRadius ?? size / 5 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.accentColor)
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.15)
            } else {
                Text(String(info.localizedName.prefix(2)))
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
