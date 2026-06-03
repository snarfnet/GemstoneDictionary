import SwiftUI

struct CompatibilityView: View {
    @State private var stone1ID: String = GemstoneDatabase.stones[0].id
    @State private var stone2ID: String = GemstoneDatabase.stones[1].id
    @State private var result: CompatibilityResult? = nil
    private let en = isEnglish()

    private var sortedStones: [Gemstone] {
        GemstoneDatabase.stones.sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    private var stone1: Gemstone { GemstoneDatabase.stones.first { $0.id == stone1ID } ?? GemstoneDatabase.stones[0] }
    private var stone2: Gemstone { GemstoneDatabase.stones.first { $0.id == stone2ID } ?? GemstoneDatabase.stones[1] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard
                pickerSection
                checkButton
                if let result {
                    resultCard(result)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.background.ignoresSafeArea())
        .navigationTitle(en ? "Compatibility" : "石の相性チェック")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STONE COMPATIBILITY")
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            Text(en ? "Compatibility Check" : "石の相性チェック")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundStyle(AppStyle.ink)
            Text(en
                ? "Select two stones to see how well they work together — based on mineral group, color harmony, and hardness."
                : "2つの石を選んで相性を確認。鉱物グループ・色の調和・硬さから総合スコアを出します。")
                .font(.body)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var pickerSection: some View {
        VStack(spacing: 12) {
            stonePickerRow(
                label: en ? "Stone 1" : "石 1",
                selectedID: $stone1ID,
                stone: stone1
            )
            HStack {
                Spacer()
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppStyle.turquoise)
                Spacer()
            }
            stonePickerRow(
                label: en ? "Stone 2" : "石 2",
                selectedID: $stone2ID,
                stone: stone2
            )
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private func stonePickerRow(label: String, selectedID: Binding<String>, stone: Gemstone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            HStack(spacing: 12) {
                Circle()
                    .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(AppStyle.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(en ? stone.englishName : stone.name)
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(en ? stone.name : stone.kana)
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Picker("", selection: selectedID) {
                    ForEach(sortedStones) { s in
                        Text(en ? s.englishName : s.name).tag(s.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: selectedID.wrappedValue) { _, _ in
                    result = nil
                }
            }
        }
    }

    private var checkButton: some View {
        Button {
            withAnimation(.spring(response: 0.4)) {
                result = CompatibilityResult.calculate(stone1: stone1, stone2: stone2)
            }
        } label: {
            Label(en ? "Check Compatibility" : "相性を調べる", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(stone1ID == stone2ID)
    }

    private func resultCard(_ result: CompatibilityResult) -> some View {
        VStack(spacing: 16) {
            // Score gauge
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(en ? result.labelEn : result.label)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(result.color)
                        HStack(spacing: 8) {
                            stoneBadge(stone1)
                            Text("×")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppStyle.muted)
                            stoneBadge(stone2)
                        }
                    }
                    Spacer()
                    ScoreCircle(score: result.score, color: result.color)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppStyle.line)
                        Capsule()
                            .fill(result.color)
                            .frame(width: proxy.size.width * CGFloat(result.score) / 100)
                    }
                }
                .frame(height: 10)
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 6) {
                Text(en ? "Analysis" : "解説")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppStyle.turquoise)
                Text(en ? result.descriptionEn : result.description)
                    .font(.body)
                    .foregroundStyle(AppStyle.muted)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Detail breakdown
            VStack(alignment: .leading, spacing: 10) {
                Text(en ? "Details" : "詳細")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppStyle.turquoise)

                detailRow(icon: "diamond.fill",
                          label: en ? "Hardness" : "硬度",
                          value1: stone1.hardness, value2: stone2.hardness)
                detailRow(icon: "circle.hexagongrid.fill",
                          label: en ? "Colors" : "色",
                          value1: stone1.colors.prefix(3).joined(separator: "・"),
                          value2: stone2.colors.prefix(3).joined(separator: "・"))
                detailRow(icon: "shield.fill",
                          label: en ? "Rank" : "ランク",
                          value1: stone1.rankRange, value2: stone2.rankRange)

                let e1 = GemstoneDatabase.effects(for: stone1.id)
                let e2 = GemstoneDatabase.effects(for: stone2.id)
                let shared = Array(Set(e1).intersection(Set(e2)))
                if !shared.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(AppStyle.gold)
                            .frame(width: 20)
                        Text(en ? "Shared Effects" : "共通の効果")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                            .frame(width: 72, alignment: .leading)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        Text(shared.joined(separator: "・"))
                            .font(.caption)
                            .foregroundStyle(AppStyle.muted)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func stoneBadge(_ stone: Gemstone) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                .frame(width: 12, height: 12)
            Text(en ? stone.englishName : stone.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func detailRow(icon: String, label: String, value1: String, value2: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppStyle.turquoise)
                .frame(width: 20)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.ink)
                .frame(width: 50, alignment: .leading)
            Text(value1)
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
            Text("/ \(value2)")
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
            Spacer()
        }
    }
}

private struct ScoreCircle: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppStyle.line, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppStyle.ink)
                Text("%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppStyle.muted)
            }
        }
        .frame(width: 64, height: 64)
    }
}
