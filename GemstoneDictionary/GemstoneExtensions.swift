import Foundation
import SwiftUI

// MARK: - Birthstone

struct BirthstoneInfo: Identifiable {
    let month: Int
    let stones: [String]  // gemstone IDs
    let meaning: String
    let meaningEn: String

    var id: Int { month }

    var monthName: String {
        let names = ["1月", "2月", "3月", "4月", "5月", "6月",
                     "7月", "8月", "9月", "10月", "11月", "12月"]
        guard month >= 1, month <= 12 else { return "" }
        return names[month - 1]
    }

    var monthNameEn: String {
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        guard month >= 1, month <= 12 else { return "" }
        return names[month - 1]
    }
}

extension GemstoneDatabase {
    static let birthstones: [BirthstoneInfo] = [
        BirthstoneInfo(month: 1, stones: ["garnet", "almandine-garnet"], meaning: "友情・誠実・情熱。新年の始まりに持つと縁を深める石。", meaningEn: "Friendship, loyalty, and passion. A stone said to deepen bonds at the year's start."),
        BirthstoneInfo(month: 2, stones: ["amethyst"], meaning: "平和・知恵・誠実。落ち着きをもたらし、思慮深さを高める石。", meaningEn: "Peace, wisdom, and sincerity. Said to bring calm and encourage thoughtful decisions."),
        BirthstoneInfo(month: 3, stones: ["aquamarine", "bloodstone"], meaning: "勇気・健康・幸福。海のように心を澄ませ、旅の守護石とされる。", meaningEn: "Courage, health, and happiness. Clear as the sea, traditionally a guardian for travelers."),
        BirthstoneInfo(month: 4, stones: ["diamond", "rock-crystal"], meaning: "純粋・永遠・強さ。世界で最も硬い石で、不変の絆を象徴する。", meaningEn: "Purity, eternity, and strength. The hardest stone, symbolizing unbreakable bonds."),
        BirthstoneInfo(month: 5, stones: ["emerald"], meaning: "愛・幸運・再生。春の緑に喩えられ、豊かさをもたらすとされる石。", meaningEn: "Love, good fortune, and renewal. Compared to spring's green, said to bring abundance."),
        BirthstoneInfo(month: 6, stones: ["pearl", "moonstone", "alexandrite"], meaning: "純潔・健康・長寿。月のように穏やかで、女性の守護石とも呼ばれる。", meaningEn: "Purity, health, and longevity. Gentle as moonlight, often called a guardian stone for women."),
        BirthstoneInfo(month: 7, stones: ["ruby"], meaning: "情熱・愛・生命力。太陽に例えられる赤い炎の石で、勝利を導くとされる。", meaningEn: "Passion, love, and vitality. The red flame of the sun, said to lead its wearer to victory."),
        BirthstoneInfo(month: 8, stones: ["peridot", "spinel", "sardonyx"], meaning: "友情・幸運・平和。夜でも光を放つとされた、エジプト王の宝石。", meaningEn: "Friendship, fortune, and peace. Once called the gem of Egyptian pharaohs, said to glow at night."),
        BirthstoneInfo(month: 9, stones: ["sapphire"], meaning: "誠実・知恵・神聖。深い青は真理を映し、高い志を持つ人の守護石。", meaningEn: "Sincerity, wisdom, and sanctity. Deep blue mirrors truth, a guardian for those with lofty ideals."),
        BirthstoneInfo(month: 10, stones: ["opal", "tourmaline", "pink-tourmaline"], meaning: "希望・創造・幸運。虹色の閃光が無限の可能性を象徴する石。", meaningEn: "Hope, creativity, and luck. Rainbow flashes symbolize infinite possibility."),
        BirthstoneInfo(month: 11, stones: ["topaz", "citrine"], meaning: "友情・誠実・知性。黄金色の光が知恵と豊かさをもたらすとされる石。", meaningEn: "Friendship, sincerity, and intellect. Golden light said to bring wisdom and abundance."),
        BirthstoneInfo(month: 12, stones: ["turquoise", "tanzanite", "blue-zircon"], meaning: "幸運・成功・繁栄。空と海を映す青が、旅と未来の守護石とされる。", meaningEn: "Luck, success, and prosperity. Sky-and-sea blue, a guardian for journeys and futures.")
    ]
}

