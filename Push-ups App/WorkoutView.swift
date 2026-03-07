//
//  WorkoutView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI

// MARK: - TempoVisualizerView

struct TempoVisualizerView: View {

    let workoutType: WorkoutType
    @ObservedObject var detector: PushUpDetector

    private let dotSize: CGFloat = 47

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                drawGrid(ctx: ctx, size: size)
                let dotY = dotYPosition(in: size)
                drawDot(ctx: ctx, size: size, dotY: dotY)
            }
            .clipShape(Circle())
        }
    }

    // MARK: - Drawing

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
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

    private func drawDot(ctx: GraphicsContext, size: CGSize, dotY: CGFloat) {
        let dotX = size.width / 2
        let dotRect = CGRect(
            x: dotX - dotSize / 2,
            y: dotY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        ctx.fill(Path(ellipseIn: dotRect), with: .color(.black))

        let phase = detector.currentPhase
        let label = phase == .down ? "Down" : "Top"
        ctx.draw(
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.4)),
            at: CGPoint(x: dotX, y: dotY + dotSize / 2 + 12)
        )
    }

    private func dotYPosition(in size: CGSize) -> CGFloat {
        let progress = CGFloat(detector.getCurrentProgress())
        let margin: CGFloat = dotSize
        return margin + progress * (size.height - margin * 2)
    }
}
