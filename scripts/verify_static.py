from pathlib import Path
import json
import plistlib
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "GemstoneDictionary"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def check(name: str, passed: bool, details: str = "") -> bool:
    status = "OK" if passed else "FAIL"
    suffix = f" - {details}" if details else ""
    print(f"{status}: {name}{suffix}")
    return passed


def balanced_pbx(text: str) -> bool:
    stack = []
    in_string = False
    escaped = False
    pairs = {"(": ")", "{": "}", "[": "]"}
    closing = set(pairs.values())
    for char in text:
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char in pairs:
            stack.append(char)
        elif char in closing:
            if not stack or pairs[stack.pop()] != char:
                return False
    return not stack and not in_string


def extract_gemstone_blocks(models: str) -> list[str]:
    blocks = []
    marker = "Gemstone("
    index = 0
    while True:
        start = models.find(marker, index)
        if start == -1:
            break
        if start > 0 and models[start - 1].isalpha():
            index = start + len(marker)
            continue
        depth = 0
        in_string = False
        escaped = False
        end = None
        for pos in range(start, len(models)):
            char = models[pos]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue
            if char == '"':
                in_string = True
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end = pos + 1
                    break
        if end is None:
            break
        blocks.append(models[start:end])
        index = end
    return blocks


def string_field(block: str, field: str) -> str:
    match = re.search(rf'{field}:\s*"((?:[^"\\]|\\.)*)"', block)
    return match.group(1) if match else ""


def array_field(block: str, field: str) -> list[str]:
    match = re.search(rf"{field}:\s*\[(.*?)\]", block, re.S)
    if not match:
        return []
    return re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1))


def normalize_query(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).replace(" ", "").lower()
    chars = []
    for char in normalized:
        code = ord(char)
        if 0x30A1 <= code <= 0x30F6:
            chars.append(chr(code - 0x60))
        else:
            chars.append(char)
    return "".join(chars)


def search_matches(blocks: list[str], query: str) -> list[str]:
    needle = normalize_query(query)
    matches = []
    for block in blocks:
        name = string_field(block, "name")
        kana = string_field(block, "kana")
        english = string_field(block, "englishName")
        aliases = array_field(block, "aliases")
        target = " ".join(normalize_query(value) for value in [name, kana, english, *aliases])
        if needle in target or normalize_query(kana).startswith(needle):
            matches.append(name)
    return matches