// MARK: - Power Stone Effects

extension GemstoneDatabase {
    static let stoneEffects: [String: [String]] = [
        "jadeite": ["金運", "健康運", "仕事運", "厄除け"],
        "nephrite": ["健康運", "厄除け", "人間関係"],
        "turquoise": ["厄除け", "仕事運", "人間関係", "恋愛運"],
        "amethyst": ["恋愛運", "健康運", "創造性", "人間関係"],
        "rose-quartz": ["恋愛運", "人間関係", "創造性"],
        "citrine": ["金運", "仕事運", "創造性"],
        "lapis-lazuli": ["仕事運", "創造性", "人間関係", "厄除け"],
        "tiger-eye": ["金運", "仕事運", "厄除け"],
        "garnet": ["恋愛運", "情熱", "健康運"],
        "aquamarine": ["恋愛運", "人間関係", "健康運"],
        "diamond": ["恋愛運", "金運", "仕事運"],
        "ruby": ["恋愛運", "健康運", "仕事運"],
        "sapphire": ["仕事運", "創造性", "人間関係"],
        "emerald": ["恋愛運", "金運", "健康運"],
        "pearl": ["恋愛運", "健康運", "人間関係"],
        "opal": ["恋愛運", "創造性", "金運"],
        "topaz": ["金運", "仕事運", "健康運"],
        "moonstone": ["恋愛運", "人間関係", "創造性"],
        "alexandrite": ["仕事運", "創造性", "厄除け"],
        "tanzanite": ["創造性", "仕事運", "人間関係"],
        "peridot": ["金運", "健康運", "人間関係"],
        "spinel": ["健康運", "仕事運", "厄除け"],
        "malachite": ["厄除け", "仕事運", "健康運"],
        "labradorite": ["創造性", "人間関係", "厄除け"],
        "sunstone": ["金運", "仕事運", "恋愛運"],
        "iolite": ["仕事運", "創造性", "人間関係"],
        "kyanite": ["仕事運", "人間関係", "創造性"],
        "zoisite": ["健康運", "人間関係", "恋愛運"],
        "rock-crystal": ["厄除け", "創造性", "健康運"],
        "smoky-quartz": ["厄除け", "健康運", "仕事運"],
        "bloodstone": ["健康運", "厄除け", "仕事運"],
        "chrysocolla": ["恋愛運", "人間関係", "創造性"],
        "chrysoprase": ["恋愛運", "金運", "人間関係"],
        "agate": ["厄除け", "健康運", "人間関係"],
        "onyx": ["厄除け", "仕事運", "健康運"],
        "jasper": ["健康運", "厄除け", "人間関係"],
        "obsidian": ["厄除け", "健康運"],
        "prehnite": ["恋愛運", "人間関係", "健康運"],
        "zircon": ["仕事運", "金運", "厄除け"],
        "blue-zircon": ["仕事運", "金運", "厄除け"],
        "pink-tourmaline": ["恋愛運", "人間関係", "創造性"],
        "tourmaline": ["人間関係", "創造性", "厄除け"],
        "kunzite": ["恋愛運", "人間関係", "創造性"],
        "rhodonite": ["恋愛運", "人間関係", "健康運"],
        "rhodochrosite": ["恋愛運", "人間関係", "創造性"],
        "charoite": ["創造性", "仕事運", "人間関係"],
        "sugilite": ["厄除け", "健康運", "創造性"],
        "amber": ["健康運", "金運", "厄除け"],
        "coral": ["健康運", "恋愛運", "厄除け"],
        "larimar": ["恋愛運", "人間関係", "創造性"],
        "pyrite": ["金運", "仕事運"],
        "hematite": ["健康運", "仕事運", "厄除け"],
        "lepidolite": ["恋愛運", "人間関係", "健康運"],
        "fluorite": ["創造性", "仕事運", "人間関係"],
        "apatite": ["仕事運", "創造性", "健康運"],
        "celestite": ["創造性", "人間関係", "恋愛運"],
        "seraphinite": ["健康運", "人間関係", "恋愛運"],
        "moldavite": ["創造性", "仕事運", "厄除け"],
        "tektite": ["仕事運", "創造性", "厄除け"],
        "garnet-tsavorite": ["金運", "健康運", "仕事運"],
        "garnet-spessartine": ["恋愛運", "仕事運", "創造性"],
        "garnet-demantoid": ["金運", "健康運", "創造性"],
        "almandine-garnet": ["恋愛運", "健康運", "仕事運"],
        "rainbow-moonstone": ["恋愛運", "人間関係", "創造性"],
        "actinolite": ["健康運", "厄除け"],
        "dumortierite": ["仕事運", "創造性", "人間関係"],
        "hypersthene": ["厄除け", "健康運", "仕事運"],
        "labradorite": ["創造性", "人間関係", "厄除け"],
        "chalcedony": ["人間関係", "健康運", "恋愛運"],
        "fuchsite": ["健康運", "人間関係", "恋愛運"],
        "muscovite": ["創造性", "人間関係"],
        "stichtite": ["恋愛運", "人間関係", "創造性"],
        "vesuvianite": ["恋愛運", "人間関係", "健康運"],
        "purpurite": ["創造性", "仕事運", "厄除け"]
    ]

