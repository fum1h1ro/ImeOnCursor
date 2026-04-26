# BezelHue

macOS のメニューバーアプリ。IME（入力ソース）を切り替えたとき、画面端にカラー帯を表示して現在の入力ソースを視覚的に通知します。

## 動作要件

- macOS 13.0 以上

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
xcodebuild build -project BezelHue.xcodeproj -scheme BezelHue -configuration Release

# または Xcode で開く
open BezelHue.xcodeproj
```

> **Note**: `project.yml` を編集した場合は `xcodegen generate` を再実行してください。ソースコードのみの変更であれば不要です。

## 使い方

起動するとメニューバーにキーボードアイコンが表示されます。Dock には表示されません。

**Preferences...** から入力ソースごとに表示設定を変更できます。

### カラー帯の設定

| 設定項目 | 内容 |
|---|---|
| ON/OFF | 帯の表示・非表示 |
| 表示位置 | 上端・下端・左端・右端（複数選択可） |
| 太さ | 1〜20pt |

### 表示モード（入力ソースごと）

| モード | 動作 |
|---|---|
| 常時表示 | 常に帯を表示 |
| 切り替え後 N 秒 | IME 切り替え直後から N 秒間表示（デフォルト） |
| 非表示 | 表示しない |

### 帯の色

入力ソースごとに色を設定できます。未設定の場合は入力ソース ID から自動で色が割り当てられます。

## プロジェクト構成

```
$ROOT/
├── project.yml                        # XcodeGen 設定
├── BezelHue.entitlements
├── Sources/BezelHue/
│   ├── App.swift                      # エントリーポイント
│   ├── AppDelegate.swift              # コンポーネント初期化・協調
│   ├── InputSource/
│   │   ├── InputSourceInfo.swift      # 入力ソース情報モデル・アイコン取得
│   │   └── InputSourceObserver.swift  # CFNotification による IME 変更監視
│   ├── Overlay/
│   │   └── BandWindowController.swift # カラー帯ウィンドウ管理
│   ├── Settings/
│   │   ├── SettingsStore.swift        # 設定の永続化（UserDefaults）
│   │   └── SettingsView.swift         # 設定 UI
│   └── StatusBar/
│       └── StatusBarController.swift  # メニューバーアイコン・設定ウィンドウ
└── Resources/
    └── Info.plist
```

## 技術的な詳細

### IME 変更の検知

`CFNotificationCenter`（distributed center）の `kTISNotifySelectedKeyboardInputSourceChanged` 通知を監視します。コールバックはバックグラウンドスレッドで発火するため、TIS 関数の呼び出しは `DispatchQueue.main.async` で行います。

### カラー帯ウィンドウ

`NSPanel` を `borderless` + `nonactivatingPanel` + `ignoresMouseEvents = true` で作成し、クリックを透過します。`level = .statusBar` + `.fullScreenAuxiliary` によりフルスクリーンアプリ上でも前面に表示されます。ディスプレイ構成が変わると `NSApplication.didChangeScreenParametersNotification` を受けて自動再構築します。

## ライセンス

MIT
