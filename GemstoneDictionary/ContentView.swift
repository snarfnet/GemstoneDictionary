import Foundation
import PhotosUI
import SwiftUI
import UIKit

private struct ScanHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let gemstone: Gemstone
    let score: Int
    let levelLabel: String
    let sizeLabel: String
    let sizeConfidenceLabel: String
    let referenceLabel: String
}

private struct StoredScanHistoryEntry: Codable {
    let date: Date
    let gemstoneID: String
    let score: Int
    let levelLabel: String
    let sizeLabel: String
    let sizeConfidenceLabel: String?
    let referenceLabel: String?
}

private struct GlossaryTerm: Identifiable {
    var id: String { title }
    let title: String
    let category: String
    let detail: String
}

private struct DemoStoneSample: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let primary: UIColor
    let matrix: UIColor
}

struct ContentView: View {
    @StateObject private var liveScanner = LiveCameraScannerViewModel()
    @State private var selectedStone = GemstoneDatabase.stones[0]
    @State private var query = Self.initialDictionaryQuery()
    @State private var activeGroup = "すべて"
    @State private var activeColor = "すべて"
    @State private var activeRank = "すべて"
    @State private var reference: SizeReference = .none
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var scanMetrics: ScanMetrics?
    @State private var candidates: [StoneCandidate] = []
    @State private var showingCamera = false
    @State private var liveMode = false
    @State private var selectedTab = 0
    @State private var liveStableCandidateID: String?
    @State private var liveStableCount = 0
    @State private var scanHistory: [ScanHistoryEntry] = []
    @State private var favoriteStoneIDs: Set<String> = []
    @State private var favoritesOnly = false
    private let scanHistoryStorageKey = "gemstone.scanHistory.v1"
    private let favoriteStonesStorageKey = "gemstone.favoriteStoneIDs.v1"
    private let demoSamples = [
        DemoStoneSample(
            id: "jadeite",
            name: "翡翠サンプル",
            subtitle: "緑色・半透明",
            primary: UIColor(red: 0.18, green: 0.62, blue: 0.38, alpha: 1),
            matrix: UIColor(red: 0.74, green: 0.86, blue: 0.70, alpha: 1)
        ),
        DemoStoneSample(
            id: "turquoise",
            name: "ターコイズサンプル",
            subtitle: "青緑色・不透明",
            primary: UIColor(red: 0.06, green: 0.70, blue: 0.78, alpha: 1),
            matrix: UIColor(red: 0.22, green: 0.18, blue: 0.13, alpha: 1)
        )
    ]

    private static func initialDictionaryQuery() -> String {
        let environment = ProcessInfo.processInfo.environment
        if environment["UITEST_DICTIONARY_QUERY_TA"] == "1" {
            return "た"
        }
        return environment["UITEST_DICTIONARY_QUERY"] ?? ""
    }

