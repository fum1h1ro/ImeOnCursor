import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let knownSources: [InputSourceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .frame(minWidth: 400, minHeight: 200)
    }
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                InputSourceIconView(info: source, size: 28, cornerRadius: 6)
                Text(source.localizedName)
                    .fontWeight(.medium)
                Spacer()
                Picker("", selection: $selectedMode) {
                    ForEach(ModeSelection.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: selectedMode) { _ in
                    applyMode()
                }
            }

            if selectedMode == .timedShow {
                HStack {
                    Text("表示時間:")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Slider(value: $timedSeconds, in: 1...10, step: 0.5)
                        .onChange(of: timedSeconds) { _ in
                            applyMode()
                        }
                    Text(String(format: "%.1f秒", timedSeconds))
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            syncFromStore()
        }
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