    static func effects(for stoneID: String) -> [String] {
        stoneEffects[stoneID] ?? []
    }
}

// MARK: - Compatibility Logic

struct CompatibilityResult {
    let score: Int
    let label: String
    let labelEn: String
    let description: String
    let descriptionEn: String
    let color: Color

    static func calculate(stone1: Gemstone, stone2: Gemstone) -> CompatibilityResult {
        var score = 50

        // Same mineral group bonus
        let mineralGroup1 = mineralGroup(for: stone1)
        let mineralGroup2 = mineralGroup(for: stone2)
        if mineralGroup1 == mineralGroup2 {
            score += 20
        }

        // Complementary colors
        let colorCompat = colorCompatibility(stone1.hueCenter, stone2.hueCenter)
        score += colorCompat

        // Similar hardness = practical compatibility
        let h1 = parseHardness(stone1.hardness)
        let h2 = parseHardness(stone2.hardness)
        let hardnessDiff = abs(h1 - h2)
        if hardnessDiff < 0.5 {
            score += 15
        } else if hardnessDiff < 1.5 {
            score += 8
        } else if hardnessDiff > 3 {
            score -= 10
        }

        // Shared effects bonus
        let effects1 = GemstoneDatabase.effects(for: stone1.id)
        let effects2 = GemstoneDatabase.effects(for: stone2.id)
        let sharedEffects = Set(effects1).intersection(Set(effects2))
        score += min(sharedEffects.count * 5, 15)

        score = max(0, min(100, score))
        return result(for: score)
    }

    private static func mineralGroup(for stone: Gemstone) -> String {
        let quartz = ["amethyst", "citrine", "rose-quartz", "rock-crystal", "smoky-quartz", "tiger-eye", "agate", "onyx", "jasper", "chalcedony"]
        let beryl = ["emerald", "aquamarine", "alexandrite", "goshenite", "heliodor", "red-beryl"]
        let corundum = ["ruby", "sapphire"]
        let garnetGroup = ["garnet", "almandine-garnet", "garnet-tsavorite", "garnet-spessartine", "garnet-demantoid"]
        let feldspar = ["moonstone", "labradorite", "sunstone", "rainbow-moonstone"]
        let tourmalineGroup = ["tourmaline", "pink-tourmaline"]
        let jade = ["jadeite", "nephrite"]

        if quartz.contains(stone.id) { return "quartz" }
        if beryl.contains(stone.id) { return "beryl" }
        if corundum.contains(stone.id) { return "corundum" }
        if garnetGroup.contains(stone.id) { return "garnet" }
        if feldspar.contains(stone.id) { return "feldspar" }
        if tourmalineGroup.contains(stone.id) { return "tourmaline" }
        if jade.contains(stone.id) { return "jade" }
        return stone.id
    }

