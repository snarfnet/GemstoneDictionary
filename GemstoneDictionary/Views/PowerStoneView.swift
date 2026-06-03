import SwiftUI

struct PowerStoneView: View {
    @State private var selectedEffect: String = "すべて"
    @State private var selectedStone: Gemstone? = nil
    private let en = isEnglish()

    private let effects: [(ja: String, en: String, icon: String, color: Color)] = [
        ("すべて",  "All",          "sparkles",              AppStyle.turquoise),
        ("恋愛運",  "Love",         "heart.fill",            Color(red: 0.85, green: 0.25, blue: 0.35)),
        ("金運",    "Wealth",       "yensign.circle.fill",   Color(red: 0.82, green: 0.55, blue: 0.16)),
        ("健康運",  "Health",       "leaf.fill",             Color(red: 0.18, green: 0.62, blue: 0.38)),
        ("仕事運",  "Career",       "briefcase.fill",        Color(red: 0.07, green: 0.54, blue: 0.61)),
        ("厄除け",  "Protection",   "shield.fill",           Color(red: 0.49, green: 0.14, blue: 0.20)),
        ("人間関係","Relationships","person.2.fill",          Color(red: 0.42, green: 0.30, blue: 0.70)),
        ("創造性",  "Creativity",   "paintbrush.fill",       Color(red: 0.80, green: 0.40, blue: 0.10))
    ]

    private var filteredStones: [Gemstone] {
        if selectedEffect == "すべて" {
            return GemstoneDatabase.stones.sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
        }
        return GemstoneDatabase.stones
            .filter { GemstoneDatabase.effects(for: $0.id).contains(selectedEffect) }
            .sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    private var currentEffect: (ja: String, en: String, icon: String, color: Color) {
        effects.first { $0.ja == selectedEffect } ?? effects[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard
                effectGrid
                stonesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.background.ignoresSafeArea())
        .navigationTitle(en ? "Power Stones" : "パワーストーン効果検索")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStone) { stone in
            NavigationStack {
                StoneDetailSheet(stone: stone)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POWER STONE SEARCH")
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            Text(en ? "Effect Search" : "パワーストーン効果検索")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundStyle(AppStyle.ink)
            Text(en
                ? "Find stones by their traditional effect category."
                : "望む効果のカテゴリから石を探してみましょう。")
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

    private var effectGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(effects, id: \.ja) { effect in
                EffectCell(
                    label: en ? effect.en : effect.ja,
                    icon: effect.icon,
                    color: effect.color,
                    isSelected: selectedEffect == effect.ja
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEffect = effect.ja
                    }
                }
            }
        }
    }

    private var stonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: currentEffect.icon)
                    .foregroundStyle(currentEffect.color)
                Text(en ? currentEffect.en : currentEffect.ja)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
                Spacer()
                Text("\(filteredStones.count)\(en ? " stones" : "種")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.muted)
            }

            if filteredStones.isEmpty {
                Text(en ? "No stones in this category." : "該当する石はありません。")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                    .padding(16)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(filteredStones) { stone in
                        PowerStoneCard(stone: stone, highlightEffect: selectedEffect == "すべて" ? nil : selectedEffect) {
                            selectedStone = stone
                        }
                    }
                }
            }
        }
    }
}

private struct EffectCell: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : AppStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? color : AppStyle.line))
        }
        .buttonStyle(.plain)
    }
}

private struct PowerStoneCard: View {
    let stone: Gemstone
    let highlightEffect: String?
    let action: () -> Void
    private let en = isEnglish()

    private var effects: [String] { GemstoneDatabase.effects(for: stone.id) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppStyle.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(en ? stone.englishName : stone.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppStyle.ink)
                            .lineLimit(1)
                        Text(en ? stone.name : stone.kana)
                            .font(.caption2)
                            .foregroundStyle(AppStyle.muted)
                            .lineLimit(1)
                    }
                }

                if !effects.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(effects, id: \.self) { effect in
                            Text(effect)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(effect == highlightEffect ? .white : AppStyle.turquoise)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    effect == highlightEffect ? AppStyle.turquoise : AppStyle.turquoise.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple flow layout for effect tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
