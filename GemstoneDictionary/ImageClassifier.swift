import CoreGraphics
import UIKit

enum SizeReference: String, CaseIterable, Identifiable {
    case none = "基準なし"
    case tenYen = "10円玉 23.5mm"
    case looseCase = "ルースケース 20mm"
    case ruler = "定規目盛 30mm"

    var id: String { rawValue }

    var millimeters: Double? {
        switch self {
        case .none: return nil
        case .tenYen: return 23.5
        case .looseCase: return 20
        case .ruler: return 30
        }
    }
}

enum ImageClassifier {
    static func classify(_ image: UIImage, reference: SizeReference) -> (metrics: ScanMetrics, candidates: [StoneCandidate]) {
        var metrics = analyze(image, reference: reference)
        metrics.stoneLikelihood = estimateStoneLikelihood(metrics)

        // If unlikely to be a stone, return empty candidates
        guard metrics.isLikelyStone else {
            return (metrics, [])
        }

        let candidates = GemstoneDatabase.stones
            .map { StoneCandidate(gemstone: $0, score: score($0, metrics: metrics)) }
            .sorted { $0.score > $1.score }
            .prefix(5)
        return (metrics, Array(candidates))
    }

    /// Estimates how likely the subject is a gemstone (0-100) based on visual characteristics.
    /// Real gemstones tend to have: moderate-high saturation, distinct hue concentration,
    /// a defined object region (not uniform background), and moderate brightness.
    private static func estimateStoneLikelihood(_ m: ScanMetrics) -> Int {
        var score = 0.0
        var penalties = 0.0

        // 1. Saturation: stones have distinct color. Skin/walls/paper are low saturation.
        if m.saturation > 30 {
            score += 25
        } else if m.saturation > 18 {
            score += 12
        } else {
            penalties += 15  // Very desaturated = unlikely stone
        }

        // 2. Coverage: stone should be a distinct object (20-75% of frame)
        // Too low = no object, too high = uniform surface
        if m.coverageScore >= 20 && m.coverageScore <= 75 {
            score += 25
        } else {
            penalties += 20
        }

        // 3. Brightness: stones are moderate brightness, not extreme
        if m.brightness > 20 && m.brightness < 80 {
            score += 15
        } else {
            penalties += 10
        }

        // 4. Clarity + Level combined: real stones have some color quality
        if m.clarityScore > 50 && m.levelScore > 50 {
            score += 25  // Strong stone indicator
        } else if m.clarityScore > 35 || m.levelScore > 35 {
            score += 10
        }

        // 5. Color variance penalty: if saturation is very uniform and low,
        // it's likely a solid-color non-stone surface
        if m.saturation < 15 && m.brightness > 30 && m.brightness < 70 {
            penalties += 25  // Gray/beige surfaces (desks, skin, walls)
        }

        let result = score - penalties
        return Int(min(100, max(0, round(result))))
    }

    private static func analyze(_ image: UIImage, reference: SizeReference) -> ScanMetrics {
        let width = 180
        let height = 180
        let size = CGSize(width: width, height: height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let didRender = pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            UIGraphicsPushContext(context)
            let imageSize = image.size
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
            UIGraphicsPopContext()
            return true
        }

        guard didRender else {
            return ScanMetrics(hue: 0, saturation: 0, brightness: 0, clarityScore: 0, levelScore: 0, coverageScore: 0, estimatedMillimeters: nil)
        }

        var hueX = 0.0
        var hueY = 0.0
        var saturationTotal = 0.0
        var brightnessTotal = 0.0
        var count = 0.0
        var coloredCount = 0.0
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = CGFloat(pixels[offset]) / 255
                let green = CGFloat(pixels[offset + 1]) / 255
                let blue = CGFloat(pixels[offset + 2]) / 255
                let hsb = hsbFromRGB(red: red, green: green, blue: blue)
                let radians = hsb.hue * .pi / 180
                hueX += cos(radians) * max(hsb.saturation, 1)
                hueY += sin(radians) * max(hsb.saturation, 1)
                saturationTotal += hsb.saturation
                brightnessTotal += hsb.brightness
                count += 1

                if hsb.saturation > 18, hsb.brightness > 15, hsb.brightness < 92 {
                    coloredCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        var hue = atan2(hueY, hueX) * 180 / .pi
        if hue < 0 { hue += 360 }
        let saturation = saturationTotal / max(count, 1)
        let brightness = brightnessTotal / max(count, 1)
        let coverage = coloredCount / max(count, 1)
        let bounding = coloredCount > 0 ? max(Double(maxX - minX) / Double(width), Double(maxY - minY) / Double(height)) : 0
        let clarity = Int(min(100, max(8, brightness * 0.72 + saturation * 0.32)))
        let level = Int(min(100, max(10, Double(clarity) * 0.55 + saturation * 0.45 + coverage * 8)))
        let coverageScore = Int(min(100, max(0, bounding * 100)))
        let estimated = reference.millimeters.map { Int(max(1, round($0 * max(0.45, bounding * 1.8)))) }

        return ScanMetrics(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            clarityScore: clarity,
            levelScore: level,
            coverageScore: coverageScore,
            estimatedMillimeters: estimated
        )
    }

    private static func hsbFromRGB(red: CGFloat, green: CGFloat, blue: CGFloat) -> (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        var hue: CGFloat = 0

        if delta != 0 {
            if maxValue == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }

        let saturation = maxValue == 0 ? 0 : delta / maxValue
        return (Double(hue), Double(saturation * 100), Double(maxValue * 100))
    }

    private static func score(_ stone: Gemstone, metrics: ScanMetrics) -> Int {
        let hueScore: Double
        if stone.hueRange.lowerBound == 0, stone.hueRange.upperBound == 360 {
            hueScore = metrics.saturation < 24 ? 44 : 32
        } else if hueMatches(metrics.hue, range: stone.hueRange) {
            hueScore = 62
        } else {
            let center = hueCenter(stone.hueRange)
            hueScore = max(0, 62 - hueDistance(metrics.hue, center) * 0.75)
        }

        let saturationCenter = (stone.saturationRange.lowerBound + stone.saturationRange.upperBound) / 2
        let saturationScore = max(0, 24 - abs(metrics.saturation - saturationCenter) * 0.26)
        let brightnessBonus = stone.colors.contains("黒") && metrics.brightness < 28 ? 18 : 0
        let mixedBonus = (stone.colors.contains("虹") || stone.colors.contains("多色")) && metrics.saturation > 28 ? 12 : 0
        let clearBonus = (stone.colors.contains("無色") || stone.colors.contains("白")) && metrics.saturation < 20 && metrics.brightness > 45 ? 15 : 0
        let raw = hueScore + saturationScore + Double(brightnessBonus + mixedBonus + clearBonus) + Double(metrics.coverageScore) * 0.08
        return Int(min(99, max(8, round(raw))))
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }

    private static func hueMatches(_ hue: Double, range: ClosedRange<Double>) -> Bool {
        if range.contains(hue) {
            return true
        }
        if range.lowerBound >= 300, hue <= 30 {
            return true
        }
        return false
    }

    private static func hueCenter(_ range: ClosedRange<Double>) -> Double {
        if range.lowerBound >= 300 {
            return ((range.lowerBound + range.upperBound + 360) / 2).truncatingRemainder(dividingBy: 360)
        }
        return (range.lowerBound + range.upperBound) / 2
    }
}
