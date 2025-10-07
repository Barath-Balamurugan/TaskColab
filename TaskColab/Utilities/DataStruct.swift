//
//  DataStruct.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import Foundation
import SwiftUI

struct ParticipantData: Codable, Sendable {
    let id: UUID
    let position: SIMD3<Float>
}


struct RGBAColor: Codable, Sendable {
    var r: Double; var g: Double; var b: Double; var a: Double
    init(_ color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r); self.g = Double(g); self.b = Double(b); self.a = Double(a)
    }
    var color: Color { Color(red: r, green: g, blue: b).opacity(a) }
}

struct Stroke: Identifiable, Codable, Sendable {
    var id = UUID()
    var points: [CGPoint] = []
    var color: RGBAColor = RGBAColor(.white)
    var lineWidth: CGFloat = 6
}

struct StrokeMessage: Codable, Sendable {
    var id: UUID
    var normalizedPoints: [CGPoint]   // each in [0,1] relative to the sender’s canvas size
    var color: RGBAColor
    var lineWidth: CGFloat
    var isFinal: Bool
}

enum WhiteboardControl: String, Codable, Sendable {
    case clear
}