    var filteredStones: [Gemstone] {
        let text = normalized(query)
        return GemstoneDatabase.stones
            .filter { activeGroup == "すべて" || $0.group == activeGroup }
            .filter { activeColor == "すべて" || $0.colors.contains(activeColor) }
            .filter { activeRank == "すべて" || $0.rankRange.contains(activeRank) }
            .filter { !favoritesOnly || favoriteStoneIDs.contains($0.id) }
            .filter { stone in
                guard !text.isEmpty else { return true }
                let target = ([stone.name, stone.kana, stone.englishName] + stone.aliases)
                    .map(normalized)
                    .joined(separator: " ")
                return target.contains(text) || normalized(stone.kana).hasPrefix(text)
            }
            .sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    var groupedFilteredStones: [(group: String, stones: [Gemstone])] {
        let groups = activeGroup == "すべて" ? GemstoneDatabase.kanaGroups.filter { $0 != "すべて" } : [activeGroup]
        return groups.compactMap { group in
            let stones = filteredStones.filter { $0.group == group }
            return stones.isEmpty ? nil : (group, stones)
        }
    }

    var colorFilters: [String] {
        let colors = Set(GemstoneDatabase.stones.flatMap(\.colors))
        return ["すべて"] + colors.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var rankFilters: [String] {
        ["すべて", "S", "A", "B", "C"]
    }

    var hasDictionaryFilters: Bool {
        !query.isEmpty || activeGroup != "すべて" || activeColor != "すべて" || activeRank != "すべて" || favoritesOnly
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        scanCard
                        if !candidates.isEmpty {
                            candidateSection
                        }
                        if !scanHistory.isEmpty {
                            scanHistorySection
                        }
                        selectedStoneDetail
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 26)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .background(AppStyle.background.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("判定", systemImage: "camera.viewfinder")
            }
            .tag(0)
            .accessibilityIdentifier("scanTab")

            NavigationStack {
                dictionaryView
                    .navigationTitle("天然石辞典")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("辞典", systemImage: "text.book.closed")
            }
            .tag(1)
            .accessibilityIdentifier("dictionaryTab")

            NavigationStack {
                marketGuide
                    .navigationTitle("相場メモ")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("相場", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(2)
            .accessibilityIdentifier("marketTab")

            NavigationStack {
                BirthstoneView()
            }
            .tabItem {
                Label("誕生石", systemImage: "moon.stars.fill")
            }
            .tag(3)

            NavigationStack {
                CompatibilityView()
            }
            .tabItem {
                Label("相性", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(4)

            NavigationStack {
                CollectionView()
            }
            .tabItem {
                Label("コレクション", systemImage: "tray.full.fill")
            }
            .tag(5)

            NavigationStack {
                PowerStoneView()
            }
            .tabItem {
                Label("効果", systemImage: "sparkles")
            }
            .tag(6)
        }
        .tint(AppStyle.jade)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                capturedImage = image
                classify(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            stopLiveScanning()
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        capturedImage = image
                        classify(image)
                    }
                }
            }
        }
        .onChange(of: liveScanner.isRunning) { _, isRunning in
            if !isRunning {
                liveMode = false
            }
        }
        .onChange(of: liveScanner.authorizationMessage) { _, message in
            if message != nil {
                liveMode = false
            }
        }
        .onAppear {
            loadScanHistory()
            loadFavoriteStones()
            liveScanner.onFrame = { image in
                capturedImage = image
                classify(image)
            }
        }
        .onDisappear {
            stopLiveScanning()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("STONE FIELD GUIDE")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.turquoise)
                    Text("天然石辞典")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundStyle(AppStyle.ink)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(GemstoneDatabase.stones.count)種")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.82), in: Capsule())
                    .overlay(Capsule().stroke(AppStyle.line))
            }

            Text("写真から候補を出し、名前からも調べられます。翡翠、ターコイズ、ルビー、サファイアなどの特徴、透明度、処理、価格目安を収録しました。")
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(AppStyle.muted)
        }
        .padding(18)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera Scan")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.turquoise)
                    Text("石を撮って調べる")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                Picker("基準物", selection: $reference) {
                    ForEach(SizeReference.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: reference) { _, _ in
                    if let capturedImage {
                        classify(capturedImage)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.12), Color(red: 0.22, green: 0.26, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                if liveScanner.isRunning {
                    LiveCameraPreview(session: liveScanner.session)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    framingGuideOverlay
                    liveOverlay
                } else if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()
                    framingGuideOverlay
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 44, weight: .semibold))
                        Text("カメラか写真を選択")
                            .font(.headline)
                        Text("色、明るさ、写っている範囲から候補を出します。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button {
                    toggleLiveScanning()
                } label: {
                    Label(liveMode ? "停止" : "ライブ", systemImage: liveMode ? "pause.circle" : "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("liveScanButton")

                Button {
                    stopLiveScanning()
                    showingCamera = true
                } label: {
                    Label("撮影", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("cameraCaptureButton")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("写真", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("photoPickerButton")
            }

            demoSampleSection

            if let message = liveScanner.authorizationMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppStyle.garnet)
            }

            sizeGuide

            if let scanMetrics {
                metricsPanel(scanMetrics)
                captureQualityAdvice(scanMetrics)
                classificationInsight(scanMetrics)
            } else {
                Text("実寸を出したいときは、10円玉などを同じ高さで一緒に写してください。基準なしの場合は画像内の見かけサイズだけを表示します。")
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var demoSampleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("サンプルで試す", systemImage: "testtube.2")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            Text("実機カメラがない環境でも、判定結果の表示を確認できます。")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)

            HStack(spacing: 8) {
                ForEach(demoSamples) { sample in
                    Button {
                        runDemoSample(sample)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sample.name)
                                .font(.caption.weight(.black))
                            Text(sample.subtitle)
                                .font(.caption2)
                                .foregroundStyle(AppStyle.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(DemoSampleButtonStyle(color: Color(sample.primary)))
                    .accessibilityIdentifier("demoSample-\(sample.id)")
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var sizeGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("サイズ目安を出すコツ", systemImage: "ruler")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            VStack(alignment: .leading, spacing: 5) {
                Text("10円玉などを石の横に置き、同じ高さで写してください。")
                Text("基準物なしの場合は、実寸ではなく見かけサイズを表示します。")
                Text("斜め撮影、影、背景の色でサイズと候補はぶれます。")
            }
            .font(.footnote)
            .foregroundStyle(AppStyle.muted)
            .lineSpacing(2)
        }
        .padding(12)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var framingGuideOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
                    .padding(18)
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(.white.opacity(0.54))
                    .frame(width: min(width, height) * 0.36, height: min(width, height) * 0.36)
                    .position(x: width * 0.5, y: height * 0.46)
                Text("石")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.42), in: Capsule())
                    .position(x: width * 0.5, y: height * 0.26)
                if reference.millimeters != nil {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundStyle(AppStyle.gold.opacity(0.74))
                        .frame(width: width * 0.22, height: height * 0.16)
                        .position(x: width * 0.78, y: height * 0.69)
                    Text("基準物")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppStyle.gold.opacity(0.76), in: Capsule())
                        .position(x: width * 0.78, y: height * 0.56)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var liveOverlay: some View {
        VStack {
            HStack {
                Label("ライブ判定中", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.56), in: Capsule())
                Spacer()
            }
            Spacer()
            if let first = candidates.first {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(first.gemstone.name)
                            .font(.title2.weight(.black))
                        Text("\(first.score)% / \(scanMetrics?.levelLabel ?? "-")ランク候補")
                            .font(.caption.weight(.bold))
                        Text("透明度 \(first.gemstone.shortTransparency)")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Text(liveStabilityLabel)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(liveStableCount >= 2 ? AppStyle.gold : .white.opacity(0.76))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let metrics = scanMetrics {
                            Text(metrics.sizeLabel)
                                .font(.caption.weight(.bold))
                        }
                        Text(first.gemstone.marketPrice)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }

    private var liveStabilityLabel: String {
        liveStableCount >= 2 ? "安定表示 \(liveStableCount)回" : "確認中"
    }

    private func metricsPanel(_ metrics: ScanMetrics) -> some View {
        VStack(spacing: 12) {
            MetricRow(title: "透明度", value: "\(metrics.clarityLabel) \(metrics.clarityScore)%", score: metrics.clarityScore, color: AppStyle.turquoise)
            MetricRow(title: "レベル", value: "\(metrics.levelLabel) / \(metrics.levelScore)%", score: metrics.levelScore, color: AppStyle.gold)
            MetricRow(
                title: "サイズ",
                value: metrics.sizeLabel,
                score: metrics.coverageScore,
                color: AppStyle.garnet
            )
            Text(metrics.sizeNote)
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Label("サイズ信頼度: \(metrics.sizeConfidenceLabel)", systemImage: "ruler.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(metrics.coverageScore >= 42 ? AppStyle.jade : (metrics.coverageScore >= 24 ? AppStyle.gold : AppStyle.garnet))
                Text(metrics.sizeConfidenceNote)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        }
    }

    private func captureQualityAdvice(_ metrics: ScanMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("撮影アドバイス", systemImage: "camera.metering.center.weighted")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            ForEach(metrics.captureQualityWarnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: warning.contains("良好") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(warning.contains("良好") ? AppStyle.jade : AppStyle.gold)
                        .padding(.top, 3)
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(2)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("候補")
                .font(.title2.weight(.bold))
            candidateConfidenceSection
            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        ScoreBadge(score: candidate.score)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(candidate.gemstone.name)
                                .font(.headline)
                                .foregroundStyle(AppStyle.ink)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    MiniInfoLabel(title: "ランク", value: candidate.gemstone.rankRange)
                                    MiniInfoLabel(title: "透明度", value: candidate.gemstone.shortTransparency)
                                }
                            }
                            Text(candidate.gemstone.marketPrice)
                                .font(.subheadline)
                                .foregroundStyle(AppStyle.muted)
                                .lineLimit(3)
                        }
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Button {
                            selectedStone = candidate.gemstone
                            selectedTab = 0
                        } label: {
                            Label("詳細", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button {
                            saveCandidateToHistory(candidate)
                        } label: {
                            Label("履歴保存", systemImage: "clock.badge.checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(scanMetrics == nil)

                        ShareLink(item: shareText(for: candidate, metrics: scanMetrics)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppStyle.turquoise)
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                        }
                        .accessibilityLabel("判定結果を共有")
                    }
                }
                .padding(12)
                .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            }
        }
    }

    private var candidateConfidenceSection: some View {
        guard let first = candidates.first else {
            return AnyView(EmptyView())
        }
        let secondScore = candidates.dropFirst().first?.score
        return AnyView(
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: confidenceIcon(for: first.score, secondScore: secondScore))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(confidenceColor(for: first.score, secondScore: secondScore))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("判定確度: \(confidenceTitle(for: first.score, secondScore: secondScore))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppStyle.ink)
                    Text(confidenceMessage(for: first.score, secondScore: secondScore))
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(2)
                }
            }
            .padding(12)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        )
    }

