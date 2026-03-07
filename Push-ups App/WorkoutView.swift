//
//  WorkoutView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI
import UIKit

// MARK: - TempoVisualizerView

struct TempoVisualizerView: View {

    let workoutType: WorkoutType
    @ObservedObject var detector: PushUpDetector

    @State private var startTime: Date = Date()
    @State private var lastHapticTime: Date = .distantPast

    private let period: Double = 6.0

    private let totalVisibleMultiplier: Double = 2.0  // 2 × period = 12s visible
    private let nowLineFraction: Double = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            Canvas { ctx, size in
                drawFaintGrid(ctx: ctx, size: size)
                drawWavePath(ctx: ctx, size: size, elapsed: elapsed)
                drawNowLine(ctx: ctx, size: size)

                let targetNormY = waveNormY(elapsed: elapsed)
                let actualNormY = Double(detector.getCurrentProgress())
                let targetY = normToCanvasY(normY: targetNormY, size: size)
                let actualY = normToCanvasY(normY: actualNormY, size: size)
                let nowX = size.width * CGFloat(nowLineFraction)

                drawConnector(ctx: ctx, nowX: nowX, targetY: targetY, actualY: actualY)
                drawTargetMarker(ctx: ctx, nowX: nowX, targetY: targetY)
                drawActualMarker(ctx: ctx, nowX: nowX, actualY: actualY,
                                 targetNormY: targetNormY, actualNormY: actualNormY)
            }
            .clipShape(Circle())
            .onChange(of: timeline.date) { _, newDate in
                let elapsed = newDate.timeIntervalSince(startTime)
                let targetNormY = waveNormY(elapsed: elapsed)
                let actualNormY = Double(detector.getCurrentProgress())
                let deviation = abs(targetNormY - actualNormY)
                if deviation > 0.25 && newDate.timeIntervalSince(lastHapticTime) >= 0.5 {
                    lastHapticTime = newDate
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        .onAppear {
            startTime = Date()
        }
    }

    // MARK: - Wave Math

    private func easeInOutSine(_ t: Double) -> Double {
        -(cos(.pi * t) - 1) / 2
    }

    // Returns position [1.0=top/arms-extended, 0.0=bottom/chest-to-floor]
    private func fourPhasePosition(elapsed: Double) -> Double {
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        if phase < 2.0 {
            return 1.0 - easeInOutSine(phase / 2.0)      // Phase 1: lower 1→0
        } else if phase < 3.0 {
            return 0.0                                     // Phase 2: hold at bottom
        } else if phase < 5.0 {
            return easeInOutSine((phase - 3.0) / 2.0)    // Phase 3: raise 0→1
        } else {
            return 1.0                                     // Phase 4: hold at top
        }
    }

    // Canvas convention: normY 0.0=top of canvas, 1.0=bottom — invert fourPhasePosition
    private func waveNormY(elapsed: Double) -> Double {
        1.0 - fourPhasePosition(elapsed: elapsed)
    }

    private func normToCanvasY(normY: Double, size: CGSize) -> CGFloat {
        let margin: CGFloat = 16
        return margin + CGFloat(normY) * (size.height - 2 * margin)
    }

    // MARK: - Drawing

    private func drawFaintGrid(ctx: GraphicsContext, size: CGSize) {
        let step: CGFloat = 24
        var gridPath = Path()
        var x: CGFloat = 0
        while x <= size.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= size.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        ctx.stroke(gridPath, with: .color(.black.opacity(0.08)), lineWidth: 1)
    }

    private func drawWavePath(ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let totalVisibleDuration = totalVisibleMultiplier * period
        let tLeft = elapsed - nowLineFraction * totalVisibleDuration

        var wavePath = Path()
        var firstPoint = true
        var px: CGFloat = 0
        while px <= size.width {
            let t = tLeft + Double(px / size.width) * totalVisibleDuration
            let normY = waveNormY(elapsed: t)
            let point = CGPoint(x: px, y: normToCanvasY(normY: normY, size: size))
            if firstPoint {
                wavePath.move(to: point)
                firstPoint = false
            } else {
                wavePath.addLine(to: point)
            }
            px += 2
        }

        ctx.stroke(
            wavePath,
            with: .color(.white.opacity(0.55)),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
    }

    private func drawNowLine(ctx: GraphicsContext, size: CGSize) {
        let x = size.width * CGFloat(nowLineFraction)
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        ctx.stroke(path, with: .color(.white.opacity(0.25)), lineWidth: 1)
    }

    private func drawConnector(ctx: GraphicsContext, nowX: CGFloat, targetY: CGFloat, actualY: CGFloat) {
        guard abs(targetY - actualY) > 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: nowX, y: targetY))
        path.addLine(to: CGPoint(x: nowX, y: actualY))
        ctx.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
    }

    private func drawTargetMarker(ctx: GraphicsContext, nowX: CGFloat, targetY: CGFloat) {
        let center = CGPoint(x: nowX, y: targetY)
        let baseRadius: CGFloat = 12

        // Glow rings (outermost first — painter's order)
        let glowRings: [(extra: CGFloat, opacity: Double)] = [
            (12, 0.12),
            (7,  0.22),
            (3,  0.35)
        ]
        for ring in glowRings {
            let r = baseRadius + ring.extra
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(ring.opacity)))
        }

        // Main fill
        let rect = CGRect(x: center.x - baseRadius, y: center.y - baseRadius,
                          width: baseRadius * 2, height: baseRadius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    private func drawActualMarker(ctx: GraphicsContext, nowX: CGFloat, actualY: CGFloat,
                                  targetNormY: Double, actualNormY: Double) {
        let deviation = abs(targetNormY - actualNormY)
        let color: Color = deviation < 0.10 ? .green : deviation < 0.25 ? .yellow : .red

        let radius: CGFloat = 9
        let center = CGPoint(x: nowX, y: actualY)
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))
    }
}
