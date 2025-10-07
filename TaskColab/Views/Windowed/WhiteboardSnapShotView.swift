//
//  WhiteboardSnapShotView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 07/10/25.
//

import SwiftUI
internal import OSCKitCore
import simd
import Photos

struct WhiteboardSnapshotView: View {
    let backgroundName: String
    let size: CGSize
    let strokes: [StrokeLocal]
    let inProgress: [UUID: StrokeLocal]

    var body: some View {
        ZStack {
            Image(backgroundName)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .overlay(Color.white.opacity(0.06))
                .clipped()

            Canvas { ctx, _ in
                for s in strokes { Self.drawStroke(s, in: &ctx) }
                for s in inProgress.values { Self.drawStroke(s, in: &ctx) }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: size.width, height: size.height)
    }

    static func drawStroke(_ stroke: StrokeLocal, in ctx: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        var path = Path()
        path.addLines(stroke.points)
        ctx.stroke(
            path,
            with: .color(stroke.color),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }
}
