import AppKit
import SwiftUI

final class OverlayViewModel: ObservableObject {
    @Published var sourceInfo: InputSourceInfo?
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        if let info = viewModel.sourceInfo {
            InputSourceIconView(info: info, size: 48)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
        }
    }
}

/// オーバーレイ・設定画面で共用するアイコンビュー。
/// アクセントカラーを下敷きに敷く。
struct InputSourceIconView: View {
    let info: InputSourceInfo
    let size: CGFloat
    var cornerRadius: CGFloat? = nil  // nilで自動（size/5）

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