    private static func colorCompatibility(_ hue1: Double, _ hue2: Double) -> Int {
        var diff = abs(hue1 - hue2)
        if diff > 180 { diff = 360 - diff }
        // Complementary ~180 degrees apart
        if diff > 160 && diff < 200 { return 15 }
        // Analogous ~30 degrees
        if diff < 30 { return 10 }
        // Triadic ~120 degrees
        if diff > 100 && diff < 140 { return 8 }
        return 0
    }

    private static func parseHardness(_ hardness: String) -> Double {
        let parts = hardness.components(separatedBy: "〜")
        let values = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if values.count == 2 { return (values[0] + values[1]) / 2 }
        return values.first ?? 6.0
    }

    private static func result(for score: Int) -> CompatibilityResult {
        switch score {
        case 85...100:
            return CompatibilityResult(score: score, label: "最高の相性", labelEn: "Perfect Match",
                description: "この2つの石は非常によく調和します。同じ性質を持ち、お互いのエネルギーを高め合います。",
                descriptionEn: "These two stones harmonize beautifully, sharing qualities that amplify each other's energy.",
                color: Color(red: 0.18, green: 0.49, blue: 0.39))
        case 70..<85:
            return CompatibilityResult(score: score, label: "相性が良い", labelEn: "Good Compatibility",
                description: "バランスの良い組み合わせです。日常使いのアクセサリーにも向いています。",
                descriptionEn: "A well-balanced pair. Well-suited for everyday accessories.",
                color: Color(red: 0.18, green: 0.62, blue: 0.38))
        case 55..<70:
            return CompatibilityResult(score: score, label: "普通", labelEn: "Neutral",
                description: "可もなく不可もない組み合わせ。個人の好みで選べます。",
                descriptionEn: "A neutral combination. Suitable based on personal preference.",
                color: Color(red: 0.82, green: 0.55, blue: 0.16))
        case 40..<55:
            return CompatibilityResult(score: score, label: "注意が必要", labelEn: "Use with Care",
                description: "硬さや特性が異なります。一緒に収納する場合は傷に注意してください。",
                descriptionEn: "Hardness and properties differ. Take care to avoid scratches when storing together.",
                color: Color(red: 0.70, green: 0.40, blue: 0.10))
        default:
            return CompatibilityResult(score: score, label: "相性が弱い", labelEn: "Low Compatibility",
                description: "性質が異なるため、実用面での組み合わせには工夫が必要です。",
                descriptionEn: "Their differing properties require extra care when combined.",
                color: Color(red: 0.49, green: 0.14, blue: 0.20))
        }
    }
}

// MARK: - Collection Item

struct CollectionItem: Identifiable, Codable {
    let id: UUID
    var gemstoneID: String
    var notes: String
    var purchaseDate: Date?
    var purchasePrice: Double?
    var currency: String

    init(id: UUID = UUID(), gemstoneID: String, notes: String = "", purchaseDate: Date? = nil, purchasePrice: Double? = nil, currency: String = "JPY") {
        self.id = id
        self.gemstoneID = gemstoneID
        self.notes = notes
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.currency = currency
    }
}

// MARK: - Localization helper

func isEnglish() -> Bool {
    let lang = Locale.preferredLanguages.first ?? "ja"
    return lang.hasPrefix("en")
}
