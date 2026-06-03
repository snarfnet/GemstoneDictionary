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

        // Saturation: stones typically have noticeable color (unless clear/white)
        // Very low saturation = skin, paper, walls
        if m.saturation > 20 {
            score += min(25, m.saturation * 0.5)
        } else if m.saturation > 10 {
            score += 8
        }

        // Coverage: a stone should occupy a defined area, not fill the entire frame uniformly
        // Very low = no distinct object, very high = uniform surface (wall, floor)
        if m.coverageScore >= 15 && m.coverageScore <= 85 {
            score += 25
        } else if m.coverageScore > 85 {
            score += 5  // Likely a uniform surface, not a stone
        } else {
            score += 8
        }

        // Brightness: stones are rarely pitch black or blown out white
        if m.brightness > 15 && m.brightness < 85 {
            score += 20
        } else {
            score += 5
        }

        // Clarity: some translucency is a strong gemstone indicator
        if m.clarityScore > 40 {
            score += 15
        } else {
            score += 5
        }

        // Color consistency: stones have focused hue, not a random mix
        // The level score already captures color quality
        if m.levelScore > 40 {
            score += 15
        } else {
            score += 5
        }

        return Int(min(100, max(0, round(score))))
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
