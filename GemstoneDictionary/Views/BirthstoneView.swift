import SwiftUI

struct BirthstoneView: View {
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedStone: Gemstone? = nil
    private let en = isEnglish()

    var currentBirthstone: BirthstoneInfo? {
        GemstoneDatabase.birthstones.first { $0.month == selectedMonth }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard
                monthGrid
                if let info = currentBirthstone {
                    selectedMonthCard(info)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.background.ignoresSafeArea())
        .navigationTitle(en ? "Birthstones" : "誕生石")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStone) { stone in
            NavigationStack {
                StoneDetailSheet(stone: stone)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(en ? "BIRTHSTONE GUIDE" : "BIRTHSTONE GUIDE")
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            Text(en ? "Birthstones" : "誕生石")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundStyle(AppStyle.ink)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(en
                ? "Discover the gemstone of your birth month and its meaning."
                : "生まれ月の石と意味を探してみましょう。")
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

    private var monthGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68, maximum: 100))], spacing: 10) {
            ForEach(1...12, id: \.self) { month in
                MonthCell(
                    month: month,
                    isSelected: selectedMonth == month,
                    info: GemstoneDatabase.birthstones.first { $0.month == month }
                ) {
                    selectedMonth = month
                }
            }
        }
    }

    private func selectedMonthCard(_ info: BirthstoneInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(en ? info.monthNameEn : info.monthName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.turquoise)
                    Text(en ? "Birthstone" : "誕生石")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppStyle.ink)
                }
                Spacer()
                Text("\(info.month)")
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .foregroundStyle(AppStyle.gold.opacity(0.4))
            }

            Text(en ? info.meaningEn : info.meaning)
                .font(.body)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(5)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(en ? "Stones" : "対応する石")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppStyle.turquoise)

                ForEach(stonesForInfo(info), id: \.id) { stone in
                    Button {
                        selectedStone = stone
                    } label: {
                        BirthstoneRow(stone: stone)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private func stonesForInfo(_ info: BirthstoneInfo) -> [Gemstone] {
        info.stones.compactMap { id in
            GemstoneDatabase.stones.first { $0.id == id }
        }
    }
}

private struct MonthCell: View {
    let month: Int
    let isSelected: Bool
    let info: BirthstoneInfo?
    let action: () -> Void
    private let en = isEnglish()

    private var monthLabel: String {
        let short = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let ja = ["1月", "2月", "3月", "4月", "5月", "6月",
                  "7月", "8月", "9月", "10月", "11月", "12月"]
        guard month >= 1, month <= 12 else { return "" }
        return en ? short[month - 1] : ja[month - 1]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(monthLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : AppStyle.ink)
                if let stone = info?.stones.first,
                   let gem = GemstoneDatabase.stones.first(where: { $0.id == stone }) {
                    Circle()
                        .fill(hueColor(gem.hueCenter, sat: gem.saturationCenter))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AppStyle.jade : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? AppStyle.jade : AppStyle.line))
        }
        .buttonStyle(.plain)
    }
}

private struct BirthstoneRow: View {
    let stone: Gemstone
    private let en = isEnglish()

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(AppStyle.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(en ? stone.englishName : stone.name)
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(en ? stone.name : stone.englishName)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
        }
        .padding(12)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }
}

// MARK: - Stone Detail Sheet (reused across views)

struct StoneDetailSheet: View {
    let stone: Gemstone
    @Environment(\.dismiss) private var dismiss
    private let en = isEnglish()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(AppStyle.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(en ? stone.englishName : stone.name)
                            .font(.title2.weight(.bold))
                        Text(en ? stone.name : stone.kana)
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
                    }
                    Spacer()
                }
                .padding(16)
                .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))

                infoGrid
                    .padding(16)
                    .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))

                if !stone.note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(en ? "Note" : "メモ")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppStyle.turquoise)
                        Text(stone.note)
                            .font(.body)
                            .foregroundStyle(AppStyle.muted)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
                }
            }
            .padding(12)
        }
        .background(AppStyle.background.ignoresSafeArea())
        .navigationTitle(en ? stone.englishName : stone.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(en ? "Done" : "閉じる") { dismiss() }
            }
        }
    }

    private var infoGrid: some View {
        VStack(spacing: 8) {
            infoRow(en ? "Hardness" : "硬度", stone.hardness)
            infoRow(en ? "Transparency" : "透明度", stone.shortTransparency)
            infoRow(en ? "Rank" : "ランク", stone.rankRange)
            infoRow(en ? "Market Price" : "市場価格", stone.marketPrice)
            if !stone.care.isEmpty {
                infoRow(en ? "Care" : "お手入れ", stone.care)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(AppStyle.ink)
                .lineSpacing(3)
            Spacer()
        }
    }
}

// MARK: - Color from hue helper

func hueColor(_ hue: Double, sat: Double) -> Color {
    let h = hue / 360.0
    let s = min(max(sat / 100.0, 0.2), 0.9)
    return Color(hue: h, saturation: s, brightness: 0.78)
}
