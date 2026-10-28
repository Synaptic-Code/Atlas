import SwiftUI
import AtlasCore

/// A compact, dependency-free function plotter drawn with `Canvas`.
struct FunctionPlot: View {
    let sample: (Double) -> Double
    let domain: ClosedRange<Double>
    var markers: [PlotMarker] = []
    var shade: ClosedRange<Double>?
    var accent: Color = Theme.accent

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .background(Color.primary.opacity(0.035), in: Theme.cardShape(16))
        .clipShape(Theme.cardShape(16))
        .overlay {
            Theme.cardShape(16).strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 60, size.height > 60 else { return }

        let inset: CGFloat = 16
        let plotRect = CGRect(
            x: inset,
            y: inset,
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2)
        )

        guard domain.upperBound > domain.lowerBound else { return }

        let sampleCount = 320
        var values: [Double] = []
        values.reserveCapacity(sampleCount + 1)
        for index in 0...sampleCount {
            let x = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(index) / Double(sampleCount)
            let y = sample(x)
            if y.isFinite { values.append(y) }
        }

        guard !values.isEmpty else {
            drawEmpty("No real values in this range", in: &context, rect: plotRect)
            return
        }

        // Percentiles keep asymptotes from crushing the interesting part of the curve.
        let sorted = values.sorted()
        var low = sorted[max(0, Int(Double(sorted.count - 1) * 0.01))]
        var high = sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.99))]

        if high - low < 1e-9 {
            let padding = max(1, abs(high) * 0.5)
            low -= padding
            high += padding
        }
        let verticalPadding = (high - low) * 0.14
        low -= verticalPadding
        high += verticalPadding
        guard low.isFinite, high.isFinite, high > low else { return }

        func xPosition(_ x: Double) -> CGFloat {
            let fraction = (x - domain.lowerBound) / (domain.upperBound - domain.lowerBound)
            return plotRect.minX + CGFloat(fraction) * plotRect.width
        }

        func yPosition(_ y: Double) -> CGFloat {
            let fraction = (y - low) / (high - low)
            return plotRect.maxY - CGFloat(fraction) * plotRect.height
        }

        drawGrid(in: &context, rect: plotRect, low: low, high: high, xPosition: xPosition, yPosition: yPosition)

        var plotContext = context
        plotContext.clip(to: Path(plotRect))

        // Shaded integral region
        if let shade {
            let start = max(shade.lowerBound, domain.lowerBound)
            let end = min(shade.upperBound, domain.upperBound)
            if start < end {
                let baseline = min(max(yPosition(0), plotRect.minY), plotRect.maxY)
                var area = Path()
                area.move(to: CGPoint(x: xPosition(start), y: baseline))

                var started = false
                for index in 0...240 {
                    let x = start + (end - start) * Double(index) / 240
                    let y = sample(x)
                    guard y.isFinite else { continue }
                    let point = CGPoint(x: xPosition(x), y: yPosition(y))
                    if started {
                        area.addLine(to: point)
                    } else {
                        area.move(to: point)
                        started = true
                    }
                }
                area.addLine(to: CGPoint(x: xPosition(end), y: baseline))
                area.closeSubpath()

                plotContext.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [accent.opacity(0.40), accent.opacity(0.06)]),
                        startPoint: CGPoint(x: 0, y: plotRect.minY),
                        endPoint: CGPoint(x: 0, y: plotRect.maxY)
                    )
                )
            }
        }

        // Curve
        let discontinuityThreshold = (high - low) * 0.85
        var curve = Path()
        var segmentOpen = false
        var previousY: Double?

        for index in 0...sampleCount {
            let x = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(index) / Double(sampleCount)
            let y = sample(x)

            guard y.isFinite else {
                segmentOpen = false
                previousY = nil
                continue
            }

            if let previousY, abs(y - previousY) > discontinuityThreshold {
                segmentOpen = false
            }

            let point = CGPoint(x: xPosition(x), y: yPosition(y))
            if segmentOpen {
                curve.addLine(to: point)
            } else {
                curve.move(to: point)
                segmentOpen = true
            }
            previousY = y
        }

        plotContext.stroke(
            curve,
            with: .linearGradient(
                Gradient(colors: [accent, Theme.violet]),
                startPoint: CGPoint(x: 0, y: plotRect.minY),
                endPoint: CGPoint(x: 0, y: plotRect.maxY)
            ),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )

        // Markers
        for marker in markers {
            switch marker {
            case .vertical(let x):
                guard domain.contains(x) else { continue }
                var line = Path()
                line.move(to: CGPoint(x: xPosition(x), y: plotRect.minY))
                line.addLine(to: CGPoint(x: xPosition(x), y: plotRect.maxY))
                plotContext.stroke(
                    line,
                    with: .color(accent.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                )

            case .tangent(let x, let slope):
                guard domain.contains(x) else { continue }
                let y = sample(x)
                guard y.isFinite else { continue }
                let span = (domain.upperBound - domain.lowerBound) * 0.22
                let startX = x - span
                let endX = x + span
                var line = Path()
                line.move(to: CGPoint(x: xPosition(startX), y: yPosition(y + slope * (startX - x))))
                line.addLine(to: CGPoint(x: xPosition(endX), y: yPosition(y + slope * (endX - x))))
                plotContext.stroke(
                    line,
                    with: .color(Theme.gold.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])
                )

            case .dot(let x, let label):
                guard domain.contains(x) else { continue }
                let y = sample(x)
                guard y.isFinite else { continue }
                let point = CGPoint(x: xPosition(x), y: yPosition(y))
                guard point.y >= plotRect.minY - 60, point.y <= plotRect.maxY + 60 else { continue }

                let dotRect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
                plotContext.fill(Path(ellipseIn: dotRect), with: .color(accent))
                plotContext.stroke(
                    Path(ellipseIn: dotRect.insetBy(dx: -1.6, dy: -1.6)),
                    with: .color(.white.opacity(0.9)),
                    lineWidth: 1.4
                )

                if !label.isEmpty {
                    let text = Text(label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    plotContext.draw(text, at: CGPoint(x: point.x, y: point.y - 9), anchor: .bottom)
                }
            }
        }
    }

    private func drawGrid(
        in context: inout GraphicsContext,
        rect: CGRect,
        low: Double,
        high: Double,
        xPosition: (Double) -> CGFloat,
        yPosition: (Double) -> CGFloat
    ) {
        let gridColor = Color.primary.opacity(0.07)
        let axisColor = Color.primary.opacity(0.28)

        for index in 0...6 {
            let fraction = Double(index) / 6
            let x = rect.minX + rect.width * CGFloat(fraction)
            var line = Path()
            line.move(to: CGPoint(x: x, y: rect.minY))
            line.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.8)
        }

        for index in 0...5 {
            let fraction = Double(index) / 5
            let y = rect.minY + rect.height * CGFloat(fraction)
            var line = Path()
            line.move(to: CGPoint(x: rect.minX, y: y))
            line.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.8)
        }

        if low < 0, high > 0 {
            var axis = Path()
            axis.move(to: CGPoint(x: rect.minX, y: yPosition(0)))
            axis.addLine(to: CGPoint(x: rect.maxX, y: yPosition(0)))
            context.stroke(axis, with: .color(axisColor), lineWidth: 1)
        }

        if domain.lowerBound < 0, domain.upperBound > 0 {
            var axis = Path()
            axis.move(to: CGPoint(x: xPosition(0), y: rect.minY))
            axis.addLine(to: CGPoint(x: xPosition(0), y: rect.maxY))
            context.stroke(axis, with: .color(axisColor), lineWidth: 1)
        }

        let lowerLabel = Text(NumberText.string(for: domain.lowerBound))
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(Color.secondary)
        context.draw(lowerLabel, at: CGPoint(x: rect.minX + 2, y: rect.maxY + 2), anchor: .bottomLeading)

        let upperLabel = Text(NumberText.string(for: domain.upperBound))
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(Color.secondary)
        context.draw(upperLabel, at: CGPoint(x: rect.maxX - 2, y: rect.maxY + 2), anchor: .bottomTrailing)
    }

    private func drawEmpty(_ message: String, in context: inout GraphicsContext, rect: CGRect) {
        let text = Text(message)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.secondary)
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }
}
