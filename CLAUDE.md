# ImeOnCursor

## 概要

macOS メニューバーアプリ。IME（入力ソース）切り替え時に画面端にカラー帯を表示して現在の入力ソースを視覚的に通知する。

## ビルド

```bash
# xcodeproj 再生成（project.yml 変更時のみ必要）
xcodegen generate

# ビルド
xcodebuild build -project ImeOnCursor.xcodeproj -scheme ImeOnCursor -configuration Debug

# 型チェックのみ
swiftc -typecheck -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos13.0 <files>
```

> `project.yml` に `schemes` セクションが定義されているので、`xcodegen generate` 後もスキームは自動生成される。

## 技術的な注意事項

### AX 権限チェック（macOS 26 / Darwin 25.x）

`AXIsProcessTrustedWithOptions([prompt: true])` は AX が許可済みでも false を返すことがある。そのため：
1. まず `prompt: false` で呼び出してAXサーバーとの接続を初期化する
2. `AXIsProcessTrusted()` の結果でダイアログ表示を判断する

### CFNotification / Carbon API

- `CFNotificationCenterAddObserver` は Carbon の C シグネチャ（`CFString` を受け取る）
- `RemoveObserver` は Swift overlay の `CFNotificationName` を使う
- TIS 関数はメインスレッド必須 → コールバック内では `DispatchQueue.main.async`

### BandWindowController フレーム計算

`screen.visibleFrame` は Dock + メニューバーを除いた矩形（Cocoa 座標系）。

| 位置 | 計算 |
|---|---|
| top | `x: sf.minX, y: vf.maxY - thickness, w: sf.width, h: thickness` |
| bottom | `x: sf.minX, y: vf.minY, w: sf.width, h: thickness` |
| left | `x: sf.minX, y: vf.minY, w: thickness, h: vf.height` |
| right | `x: sf.maxX - thickness, y: vf.minY, w: thickness, h: vf.height` |

### NSPanel 設定（帯ウィンドウ）

```swift
panel.level = .statusBar          // メニューバー直下に配置可能な高さ
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
panel.ignoresMouseEvents = true   // クリック透過
```

## ファイル構成

```
Sources/ImeOnCursor/
├── App.swift                      # @main エントリーポイント
├── AppDelegate.swift              # DI コーディネーター
├── InputSource/
│   ├── InputSourceInfo.swift      # TIS データモデル + アイコン読み込み
│   └── InputSourceObserver.swift  # CFNotification + Combine パブリッシャー
├── Overlay/
│   └── BandWindowController.swift # NSPanel 管理（位置・太さ・マルチディスプレイ）
├── Settings/
│   ├── SettingsStore.swift        # UserDefaults 永続化（DisplayMode / BandPosition）
│   └── SettingsView.swift         # SwiftUI 設定 UI + InputSourceIconView
└── StatusBar/
    └── StatusBarController.swift  # NSStatusItem + メニュー
```
