# 実機ビルドとTestFlight手順

GitHub Actionsでは、静的検証、シミュレータ向けXcodeビルド、UIテスト、シミュレータ用 `.app` artifact の作成まで確認します。iPhone実機へ入れるにはAppleの署名が必要です。

## 事前準備

- Apple Developer Programに入っているApple ID
- Xcode 16以降を入れたMac
- テスト用iPhone
- このPRのブランチ `codex/gemstone-dictionary-ios-build`
- Bundle ID `com.tokyonasu.gemstonedictionary`

## GitHub Actionsの成果物

1. PRの `GemstoneDictionary iOS Build` を開く。
2. 成功した最新runを開く。
3. Artifactsから `GemstoneDictionary-simulator-app` をダウンロードする。
4. これはシミュレータ確認用です。実機にはそのまま入りません。

## iPhoneへ直接入れる

1. Macでリポジトリを開く。
2. `ios/GemstoneDictionary/GemstoneDictionary.xcodeproj` をXcodeで開く。
3. `GemstoneDictionary` targetのSigning & Capabilitiesを開く。
4. Teamに自分のApple Developer Teamを選ぶ。
5. iPhoneをMacへ接続し、iPhone側で「このコンピュータを信頼」を押す。
6. Xcode上部の実行先を接続したiPhoneに変える。
7. Runを押す。
8. iPhoneでカメラ許可と写真許可の表示を確認する。
9. `REAL_DEVICE_QA.md` の実機チェックを埋める。

## TestFlightで配る

1. Xcodeで実機向けSigningが通る状態にする。
2. `Any iOS Device` を選ぶ。
3. `Product > Archive` を実行する。
4. Organizerで `Distribute App` を押す。
5. `App Store Connect` を選ぶ。
6. `Upload` を選ぶ。
7. 暗号化の質問は、非免除暗号を使っていないため `No` を選ぶ。
8. App Store Connectで処理が終わったら、TestFlightへ内部テスターを追加する。
9. TestFlight版をiPhoneに入れ、`REAL_DEVICE_QA.md` を埋める。

## 実機で見る石

- 緑系: 翡翠、プレナイト、ペリドット、アベンチュリンなど
- 青緑系: ターコイズ、アパタイト、アマゾナイトなど
- サイズ基準: 10円玉
- 背景: 白い紙
- 光: 明るい室内と自然光に近い場所

## 完成判定

GitHub Actionsが成功し、実機でライブカメラ、撮影、写真選択、10円玉基準サイズ、暗所アドバイス、検索、相場一覧が通れば完成扱いにできます。写真判定は鑑定ではなく候補表示です。高額品や処理の確認は鑑別機関で行う案内を残します。