    private func confidenceTitle(for score: Int, secondScore: Int?) -> String {
        let gap = score - (secondScore ?? 0)
        if score >= 78, gap >= 10 { return "高め" }
        if score >= 62 { return "中くらい" }
        return "低め"
    }

    private func confidenceMessage(for score: Int, secondScore: Int?) -> String {
        let gap = score - (secondScore ?? 0)
        if score >= 78, gap >= 10 {
            return "最上位候補が比較的はっきり出ています。処理や産地は写真では断定できないため、高額品は鑑別書で確認してください。"
        }
        if score >= 62 {
            return "候補は出ていますが、似た色の石が近く出る可能性があります。候補を開き、硬度、比重、処理、価格条件を比べてください。"
        }
        return "写真条件や色の近い石の影響で、候補が不安定です。明るさ、背景、石の大きさを整えて撮り直してください。"
    }

    private func confidenceIcon(for score: Int, secondScore: Int?) -> String {
        confidenceTitle(for: score, secondScore: secondScore) == "低め" ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private func confidenceColor(for score: Int, secondScore: Int?) -> Color {
        switch confidenceTitle(for: score, secondScore: secondScore) {
        case "高め": return AppStyle.jade
        case "中くらい": return AppStyle.gold
        default: return AppStyle.garnet
        }
    }

    private var scanHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近の判定")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    scanHistory.removeAll()
                    saveScanHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppStyle.garnet)
                        .padding(8)
                        .background(.white.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(AppStyle.line))
                }
                .accessibilityLabel("判定履歴を消去")
            }

            ForEach(scanHistory.prefix(6)) { entry in
                Button {
                    selectedStone = entry.gemstone
                    selectedTab = 0
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(AppStyle.turquoise)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(entry.gemstone.name)
                                    .font(.headline)
                                    .foregroundStyle(AppStyle.ink)
                                Spacer()
                                Text(entry.date, style: .time)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppStyle.muted)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    MiniInfoLabel(title: "一致", value: "\(entry.score)%")
                                    MiniInfoLabel(title: "レベル", value: entry.levelLabel)
                                    MiniInfoLabel(title: "サイズ", value: entry.sizeLabel)
                                    MiniInfoLabel(title: "信頼度", value: entry.sizeConfidenceLabel)
                                }
                            }
                            Text("基準物: \(entry.referenceLabel)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppStyle.muted)
                            Text(entry.gemstone.marketPrice)
                                .font(.caption)
                                .foregroundStyle(AppStyle.muted)
                                .lineLimit(2)
                        }
                        ShareLink(item: shareText(for: entry)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppStyle.turquoise)
                                .padding(8)
                                .background(.white.opacity(0.78), in: Circle())
                                .overlay(Circle().stroke(AppStyle.line))
                        }
                        .accessibilityLabel("履歴の判定結果を共有")
                    }
                    .padding(12)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func classificationInsight(_ metrics: ScanMetrics) -> some View {
        if let first = candidates.first {
            VStack(alignment: .leading, spacing: 10) {
                Label("判定の根拠", systemImage: "waveform.path.ecg.rectangle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
                Text("最上位候補: \(first.gemstone.name) \(first.score)%")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppStyle.turquoise)
                ForEach(classificationEvidence(for: first, metrics: metrics), id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(AppStyle.jade)
                            .padding(.top, 7)
                        Text(item)
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        }
    }

    private var selectedStoneDetail: some View {
        StoneDetailView(
            stone: selectedStone,
            isFavorite: favoriteStoneIDs.contains(selectedStone.id),
            onToggleFavorite: { toggleFavorite(selectedStone) }
        ) { stone in
            selectedStone = stone
            selectedTab = 0
        }
    }

    private var dictionaryView: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GemstoneDatabase.kanaGroups, id: \.self) { group in
                        Button(group) {
                            activeGroup = group
                        }
                        .buttonStyle(ChipButtonStyle(isActive: activeGroup == group))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        favoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: favoritesOnly ? "star.fill" : "star")
                            Text("お気に入り")
                        }
                    }
                    .buttonStyle(ChipButtonStyle(isActive: favoritesOnly))

                    ForEach(colorFilters, id: \.self) { color in
                        Button {
                            activeColor = color
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(dictionaryColorSwatch(color))
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(AppStyle.line))
                                Text(color)
                            }
                        }
                        .buttonStyle(ChipButtonStyle(isActive: activeColor == color))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rankFilters, id: \.self) { rank in
                        Button {
                            activeRank = rank
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: rank == "すべて" ? "line.3.horizontal.decrease.circle" : "star.leadinghalf.filled")
                                Text(rankFilterTitle(for: rank))
                            }
                        }
                        .buttonStyle(ChipButtonStyle(isActive: activeRank == rank))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            List {
                if groupedFilteredStones.isEmpty {
                    dictionaryEmptyState
                } else {
                    ForEach(groupedFilteredStones, id: \.group) { section in
                        Section(section.group) {
                            ForEach(section.stones) { stone in
                                dictionaryRow(stone)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "た、ターコイズ、翡翠、jade")
            .accessibilityIdentifier("dictionarySearchList")
        }
        .background(AppStyle.background.ignoresSafeArea())
    }

    private var dictionaryEmptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("該当する石がありません", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                Text("検索語、五十音、色、ランク、お気に入りの条件を変えて探してください。")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                    .lineSpacing(3)
                if hasDictionaryFilters {
                    Button {
                        resetDictionaryFilters()
                    } label: {
                        Label("条件をリセット", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.vertical, 14)
        }
        .listRowBackground(Color.clear)
    }

    private func resetDictionaryFilters() {
        query = ""
        activeGroup = "すべて"
        activeColor = "すべて"
        activeRank = "すべて"
        favoritesOnly = false
    }

    private func dictionaryRow(_ stone: Gemstone) -> some View {
        Button {
            selectedStone = stone
            selectedTab = 0
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(stone.name)
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                    Spacer()
                    if favoriteStoneIDs.contains(stone.id) {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppStyle.gold)
                    }
                    Text(stone.rankRange)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.turquoise)
                }
                Text("\(stone.kana) / \(stone.englishName)")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                Text(stone.marketPrice)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                    .lineLimit(2)
            }
            .padding(.vertical, 6)
        }
    }

    private func rankFilterTitle(for rank: String) -> String {
        switch rank {
        case "S": return "S候補"
        case "A": return "A候補"
        case "B": return "B候補"
        case "C": return "C候補"
        default: return "全ランク"
        }
    }

    private var marketGuide: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                GuideBlock(
                    title: "価格は断定しない",
                    icon: "exclamationmark.magnifyingglass",
                    text: "\(GemstoneDatabase.marketReviewedAt)。写真判定だけでは、処理、産地、重量、鑑別書の有無を確定できません。\(GemstoneDatabase.marketDisclaimer)"
                )
                GuideBlock(
                    title: "レベル表示の目安",
                    icon: "star.leadinghalf.filled",
                    text: "Sは色と透明感が強い候補、Aは状態が良い候補、Bは一般的な流通品、Cは不透明や傷が多い可能性がある候補です。写真からの推定なので、鑑定ランクとは分けて見てください。"
                )
                GuideBlock(
                    title: "写真判定で見ているもの",
                    icon: "camera.metering.matrix",
                    text: "写真の色相、彩度、明るさ、画面内で石が占める範囲を見て、辞典データに近い候補を並べます。似た色の石、染色品、処理品、照明の色かぶりは候補が近く出ます。"
                )
                GuideBlock(
                    title: "翡翠は色、透明度、きめ",
                    icon: "circle.hexagongrid.fill",
                    text: "翡翠は色が最重要です。GIAは色、透明度、質感を主要な評価要素として説明しています。A貨かどうかも価格に直結します。"
                )
                GuideBlock(
                    title: "ターコイズは処理確認",
                    icon: "paintpalette",
                    text: "無処理か、安定化か、染色かで評価が変わります。鮮やかな青、均一な色、硬さ、産地情報が大切です。"
                )
                GuideBlock(
                    title: "相場更新で見る条件",
                    icon: "list.bullet.clipboard",
                    text: "価格を見直すときは、色、透明度、処理、重量、産地、鑑別書、販売店の返品条件を確認します。翡翠はA貨/B貨/C貨、ターコイズは無処理/安定化/染色/再生品の違いを分けて見ます。"
                )
                GuideBlock(
                    title: "詳細データの増やし方",
                    icon: "plus.app",
                    text: "Models.swift の GemstoneDatabase に1件追加すると、検索、五十音、写真候補に自動で反映されます。"
                )
                marketPriceListSection
                marketBuyingChecklistSection
                glossarySection
                VStack(alignment: .leading, spacing: 8) {
                    Text("参考にした考え方")
                        .font(.title3.weight(.bold))
                    Link("GIA: Jadeite Jade Quality Factors", destination: URL(string: "https://www.gia.edu/jade-quality-factor")!)
                    Link("GIA: Turquoise Buyer Guide", destination: URL(string: "https://www.gia.edu/gia-website/turquoise/buyers-guide")!)
                    Link("International Gem Society: Gem Price Guide", destination: URL(string: "https://www.gemsociety.org/article/gem-price-guide/")!)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.jade)
                .padding(16)
                .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            }
            .padding(12)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.background.ignoresSafeArea())
    }

    private var marketPriceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(GemstoneDatabase.stones.count)種類の相場一覧", systemImage: "list.bullet.rectangle")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            Text("\(GemstoneDatabase.marketReviewedAt)。各行をタップすると、硬度、比重、処理、見分け方まで確認できます。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(3)
            VStack(spacing: 8) {
                ForEach(marketPriceRows) { stone in
                    Button {
                        selectedStone = stone
                        selectedTab = 0
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(stone.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppStyle.ink)
                                    Text(stone.rankRange)
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(AppStyle.jade, in: Capsule())
                                }
                                Text(stone.marketPrice)
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.muted)
                                    .lineLimit(3)
                                    .lineSpacing(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppStyle.turquoise)
                                .padding(.top, 4)
                        }
                        .padding(10)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .accessibilityIdentifier("marketPriceList")
    }

    private var marketPriceRows: [Gemstone] {
        GemstoneDatabase.stones.sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    private var marketBuyingChecklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("買う前に見る項目", systemImage: "checklist")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            Text("相場だけで判断せず、石の状態と販売条件を同じ画面で確認します。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(3)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(marketBuyingChecklistItems, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(item.title, systemImage: item.icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    .padding(10)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                }
            }
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var marketBuyingChecklistItems: [(title: String, icon: String, detail: String)] {
        [
            ("処理", "wand.and.stars", "翡翠はA貨/B貨/C貨、ターコイズは無処理/安定化/染色/再生品を分けて確認します。"),
            ("証明", "doc.text.magnifyingglass", "高額品は鑑別書、販売証明、返品条件を見ます。説明が曖昧な高ランク表記は慎重に扱います。"),
            ("品質", "sparkle.magnifyingglass", "色、透明度、傷、欠け、内包物、研磨の状態を見ます。写真だけでは断定しません。"),
            ("価格", "tag", "同じ石名でも重量、産地、処理、販売店で幅があります。市場価格は固定額ではなく目安です。")
        ]
    }

    private var glossarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("鑑別・相場の用語集", systemImage: "text.book.closed")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppStyle.ink)
            Text("辞典や判定結果で出る言葉を、購入前に確認しやすい形でまとめています。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(3)
            ForEach(glossaryTerms) { term in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(term.title)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppStyle.ink)
                        Text(term.category)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppStyle.turquoise)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.7), in: Capsule())
                    }
                    Text(term.detail)
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            }
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var glossaryTerms: [GlossaryTerm] {
        [
            GlossaryTerm(title: "A貨翡翠", category: "翡翠", detail: "天然翡翠にワックス程度の仕上げをしたもの。樹脂含浸や染色がないかを鑑別書で確認します。"),
            GlossaryTerm(title: "B貨/C貨", category: "翡翠", detail: "B貨は漂白や樹脂含浸、C貨は染色を含む流通表現です。価格とランク評価が大きく変わります。"),
            GlossaryTerm(title: "含浸", category: "処理", detail: "割れや隙間に樹脂、オイル、ガラスなどを入れる処理です。透明感は上がって見えても価値評価は変わります。"),
            GlossaryTerm(title: "染色", category: "処理", detail: "色を人工的に足す処理です。表面だけ濃い色、割れ目に強い色が集まる場合は注意します。"),
            GlossaryTerm(title: "安定化", category: "ターコイズ", detail: "樹脂などで硬さや耐久性を補う処理です。ターコイズでは一般的ですが、無処理品とは価格が違います。"),
            GlossaryTerm(title: "再生品", category: "ターコイズ", detail: "粉末や破片を固めたものです。天然ターコイズ名で高額販売されていないか確認します。"),
            GlossaryTerm(title: "硬度", category: "物性", detail: "傷つきにくさの目安です。水晶は7、翡翠は6.5〜7前後。似た石の判別に使います。"),
            GlossaryTerm(title: "比重", category: "物性", detail: "同じ大きさでどれくらい重いかの目安です。翡翠、ガーネット、ヘマタイトなどは比重差が判別の助けになります。"),
            GlossaryTerm(title: "屈折率", category: "物性", detail: "光の曲がり方を示す数値です。鑑別機関や専門店では石種確認の重要な手がかりになります。"),
            GlossaryTerm(title: "カラット", category: "価格", detail: "宝石の重さの単位で、1ctは0.2gです。市場価格の幅はct単価、処理、色、透明度で変わります。"),
            GlossaryTerm(title: "鑑別書", category: "購入", detail: "石種、処理、天然/合成の判断材料です。高額品では販売説明だけでなく鑑別書と返品条件を確認します。")
        ]
    }

    private func classify(_ image: UIImage) {
        let result = ImageClassifier.classify(image, reference: reference)
        scanMetrics = result.metrics
        candidates = result.candidates
        if let first = result.candidates.first {
            updateLiveStability(with: first)
            if !liveMode || liveStableCount >= 2 || selectedStone.id == first.gemstone.id {
                selectedStone = first.gemstone
            }
            if !liveMode || liveStableCount == 2 {
                recordScanHistory(candidate: first, metrics: result.metrics)
            }
        }
    }

    private func runDemoSample(_ sample: DemoStoneSample) {
        stopLiveScanning()
        reference = .none
        let image = Self.makeDemoSampleImage(primary: sample.primary, matrix: sample.matrix)
        capturedImage = image
        classify(image)
    }

    private static func makeDemoSampleImage(primary: UIColor, matrix: UIColor) -> UIImage {
        let size = CGSize(width: 720, height: 540)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.84, green: 0.82, blue: 0.76, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let stoneRect = CGRect(x: 120, y: 88, width: 480, height: 340)
            matrix.setFill()
            context.cgContext.fillEllipse(in: stoneRect)

            primary.setFill()
            context.cgContext.fillEllipse(in: stoneRect.insetBy(dx: 24, dy: 22))

            UIColor.white.withAlphaComponent(0.24).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 246, y: 142, width: 142, height: 58))

            UIColor.black.withAlphaComponent(0.10).setStroke()
            context.cgContext.setLineWidth(12)
            context.cgContext.strokeEllipse(in: stoneRect.insetBy(dx: 8, dy: 8))

            UIColor.black.withAlphaComponent(0.14).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 210, y: 412, width: 300, height: 42))
        }
    }

    private func recordScanHistory(candidate: StoneCandidate, metrics: ScanMetrics) {
        if let latest = scanHistory.first,
           latest.gemstone.id == candidate.gemstone.id,
           latest.score == candidate.score,
           latest.sizeLabel == metrics.sizeLabel,
           latest.sizeConfidenceLabel == metrics.sizeConfidenceLabel,
           latest.referenceLabel == reference.rawValue {
            return
        }

        scanHistory.insert(
            ScanHistoryEntry(
                date: Date(),
                gemstone: candidate.gemstone,
                score: candidate.score,
                levelLabel: metrics.levelLabel,
                sizeLabel: metrics.sizeLabel,
                sizeConfidenceLabel: metrics.sizeConfidenceLabel,
                referenceLabel: reference.rawValue
            ),
            at: 0
        )

        if scanHistory.count > 8 {
            scanHistory.removeLast(scanHistory.count - 8)
        }
        saveScanHistory()
    }

    private func saveCandidateToHistory(_ candidate: StoneCandidate) {
        guard let scanMetrics else { return }
        selectedStone = candidate.gemstone
        recordScanHistory(candidate: candidate, metrics: scanMetrics)
    }

    private func shareText(for candidate: StoneCandidate, metrics: ScanMetrics?) -> String {
        let level = metrics?.levelLabel ?? "-"
        let size = metrics?.sizeLabel ?? "未計測"
        let referenceLabel = reference.rawValue
        return [
            "天然石判定メモ",
            "候補: \(candidate.gemstone.name) / \(candidate.gemstone.englishName)",
            "一致率: \(candidate.score)%",
            "レベル候補: \(level)",
            "透明度: \(candidate.gemstone.shortTransparency)",
            "サイズ: \(size)",
            "基準物: \(referenceLabel)",
            "サイズ信頼度: \(metrics?.sizeConfidenceLabel ?? "-")",
            "相場目安: \(candidate.gemstone.marketPrice)",
            "注意: 写真判定は目安です。高額品は鑑別書で確認してください。"
        ].joined(separator: "\n")
    }

    private func shareText(for entry: ScanHistoryEntry) -> String {
        [
            "天然石判定メモ",
            "候補: \(entry.gemstone.name) / \(entry.gemstone.englishName)",
            "一致率: \(entry.score)%",
            "レベル候補: \(entry.levelLabel)",
            "透明度: \(entry.gemstone.shortTransparency)",
            "サイズ: \(entry.sizeLabel)",
            "基準物: \(entry.referenceLabel)",
            "サイズ信頼度: \(entry.sizeConfidenceLabel)",
            "相場目安: \(entry.gemstone.marketPrice)",
            "注意: 写真判定は目安です。高額品は鑑別書で確認してください。"
        ].joined(separator: "\n")
    }

    private func loadScanHistory() {
        guard scanHistory.isEmpty,
              let data = UserDefaults.standard.data(forKey: scanHistoryStorageKey),
              let stored = try? JSONDecoder().decode([StoredScanHistoryEntry].self, from: data) else {
            return
        }

        scanHistory = stored.compactMap { item in
            guard let stone = GemstoneDatabase.stones.first(where: { $0.id == item.gemstoneID }) else {
                return nil
            }
            return ScanHistoryEntry(
                date: item.date,
                gemstone: stone,
                score: item.score,
                levelLabel: item.levelLabel,
                sizeLabel: item.sizeLabel,
                sizeConfidenceLabel: item.sizeConfidenceLabel ?? "未記録",
                referenceLabel: item.referenceLabel ?? "基準なし"
            )
        }
    }

    private func saveScanHistory() {
        let stored = scanHistory.map {
            StoredScanHistoryEntry(
                date: $0.date,
                gemstoneID: $0.gemstone.id,
                score: $0.score,
                levelLabel: $0.levelLabel,
                sizeLabel: $0.sizeLabel,
                sizeConfidenceLabel: $0.sizeConfidenceLabel,
                referenceLabel: $0.referenceLabel
            )
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: scanHistoryStorageKey)
        }
    }

    private func toggleFavorite(_ stone: Gemstone) {
        if favoriteStoneIDs.contains(stone.id) {
            favoriteStoneIDs.remove(stone.id)
        } else {
            favoriteStoneIDs.insert(stone.id)
        }
        saveFavoriteStones()
    }

    private func loadFavoriteStones() {
        guard favoriteStoneIDs.isEmpty,
              let stored = UserDefaults.standard.stringArray(forKey: favoriteStonesStorageKey) else {
            return
        }
        favoriteStoneIDs = Set(stored)
    }

    private func saveFavoriteStones() {
        UserDefaults.standard.set(Array(favoriteStoneIDs).sorted(), forKey: favoriteStonesStorageKey)
    }

    private func updateLiveStability(with candidate: StoneCandidate) {
        guard liveMode else {
            liveStableCandidateID = candidate.gemstone.id
            liveStableCount = 1
            return
        }

        if liveStableCandidateID == candidate.gemstone.id {
            liveStableCount = min(liveStableCount + 1, 9)
        } else {
            liveStableCandidateID = candidate.gemstone.id
            liveStableCount = 1
        }
    }

    private func toggleLiveScanning() {
        if liveMode {
            stopLiveScanning()
        } else {
            liveMode = true
            liveStableCandidateID = nil
            liveStableCount = 0
            liveScanner.start()
        }
    }

    private func stopLiveScanning() {
        liveMode = false
        liveStableCandidateID = nil
        liveStableCount = 0
        liveScanner.stop()
    }

    private func dictionaryColorSwatch(_ color: String) -> Color {
        switch color {
        case "赤": return .red
        case "桃", "ピンク", "薄桃": return .pink
        case "橙": return .orange
        case "黄", "金": return AppStyle.gold
        case "黄緑": return Color(red: 0.62, green: 0.78, blue: 0.22)
        case "緑", "青緑": return AppStyle.jade
        case "水色", "青": return AppStyle.turquoise
        case "藍", "青紫": return Color(red: 0.25, green: 0.32, blue: 0.72)
        case "紫", "薄紫": return Color(red: 0.55, green: 0.37, blue: 0.78)
        case "茶": return Color(red: 0.48, green: 0.30, blue: 0.18)
        case "黒": return Color(red: 0.08, green: 0.08, blue: 0.08)
        case "白", "無色": return .white
        case "灰", "銀": return .gray
        case "虹", "多色", "縞": return Color(red: 0.58, green: 0.48, blue: 0.90)
        default: return AppStyle.line
        }
    }

    private func classificationEvidence(for candidate: StoneCandidate, metrics: ScanMetrics) -> [String] {
        let hue = Int(round(metrics.hue))
        let saturation = Int(round(metrics.saturation))
        let brightness = Int(round(metrics.brightness))
        let range = hueRangeText(candidate.gemstone.hueRange)
        return [
            "色相 \(hue)°。\(candidate.gemstone.name)の想定色 \(range) と比べています。",
            "彩度 \(saturation)%、明るさ \(brightness)%。色の濃さと透明感の目安に使います。",
            "画面内サイズ \(metrics.coverageScore)%。石が大きく写るほど候補の安定度が上がります。",
            "似た色の石、染色品、処理品は候補が近く出ます。高額品は鑑別書で確認してください。"
        ]
    }

    private func hueRangeText(_ range: ClosedRange<Double>) -> String {
        if range.lowerBound == 0, range.upperBound == 360 {
            return "全色"
        }
        return "\(Int(round(range.lowerBound)))°-\(Int(round(range.upperBound)))°"
    }

    private func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.widthInsensitive, .caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let scalars = folded.unicodeScalars.map { scalar -> UnicodeScalar in
            let value = scalar.value
            if (0x30A1...0x30F6).contains(value), let hiragana = UnicodeScalar(value - 0x60) {
                return hiragana
            }
            return scalar
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

struct StoneDetailView: View {
    let stone: Gemstone
    var isFavorite = false
    var onToggleFavorite: () -> Void = {}
    var onSelectSimilar: (Gemstone) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stone.kana)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.turquoise)
                    Text(stone.name)
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundStyle(AppStyle.ink)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text(stone.englishName)
                        .font(.headline)
                        .foregroundStyle(AppStyle.muted)
                }
                Spacer()
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isFavorite ? AppStyle.gold : AppStyle.muted)
                        .padding(10)
                        .background(.white.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(AppStyle.line))
                }
                .accessibilityLabel(isFavorite ? "お気に入りから外す" : "お気に入りに追加")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                FactTile(title: "ランク", value: stone.rankRange)
                FactTile(title: "硬度", value: stone.hardness)
                FactTile(title: "比重", value: stone.specificGravity)
                FactTile(title: "屈折率", value: stone.refractiveIndex)
            }

            ShareLink(item: detailShareText) {
                Label("詳細メモを共有", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            rankGuideSection
            physicalReadingSection
            TextBlock(title: "透明度", text: stone.transparency)
            TextBlock(title: "市場価格", text: "\(stone.marketPrice)\n\(GemstoneDatabase.marketReviewedAt)。\(GemstoneDatabase.marketDisclaimer)")
            treatmentAlertSection
            purchaseChecklistSection
            appraisalMemoSection
            BulletBlock(title: "価格が上がる条件", items: stone.priceFactors)
            similarStoneSection
            confusingStoneSection
            BulletBlock(title: "見分け方", items: stone.identificationTips)
            BulletBlock(title: "主な処理", items: stone.treatments)
            TextBlock(title: "扱い方", text: stone.care)
            TextBlock(title: "メモ", text: stone.note)
        }
        .padding(12)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var rankGuideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ランク目安", systemImage: "star.leadinghalf.filled")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(rankGuideItems, id: \.grade) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text(item.grade)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(rankColor(for: item.grade), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(2)
                    }
                }
            }
            Text("写真のレベル表示は鑑定ランクではありません。実際のランクは実物、処理、重量、産地、鑑別書で確認してください。")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(2)
        }
    }

    private var detailShareText: String {
        [
            "天然石詳細メモ",
            "名称: \(stone.name) / \(stone.englishName)",
            "かな: \(stone.kana)",
            "ランク目安: \(stone.rankRange)",
            "硬度: \(stone.hardness)",
            "比重: \(stone.specificGravity)",
            "屈折率: \(stone.refractiveIndex)",
            "透明度: \(stone.transparency)",
            "相場目安: \(stone.marketPrice)",
            "価格条件: \(stone.priceFactors.prefix(3).joined(separator: " / "))",
            "処理確認: \(stone.treatments.prefix(3).joined(separator: " / "))",
            "見分け方: \(stone.identificationTips.prefix(3).joined(separator: " / "))",
            "注意: 写真判定と相場は目安です。高額品は鑑別書、処理説明、返品条件を確認してください。"
        ].joined(separator: "\n")
    }

    private var rankGuideItems: [(grade: String, title: String, detail: String)] {
        let topFactors = stone.priceFactors.prefix(2).joined(separator: "、")
        let treatments = stone.treatments.prefix(2).joined(separator: "、")
        return [
            ("S", "上質候補", "\(topFactors)が強く、傷や色むらが少ない。高額品は鑑別書で確認。"),
            ("A", "良品候補", "色と透明感のバランスがよく、処理内容が明記されている。"),
            ("B", "一般流通候補", "見た目は楽しめるが、内包物、色むら、一般的な処理を確認。主な処理: \(treatments)。"),
            ("C", "注意候補", "染色、含浸、欠け、強い濁り、名称違いに注意。価格だけで判断しない。")
        ]
    }

    private var physicalReadingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("数値の見方", systemImage: "number.circle")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(physicalReadingItems, id: \.title) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppStyle.turquoise)
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.7), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    private var physicalReadingItems: [(title: String, icon: String, detail: String)] {
        [
            ("硬度 \(stone.hardness)", "shield.lefthalf.filled", "傷つきにくさの目安です。数値が高いほど日常傷に強く、低い石はリングよりペンダント向きです。"),
            ("比重 \(stone.specificGravity)", "scalemass", "同じ大きさでの重さの目安です。翡翠、ガーネット、ヘマタイトのように重さが判別の助けになる石があります。"),
            ("屈折率 \(stone.refractiveIndex)", "sparkle.magnifyingglass", "光の曲がり方です。写真では測れませんが、鑑別書や専門店で石種確認に使う重要な数値です。")
        ]
    }

    private func rankColor(for grade: String) -> Color {
        switch grade {
        case "S": return AppStyle.gold
        case "A": return AppStyle.jade
        case "B": return AppStyle.turquoise
        default: return AppStyle.garnet
        }
    }

    private var treatmentAlertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("処理・注意ハイライト", systemImage: "exclamationmark.shield")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(treatmentAlertItems, id: \.title) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: item.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(item.isCaution ? AppStyle.garnet : AppStyle.gold)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            }
        }
    }

    private var treatmentAlertItems: [(title: String, detail: String, icon: String, isCaution: Bool)] {
        var items: [(title: String, detail: String, icon: String, isCaution: Bool)] = [
            (
                title: "確認する処理",
                detail: stone.treatments.joined(separator: " / "),
                icon: "wand.and.stars",
                isCaution: true
            )
        ]

        if stone.treatments.contains(where: { $0.contains("染色") || $0.contains("含浸") || $0.contains("樹脂") || $0.contains("再生") }) {
            items.append((
                title: "価格差に注意",
                detail: "染色、含浸、樹脂、再生品は見た目が良くても評価が変わります。高額品は鑑別書で処理欄を確認してください。",
                icon: "exclamationmark.triangle.fill",
                isCaution: true
            ))
        } else {
            items.append((
                title: "説明の確認",
                detail: "無処理表記でも、加熱、ワックス、安定化などの説明がないか販売情報を確認してください。",
                icon: "doc.text.magnifyingglass",
                isCaution: false
            ))
        }

        items.append((
            title: "扱い方",
            detail: stone.care,
            icon: "hand.raised.fill",
            isCaution: false
        ))
        return items
    }

    private var purchaseChecklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("購入前チェック", systemImage: "checklist.checked")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(purchaseChecklistItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(AppStyle.gold)
                        .padding(.top, 3)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(3)
                }
            }
        }
    }

    private var purchaseChecklistItems: [String] {
        [
            "相場は目安です。重量、産地、販売店、鑑別書の有無で大きく変わります。",
            "処理確認: \(stone.treatments.prefix(3).joined(separator: " / "))",
            "価格条件: \(stone.priceFactors.prefix(2).joined(separator: " / "))",
            "見分け方: \(stone.identificationTips.prefix(2).joined(separator: " / "))",
            "写真判定だけで購入判断をせず、高額品は鑑別書と返品条件を確認してください。"
        ]
    }

    private var appraisalMemoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("鑑別・ランク確認メモ", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(appraisalMemoItems, id: \.title) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.turquoise)
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            }
        }
    }

    private var appraisalMemoItems: [(title: String, detail: String)] {
        [
            (
                "名称の照合",
                "\(stone.name) / \(stone.englishName)。別名や流通名だけで判断せず、鑑別書の鉱物名と照らし合わせます。"
            ),
            (
                "数値の照合",
                "硬度 \(stone.hardness)、比重 \(stone.specificGravity)、屈折率 \(stone.refractiveIndex)。写真候補が近い石は、この数値で差を見ます。"
            ),
            (
                "処理の確認",
                stone.treatments.joined(separator: " / ") + "。処理は価格とランク表示に直結します。"
            ),
            (
                "価格の照合",
                "\(stone.marketPrice) \(GemstoneDatabase.marketReviewedAt)。安すぎる高ランク表記や、処理説明のない高額品は慎重に見ます。"
            )
        ]
    }

    private var similarStoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("似ている石")
                .font(.headline)
            ForEach(similarStones) { similar in
                Button {
                    onSelectSimilar(similar)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(similar.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppStyle.ink)
                            Text(similarityNote(for: similar))
                                .font(.caption)
                                .foregroundStyle(AppStyle.muted)
                                .lineSpacing(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppStyle.turquoise)
                    }
                    .padding(10)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                }
                .buttonStyle(.plain)
            }
            Text("写真判定で候補が近いときは、ここから硬度、比重、処理、価格条件を比べてください。")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(2)
        }
    }

    private var similarStones: [Gemstone] {
        Array(
            GemstoneDatabase.stones
                .filter { $0.id != stone.id }
                .sorted { similarityDistance(to: $0) < similarityDistance(to: $1) }
                .prefix(4)
        )
    }

    private var confusingStoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("迷いやすい石", systemImage: "arrow.left.arrow.right.circle")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            ForEach(confusingStones) { other in
                Button {
                    onSelectSimilar(other)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(other.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppStyle.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppStyle.turquoise)
                        }
                        Text(confusingCue(for: other))
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(3)
                        HStack(spacing: 6) {
                            MiniInfoLabel(title: "硬度", value: other.hardness)
                            MiniInfoLabel(title: "比重", value: other.specificGravity)
                            MiniInfoLabel(title: "処理", value: other.treatments.prefix(1).joined())
                        }
                    }
                    .padding(10)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                }
                .buttonStyle(.plain)
            }
            Text("色が近いと写真判定では候補が寄ります。迷うときは硬度、比重、屈折率、処理、価格条件を並べて見ます。")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(2)
        }
    }

    private var confusingStones: [Gemstone] {
        let ids = confusingStoneIDs(for: stone.id)
        return ids.compactMap { id in
            GemstoneDatabase.stones.first { $0.id == id }
        }
    }

    private func confusingStoneIDs(for id: String) -> [String] {
        switch id {
        case "jadeite": return ["nephrite", "chrysoprase", "prehnite"]
        case "nephrite": return ["jadeite", "chrysoprase", "prehnite"]
        case "turquoise": return ["amazonite", "apatite", "larimar"]
        case "amazonite": return ["turquoise", "apatite", "aquamarine"]
        case "apatite": return ["turquoise", "amazonite", "aquamarine"]
        case "lapis-lazuli": return ["iolite", "sapphire", "kyanite"]
        case "sapphire": return ["iolite", "lapis-lazuli", "kyanite"]
        case "ruby": return ["garnet", "spinel", "tourmaline"]
        case "garnet": return ["ruby", "spinel", "tourmaline"]
        case "amethyst": return ["iolite", "fluorite", "kunzite"]
        case "citrine": return ["topaz", "sunstone", "carnelian"]
        case "aquamarine": return ["topaz", "apatite", "amazonite"]
        default:
            return similarStones.map(\.id)
        }
    }

    private func confusingCue(for other: Gemstone) -> String {
        let ownHardness = stone.hardness
        let ownGravity = stone.specificGravity
        return "\(stone.name)は硬度 \(ownHardness)、比重 \(ownGravity)。\(other.name)は硬度 \(other.hardness)、比重 \(other.specificGravity)。名称、処理、価格条件を確認してください。"
    }

    private func similarityNote(for other: Gemstone) -> String {
        let hue = Int(round(hueDistance(stoneHueCenter, other.hueCenter)))
        let saturation = Int(round(abs(stone.saturationCenter - other.saturationCenter)))
        return "色相差 約\(hue)° / 彩度差 約\(saturation)% / \(other.shortTransparency)"
    }

    private func similarityDistance(to other: Gemstone) -> Double {
        hueDistance(stoneHueCenter, other.hueCenter) + abs(stone.saturationCenter - other.saturationCenter) * 0.45
    }

    private var stoneHueCenter: Double {
        stone.hueCenter
    }

    private func hueDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }
}