def main() -> int:
    models = read(APP / "Models.swift")
    content = read(APP / "ContentView.swift")
    classifier = read(APP / "ImageClassifier.swift")
    live = read(APP / "LiveCameraScanner.swift")
    picker = read(APP / "ImagePicker.swift")
    project = read(ROOT / "project.yml")
    ui_tests_path = ROOT / "GemstoneDictionaryUITests" / "GemstoneDictionaryUITests.swift"
    ui_tests = read(ui_tests_path) if ui_tests_path.exists() else ""
    readme = read(ROOT / "README.md")
    qa_checklist = ROOT / "QA_CHECKLIST.md"
    completion_audit = ROOT / "COMPLETION_AUDIT.md"
    real_device_qa_path = ROOT / "REAL_DEVICE_QA.md"
    device_build_path = ROOT / "DEVICE_BUILD_AND_TESTFLIGHT.md"
    market_notes_path = ROOT / "MARKET_DATA_NOTES.md"
    market_notes = read(market_notes_path) if market_notes_path.exists() else ""
    real_device_qa = read(real_device_qa_path) if real_device_qa_path.exists() else ""
    device_build = read(device_build_path) if device_build_path.exists() else ""
    build_script = ROOT / "scripts" / "build_mac.sh"
    workflow = ROOT.parents[1] / ".github" / "workflows" / "gemstone-dictionary-ios-build.yml"
    xcodeproj = ROOT / "GemstoneDictionary.xcodeproj" / "project.pbxproj"
    scheme = ROOT / "GemstoneDictionary.xcodeproj" / "xcshareddata" / "xcschemes" / "GemstoneDictionary.xcscheme"
    info_plist = APP / "Resources" / "Info.plist"

    results = []
    all_blocks = extract_gemstone_blocks(models)
    blocks = [block for block in all_blocks if string_field(block, "id")]
    supplemental_count = len(re.findall(r"^\s*supplementalStone\(", models, re.M))
    gemstone_count = len(blocks) + supplemental_count
    required_string_fields = [
        "id",
        "name",
        "kana",
        "englishName",
        "group",
        "hardness",
        "specificGravity",
        "refractiveIndex",
        "transparency",
        "rankRange",
        "marketPrice",
        "care",
        "note",
    ]
    required_array_fields = ["aliases", "colors", "priceFactors", "identificationTips", "treatments"]
    valid_groups = set("あかさたなはまやらわ")

    results.append(check("150種類以上の天然石データ", gemstone_count >= 150, f"{gemstone_count} entries"))
    results.append(check("Gemstoneブロック解析", len(blocks) + 1 == len(all_blocks), f"{len(blocks)} literal blocks, {supplemental_count} supplemental"))
    missing_detail = []
    invalid_groups = []
    for block in blocks:
        name = string_field(block, "name") or "(name missing)"
        for field in required_string_fields:
            if not string_field(block, field):
                missing_detail.append(f"{name}.{field}")
        for field in required_array_fields:
            if not array_field(block, field):
                missing_detail.append(f"{name}.{field}")
        if string_field(block, "group") not in valid_groups:
            invalid_groups.append(f"{name}.{string_field(block, 'group')}")
    results.append(check("各石の詳細フィールド", not missing_detail, ", ".join(missing_detail[:8])))
    results.append(check("各石の五十音グループ", not invalid_groups, ", ".join(invalid_groups[:8])))
    ta_matches = search_matches(blocks, "た")
    results.append(check("検索「た」でターコイズ", "ターコイズ" in ta_matches, ", ".join(ta_matches[:8])))
    results.append(check("検索「ヒスイ」で翡翠", "翡翠" in search_matches(blocks, "ヒスイ")))
    results.append(check("検索「ﾀｰｺｲｽﾞ」でターコイズ", "ターコイズ" in search_matches(blocks, "ﾀｰｺｲｽﾞ")))
    results.append(check("検索「jade」で翡翠", "翡翠" in search_matches(blocks, "jade")))
    jade_block = next((block for block in blocks if string_field(block, "name") == "翡翠"), "")
    results.append(check("翡翠の処理注意", "A貨" in jade_block and "含浸" in jade_block and "鑑別" in jade_block))
    results.append(check("翡翠データ", "翡翠" in models and "Jadeite Jade" in models))
    results.append(check("ターコイズデータ", "ターコイズ" in models and "Turquoise" in models))
    results.append(check("市場価格データ", "marketPrice" in models and "市場価格" in content))
    results.append(check("相場レビュー日", "marketReviewedAt" in models and "2026年6月目安" in models and "GemstoneDatabase.marketReviewedAt" in content))
    results.append(check("相場注意文", "marketDisclaimer" in models and "GemstoneDatabase.marketDisclaimer" in content))
    results.append(check("相場一覧表示", "marketPriceListSection" in content and "marketPriceRows" in content and "GemstoneDatabase.stones.count" in content and "種類の相場一覧" in content and "stone.marketPrice" in content and "selectedTab = 0" in content))
    results.append(check("相場更新条件表示", "相場更新で見る条件" in content and "A貨/B貨/C貨" in content and "無処理/安定化/染色/再生品" in content))
    results.append(check("相場購入前チェック", "marketBuyingChecklistSection" in content and "marketBuyingChecklistItems" in content and "買う前に見る項目" in content and "処理" in content and "証明" in content and "品質" in content and "価格" in content and "返品条件" in content))
    results.append(check("鑑別・相場用語集", "GlossaryTerm" in content and "glossarySection" in content and "glossaryTerms" in content and "鑑別・相場の用語集" in content and "A貨翡翠" in content and "B貨/C貨" in content and "含浸" in content and "再生品" in content and "カラット" in content))
    results.append(check("透明度データ", "transparency" in models and "透明度" in content))
    results.append(check("ランク/レベル表示", "rankRange" in models and "レベル" in content))
    results.append(check("ランク目安詳細", "rankGuideSection" in content and "rankGuideItems" in content and "写真のレベル表示は鑑定ランクではありません" in content and "rankColor" in content))
    results.append(check("数値の見方", "physicalReadingSection" in content and "physicalReadingItems" in content and "数値の見方" in content and "傷つきにくさ" in content and "屈折率" in content))
    results.append(check("処理注意ハイライト", "treatmentAlertSection" in content and "treatmentAlertItems" in content and "処理・注意ハイライト" in content and "価格差に注意" in content and "stone.care" in content))
    results.append(check("写真判定ロジック説明", "色相" in content and "彩度" in content and "明るさ" in content and "画面内" in content))
    results.append(check("候補カード詳細表示", "MiniInfoLabel" in content and "shortTransparency" in content and "candidate.gemstone.marketPrice" in content))
    results.append(check("判定確度表示", "candidateConfidenceSection" in content and "confidenceTitle" in content and "confidenceMessage" in content and "判定確度" in content and "高め" in content and "中くらい" in content and "低め" in content))
    results.append(check("サンプル判定", "DemoStoneSample" in content and "demoSampleSection" in content and "runDemoSample" in content and "makeDemoSampleImage" in content and "翡翠サンプル" in content and "ターコイズサンプル" in content))
    results.append(check("候補の手動履歴保存", "saveCandidateToHistory" in content and "履歴保存" in content and "clock.badge.checkmark" in content and "recordScanHistory(candidate: candidate" in content))
    results.append(check("判定履歴", "ScanHistoryEntry" in content and "scanHistorySection" in content and "recordScanHistory" in content and "最近の判定" in content and "clock.arrow.circlepath" in content))
    results.append(check("判定履歴の基準物保存", "referenceLabel" in content and "reference.rawValue" in content and "基準物: \\(entry.referenceLabel)" in content))
    results.append(check("判定履歴のサイズ信頼度保存", "sizeConfidenceLabel" in content and "sizeConfidenceLabel: String?" in content and "信頼度" in content and "未記録" in content))
    results.append(check("判定履歴保存", "StoredScanHistoryEntry" in content and "UserDefaults.standard" in content and "loadScanHistory()" in content and "saveScanHistory()" in content and "JSONEncoder" in content and "JSONDecoder" in content and "referenceLabel: String?" in content))
    results.append(check("判定結果共有", "ShareLink" in content and "shareText(for candidate" in content and "shareText(for entry" in content and "天然石判定メモ" in content and "square.and.arrow.up" in content and "基準物: \\(referenceLabel)" in content and "基準物: \\(entry.referenceLabel)" in content and "サイズ信頼度" in content))
    results.append(check("辞典詳細共有", "detailShareText" in content and "詳細メモを共有" in content and "天然石詳細メモ" in content and "処理確認" in content and "鑑別書" in content))
    results.append(check("ライブ詳細表示", "first.gemstone.shortTransparency" in content and "first.gemstone.marketPrice" in content and "metrics.sizeLabel" in content))
    results.append(check("ライブ安定表示", "liveStableCandidateID" in content and "liveStableCount" in content and "updateLiveStability" in content and "liveStabilityLabel" in content))
    results.append(check("撮影品質アドバイス", "captureQualityWarnings" in models and "captureQualityAdvice" in content and "撮影アドバイス" in content and "brightness < 24" in models and "coverageScore < 24" in models))
    results.append(check("フレーミングガイド", "framingGuideOverlay" in content and "基準物" in content and "reference.millimeters" in content and "allowsHitTesting(false)" in content))
    results.append(check("判定根拠表示", "classificationInsight" in content and "classificationEvidence" in content and "判定の根拠" in content and "鑑別書" in content))
    results.append(check("似ている石比較", "similarStoneSection" in content and "similarStones" in content and "similarityNote" in content and "hueCenter" in models and "saturationCenter" in models))
    results.append(check("迷いやすい石比較", "confusingStoneSection" in content and "confusingStones" in content and "confusingStoneIDs" in content and "confusingCue" in content and "迷いやすい石" in content and "jadeite" in content and "nephrite" in content and "turquoise" in content and "amazonite" in content))
    results.append(check("購入前チェック", "purchaseChecklistSection" in content and "purchaseChecklistItems" in content and "返品条件" in content and "stone.treatments.prefix" in content))
    results.append(check("鑑別・ランク確認メモ", "appraisalMemoSection" in content and "appraisalMemoItems" in content and "doc.text.magnifyingglass" in content and "硬度" in content and "屈折率" in content and "処理は価格とランク表示に直結" in content))
    results.append(check("サイズ目安", "estimatedMillimeters" in models and "サイズ" in content))
    results.append(check("サイズ信頼度", "sizeConfidenceLabel" in models and "sizeConfidenceNote" in models and "サイズ信頼度" in content and "撮り直し" in models))
    results.append(check("サイズ計測ガイド", "サイズ目安を出すコツ" in content and "10円玉" in content and "見かけサイズ" in content))
    results.append(check("五十音リスト", "kanaGroups" in models and "すべて" in models))
    results.append(check("五十音セクション表示", "groupedFilteredStones" in content and "Section(section.group)" in content))
    results.append(check("色フィルター", "activeColor" in content and "colorFilters" in content and "dictionaryColorSwatch" in content and "$0.colors.contains(activeColor)" in content))
    results.append(check("ランクフィルター", "activeRank" in content and "rankFilters" in content and "$0.rankRange.contains(activeRank)" in content and "全ランク" in content and "S候補" in content))
    results.append(check("辞典該当なし表示", "dictionaryEmptyState" in content and "resetDictionaryFilters" in content and "該当する石がありません" in content and "条件をリセット" in content and "hasDictionaryFilters" in content))
    results.append(check("お気に入り保存", "favoriteStoneIDs" in content and "favoritesOnly" in content and "toggleFavorite" in content and "loadFavoriteStones()" in content and "saveFavoriteStones()" in content and "gemstone.favoriteStoneIDs.v1" in content))
    results.append(check("検索欄", ".searchable" in content and "た、ターコイズ" in content))
    results.append(check("かな検索正規化", "UnicodeScalarView" in content and "0x30A1" in content and "0x30F6" in content))
    results.append(check("ライブカメラ", "AVCaptureSession" in live and "AVCaptureVideoDataOutput" in live))
    results.append(check("ライブカメラCombine import", "import Combine" in live))
    results.append(check("ライブ停止UI同期", "toggleLiveScanning()" in content and "stopLiveScanning()" in content))
    results.append(check("ライブ許可失敗UI復帰", "liveScanner.authorizationMessage" in content and "liveScanner.isRunning" in content and "liveMode = false" in content))
    results.append(check("撮影カメラ", "UIImagePickerController" in picker and "CameraPicker" in content))
    results.append(check("写真選択", "PhotosPicker" in content))
    results.append(check("カメラ権限説明", "NSCameraUsageDescription" in project))
    results.append(check("写真権限説明", "NSPhotoLibraryUsageDescription" in project))
    results.append(check("UIテストターゲット設定", "GemstoneDictionaryUITests" in project and "bundle.ui-testing" in project))
    results.append(check("UIテスト要件", ui_tests_path.exists() and "testDictionarySearchTaFindsTurquoise" in ui_tests and "testDictionarySearchJadeFindsJadeite" in ui_tests and "testMarketListAndDemoSampleAreReachable" in ui_tests and "UITEST_DICTIONARY_QUERY" in content and "UITEST_DICTIONARY_QUERY_TA" in content and "UITEST_DICTIONARY_QUERY_TA" in ui_tests))
    results.append(check("UIテストサイズ信頼度", ui_tests_path.exists() and "サイズ信頼度" in ui_tests and "見かけサイズ" in ui_tests and "demoSample-jadeite" in ui_tests))
    results.append(check("UIテスト文字化け置換文字なし", ui_tests_path.exists() and "\ufffd" not in ui_tests))
    results.append(check("Xcodeプロジェクト同梱", xcodeproj.exists()))
    results.append(check("共有スキーム同梱", scheme.exists()))
    if xcodeproj.exists():
        pbx = read(xcodeproj)
        results.append(check("XcodeプロジェクトのSwift参照", all(name in pbx for name in [
            "GemstoneDictionaryApp.swift",
            "ContentView.swift",
            "Models.swift",
            "ImageClassifier.swift",
            "ImagePicker.swift",
            "LiveCameraScanner.swift",
        ])))
        results.append(check("Xcodeプロジェクトのリソース参照", "Assets.xcassets" in pbx and "PrivacyInfo.xcprivacy" in pbx))
        results.append(check("XcodeプロジェクトのInfo.plist参照", "GemstoneDictionary/Resources/Info.plist" in pbx))
        results.append(check("XcodeプロジェクトのUIテスト参照", "GemstoneDictionaryUITests" in pbx and "GemstoneDictionaryUITests.swift" in pbx and "com.apple.product-type.bundle.ui-testing" in pbx))
        results.append(check("Xcodeプロジェクト構文の括弧", balanced_pbx(pbx)))
    if scheme.exists():
        ET.parse(scheme)
        results.append(check("共有スキームXML", True))
    results.append(check("README更新", "ライブカメラ判定" in readme and "150種類以上" in readme))
    results.append(check("README判定根拠", "判定の根拠" in readme and "色相" in readme and "市場価格" in readme))
    results.append(check("README判定確度", "判定確度" in readme and "中くらい" in readme and "撮り直し" in readme))
    results.append(check("READMEサンプル判定", "サンプルで試す" in readme and "翡翠とターコイズ" in readme and "実機カメラがない環境" in readme))
    results.append(check("README候補保存", "任意の候補" in readme and "履歴保存" in readme))
    results.append(check("README判定履歴", "最近の判定" in readme and "履歴" in readme))
    results.append(check("README履歴保存", "端末内" in readme and "履歴" in readme))
    results.append(check("README判定共有", "共有" in readme and "判定結果" in readme))
    results.append(check("README詳細共有", "詳細メモを共有" in readme and "硬度" in readme and "屈折率" in readme))
    results.append(check("README数値の見方", "数値の見方" in readme and "傷つきにくさ" in readme and "屈折率" in readme))
    results.append(check("README処理注意", "処理・注意ハイライト" in readme and "価格差" in readme and "鑑別書" in readme))
    results.append(check("README色フィルター", "色から探す" in readme and "辞典" in readme))
    results.append(check("READMEランクフィルター", "ランク目安から探す" in readme and "辞典" in readme))
    results.append(check("README該当なし", "該当なし" in readme and "条件リセット" in readme))
    results.append(check("READMEお気に入り", "お気に入り" in readme and "端末内" in readme))
    results.append(check("READMEライブ安定表示", "安定表示" in readme and "ライブカメラ" in readme))
    results.append(check("README撮影品質", "撮影アドバイス" in readme and "暗い" in readme))
    results.append(check("READMEフレーミングガイド", "フレーミングガイド" in readme and "基準物" in readme))
    results.append(check("READMEサイズ信頼度", "サイズ推定の信頼度" in readme and "撮り直し" in readme))
    results.append(check("README似ている石", "似ている石" in readme and "色相" in readme))
    results.append(check("README迷いやすい石", "迷いやすい石" in readme and "ネフライト" in readme and "アマゾナイト" in readme))
    results.append(check("README購入前チェック", "購入前チェック" in readme and "返品条件" in readme))
    results.append(check("README鑑別メモ", "鑑別・ランク確認メモ" in readme and "硬度" in readme and "屈折率" in readme))
    results.append(check("READMEランク目安", "ランク目安" in readme and "鑑定ランク" in readme))
    results.append(check("README相場データ", "MARKET_DATA_NOTES.md" in readme and "International Gem Society" in readme))
    results.append(check("README実機QA", "REAL_DEVICE_QA.md" in readme and "iPhone実機" in readme and "10円玉基準" in readme))
    results.append(check("README実機ビルド手順", "DEVICE_BUILD_AND_TESTFLIGHT.md" in readme and "GemstoneDictionary-simulator-app" in readme))
    results.append(check("README相場一覧", "150種類以上の相場一覧" in readme and "市場価格" in readme))
    results.append(check("README相場購入前", "買う前に見る項目" in readme and "無処理/安定化/染色/再生品" in readme))
    results.append(check("README用語集", "鑑別・相場の用語集" in readme and "A貨翡翠" in readme and "カラット" in readme))
    results.append(check("相場更新メモ", market_notes_path.exists() and "GIA Jadeite Jade Quality Factors" in market_notes and "International Gem Society Gem Price Guide" in market_notes and "固定価格" in market_notes))
    results.append(check("Macビルドスクリプト", build_script.exists() and "xcodebuild" in read(build_script)))
    qa = read(qa_checklist) if qa_checklist.exists() else ""
    results.append(check("実機QAチェックリスト", qa_checklist.exists() and "ライブ中に候補名" in qa))
    results.append(check("QA判定根拠", "判定の根拠" in qa and "鑑別書" in qa))
    results.append(check("QA判定確度", "判定確度" in qa and "高め" in qa and "低め" in qa))
    results.append(check("QAサンプル判定", "サンプルで試す" in qa and "翡翠サンプル" in qa and "ターコイズサンプル" in qa))
    results.append(check("QA候補保存", "候補カード" in qa and "履歴保存" in qa and "2番目以降" in qa))
    results.append(check("QA判定履歴", "最近の判定" in qa and "履歴" in qa))
    results.append(check("QA履歴保存", "再起動" in qa and "履歴" in qa))
    results.append(check("QA判定共有", "共有" in qa and "天然石判定メモ" in qa))
    results.append(check("QA詳細共有", "詳細メモを共有" in qa and "天然石詳細メモ" in qa and "鑑別書注意" in qa))
    results.append(check("QA数値の見方", "数値の見方" in qa and "傷つきにくさ" in qa and "屈折率" in qa))
    results.append(check("QA処理注意", "処理・注意ハイライト" in qa and "価格差" in qa and "扱い方" in qa))
    results.append(check("QA色フィルター", "色フィルター" in qa and "青" in qa))
    results.append(check("QAランクフィルター", "ランクフィルター" in qa and "S候補" in qa and "C候補" in qa))
    results.append(check("QA該当なし", "該当する石がありません" in qa and "条件をリセット" in qa))
    results.append(check("QAお気に入り", "お気に入り" in qa and "再起動" in qa))
    results.append(check("QAライブ安定表示", "安定表示" in qa and "確認中" in qa))
    results.append(check("QA撮影品質", "撮影アドバイス" in qa and "石が小さく" in qa))
    results.append(check("QAフレーミングガイド", "フレーミングガイド" in qa and "基準物" in qa))
    results.append(check("QAサイズ信頼度", "サイズ信頼度" in qa and "高め/中くらい/低め" in qa))
    results.append(check("QA似ている石", "似ている石" in qa and "硬度" in qa and "比重" in qa))
    results.append(check("QA迷いやすい石", "迷いやすい石" in qa and "ネフライト" in qa and "アマゾナイト" in qa))
    results.append(check("QA購入前チェック", "購入前チェック" in qa and "返品条件" in qa))
    results.append(check("QA鑑別メモ", "鑑別・ランク確認メモ" in qa and "硬度" in qa and "屈折率" in qa))
    results.append(check("QAランク目安", "ランク目安" in qa and "鑑定ランク" in qa))
    results.append(check("QA相場更新", "相場更新" in qa and "MARKET_DATA_NOTES.md" in qa))
    results.append(check("QA相場一覧", "150種類以上の相場一覧" in qa and "市場価格" in qa and "詳細へ移動" in qa))
    results.append(check("QA相場購入前", "買う前に見る項目" in qa and "処理、証明、品質、価格" in qa and "無処理/安定化/染色/再生品" in qa))
    results.append(check("QA用語集", "鑑別・相場の用語集" in qa and "A貨翡翠" in qa and "屈折率" in qa and "鑑別書" in qa))
    results.append(check("実機QAシート", real_device_qa_path.exists() and "実機QAシート" in real_device_qa and "合格条件" in real_device_qa and "10円玉" in real_device_qa and "完成判断" in real_device_qa))
    results.append(check("実機ビルド手順", device_build_path.exists() and "実機ビルドとTestFlight手順" in device_build and "GemstoneDictionary-simulator-app" in device_build and "Product > Archive" in device_build and "REAL_DEVICE_QA.md" in device_build))
    if completion_audit.exists():
        audit = read(completion_audit)
        results.append(check("完成監査ドキュメント", "現在満たしている項目" in audit and "未検証" in audit))
        results.append(check("完成監査の残確認", "GitHub Actions" in audit and "iPhone実機" in audit and "build_mac.sh" in audit and "DEVICE_BUILD_AND_TESTFLIGHT.md" in audit))
    else:
        results.append(check("完成監査ドキュメント", False))
    if workflow.exists():
        workflow_text = read(workflow)
        results.append(check("GitHub ActionsビルドCI", "xcodebuild" in workflow_text and "GemstoneDictionary.xcodeproj" in workflow_text))
        results.append(check("GitHub Actions静的検証", "scripts/verify_static.py" in workflow_text))
        results.append(check("GitHub Actions UIテスト", "xcodebuild" in workflow_text and " test" in workflow_text and "simctl list devices available" in workflow_text))
        results.append(check("GitHub Actions artifact", "actions/upload-artifact@v7" in workflow_text and "GemstoneDictionary-simulator-app" in workflow_text and "GemstoneDictionary.app" in workflow_text))
    else:
        results.append(check("GitHub ActionsビルドCI", False))

    for swift_file in APP.glob("*.swift"):
        text = read(swift_file)
        odd_quote_lines = []
        for line_no, line in enumerate(text.splitlines(), 1):
            quote_count = line.count('"') - line.count('\\"')
            if quote_count % 2:
                odd_quote_lines.append(line_no)
        results.append(check(f"{swift_file.name} の文字列", not odd_quote_lines, str(odd_quote_lines)))
        results.append(check(f"{swift_file.name} の文字化け置換文字なし", "\ufffd" not in text))

    for json_path in [
        APP / "Assets.xcassets" / "Contents.json",
        APP / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json",
    ]:
        with json_path.open("r", encoding="utf-8") as handle:
            json.load(handle)
        results.append(check(f"{json_path.name} JSON", True))

    for plist_path in [
        info_plist,
        APP / "PrivacyInfo.xcprivacy",
    ]:
        with plist_path.open("rb") as handle:
            plist = plistlib.load(handle)
        results.append(check(f"{plist_path.name} plist", True))
        if plist_path == info_plist:
            results.append(check("Info.plist 表示名", plist.get("CFBundleDisplayName") == "天然石辞典"))
            results.append(check("Info.plist Bundle ID", plist.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)"))
            results.append(check("Info.plist Executable", plist.get("CFBundleExecutable") == "$(EXECUTABLE_NAME)"))
            results.append(check("Info.plist Package", plist.get("CFBundlePackageType") == "APPL"))
            results.append(check("Info.plist カメラ権限", "天然石" in plist.get("NSCameraUsageDescription", "")))
            results.append(check("Info.plist 写真権限", "写真" in plist.get("NSPhotoLibraryUsageDescription", "")))

    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
