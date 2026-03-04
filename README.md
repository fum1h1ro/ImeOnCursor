# ImeOnCursor

macOS のメニューバーアプリ。IME（入力ソース）を切り替えたとき、テキスト入力カーソルのそばに現在の入力ソースのアイコンを表示します。

## スクリーンショット

テキストフィールドにフォーカスした状態で IME を切り替えると、キャレット直下にアイコンが表示されます。

## 動作要件

- macOS 13.0 以上
- アクセシビリティ権限（初回起動時に案内されます）

## インストール・ビルド

### 依存ツール

```bash
brew install xcodegen
```

### ビルド手順

```bash
# Xcode プロジェクトを生成
xcodegen generate

# コマンドラインでビルド
xcodebuild build -project ImeOnCursor.xcodeproj -scheme ImeOnCursor -configuration Release

# または Xcode で開く
open ImeOnCursor.xcodeproj
```

ビルド成果物は `~/Library/Developer/Xcode/DerivedData/` 以下に生成されます。

> **Note**: `project.yml` を編集した場合は `xcodegen generate` を再実行してください。ソースコードのみの変更であれば再実行不要です。

### 初回起動時

アクセシビリティ権限が必要です。起動するとダイアログが表示されるので、案内に従って **システム設定 > プライバシーとセキュリティ > アクセシビリティ** で許可してください。許可後は自動で動作を開始します。

> **開発中の注意**: デバッグビルドはリビルドのたびにバイナリパスが変わるため、アクセシビリティ一覧に古いエントリが残ることがあります。その場合は古いエントリを削除して新しいものにチェックを入れてください。

## 使い方

起動するとメニューバーにキーボードアイコンが表示されます。Dock には表示されません。

### 表示モード

**Preferences...** から入力ソースごとに表示モードを設定できます。

| モード | 動作 |
|---|---|
| 常時表示 | テキスト入力中は常にキャレット付近に表示 |
| 切り替え後 N 秒 | IME 切り替え直後から N 秒間表示（デフォルト） |
| 非表示 | 表示しない |

「切り替え後 N 秒」モードでは、スライダーで 1〜10 秒の範囲で表示時間を調整できます。

### 表示されない場合

- テキスト入力を受け付けていない要素（ボタン・Finder など）にフォーカスがある場合は表示しません
- アクセシビリティ権限が未取得の場合は表示されません

## プロジェクト構成

```
ime-on-cursor/
├── project.yml                        # XcodeGen 設定
├── ImeOnCursor.entitlements
├── Sources/ImeOnCursor/
│   ├── App.swift                      # エントリーポイント
│   ├── AppDelegate.swift              # コンポーネント初期化・協調
│   ├── InputSource/
│   │   ├── InputSourceInfo.swift      # 入力ソース情報モデル・アイコン取得
│   │   └── InputSourceObserver.swift  # CFNotification による IME 変更監視
│   ├── Overlay/
│   │   ├── OverlayWindowController.swift  # NSPanel 管理・キャレット追跡
│   │   └── OverlayView.swift              # オーバーレイ SwiftUI ビュー
│   ├── Settings/
│   │   ├── SettingsStore.swift        # 表示モード永続化（UserDefaults）
│   │   └── SettingsView.swift         # 設定 SwiftUI ビュー
│   └── StatusBar/
│       └── StatusBarController.swift  # メニューバーアイコン・設定ウィンドウ
└── Resources/
    └── Info.plist
```

## 技術的な詳細

### キャレット位置の取得

Accessibility API（`AXUIElementCreateSystemWide`）でフォーカス中の要素を取得し、`kAXBoundsForRangeParameterizedAttribute` でキャレット位置を取得します。未対応アプリでは `AXFrame`（要素フレーム）にフォールバックします。`kAXSelectedTextRangeAttribute` が取得できない要素（テキスト入力を受け付けていない）では表示しません。

### IME 変更の検知

`CFNotificationCenter`（distributed center）の `kTISNotifySelectedKeyboardInputSourceChanged` 通知を監視します。コールバックはバックグラウンドスレッドで発火するため、TIS 関数の呼び出しは `DispatchQueue.main.async` で行います。

### オーバーレイウィンドウ

`NSPanel` を `borderless` + `nonactivatingPanel` で作成し、`ignoresMouseEvents = true` で入力を奪いません。`collectionBehavior` に `.canJoinAllSpaces` を設定してフルスクリーンでも表示されます。

## ライセンス

MIT