struct FactTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }
}

struct TextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(4)
        }
    }
}

struct BulletBlock: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppStyle.jade)
                        .font(.caption)
                        .padding(.top, 3)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                        .lineSpacing(3)
                }
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let score: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppStyle.muted)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppStyle.line)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 9)
        }
    }
}

struct ScoreBadge: View {
    let score: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("\(score)")
                .font(.title3.weight(.black))
            Text("%")
                .font(.caption2.weight(.black))
        }
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(AppStyle.jade, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MiniInfoLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.68), in: Capsule())
        .overlay(Capsule().stroke(AppStyle.line))
    }
}

struct GuideBlock: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppStyle.gold)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .background(AppStyle.jade.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(AppStyle.ink)
            .padding(.vertical, 13)
            .background(.white.opacity(configuration.isPressed ? 0.58 : 0.88), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }
}

struct DemoSampleButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppStyle.ink)
            .padding(10)
            .background(.white.opacity(configuration.isPressed ? 0.58 : 0.86), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .padding(8)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isActive ? .white : AppStyle.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isActive ? AppStyle.turquoise : .white.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

enum AppStyle {
    static let ink = Color(red: 0.11, green: 0.13, blue: 0.11)
    static let muted = Color(red: 0.39, green: 0.43, blue: 0.40)
    static let jade = Color(red: 0.18, green: 0.49, blue: 0.39)
    static let turquoise = Color(red: 0.07, green: 0.54, blue: 0.61)
    static let gold = Color(red: 0.82, green: 0.55, blue: 0.16)
    static let garnet = Color(red: 0.49, green: 0.14, blue: 0.20)
    static let line = Color.black.opacity(0.12)
    static let panel = Color(red: 1.0, green: 0.985, blue: 0.94).opacity(0.92)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.95, blue: 0.88),
            Color(red: 0.91, green: 0.95, blue: 0.91),
            Color(red: 0.98, green: 0.93, blue: 0.86)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
