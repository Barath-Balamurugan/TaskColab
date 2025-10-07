//
//  WhiteBoardDataStruct.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 22/08/25.
//

import Foundation
import SwiftUI

public struct WBPointN: Codable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
}

public enum WBMessageType: String, Codable, Sendable {
    case begin       // id, width
    case append      // id, points
    case end         // id
    case remove      // id
    case clear       // (none)
    case snapshot    // full board sync: strokes payload
}

// One message type for the messenger.
//public struct WBMessage: Codable, Sendable {
//    public var type: WBMessageType
//    public var id: UUID?
//    public var points: [WBPointN]?
//    public var width: CGFloat?
//    public var strokesSnapshot: [WBStroke]? // used only for .snapshot
//}

// A stroke model you can also reuse locally.
public struct WBStroke: Codable, Sendable, Identifiable {
    public var id: UUID
    public var width: CGFloat
    public var points: [WBPointN]
    var color: WBColorN? = nil
}

struct WBMessage: Codable {
    enum Kind: String, Codable { case begin, append, end, remove, clear, snapshot }
    var type: Kind
    var id: UUID?
    var points: [WBPointN]?
    var width: CGFloat?
    var color: WBColorN? = nil     // NEW, optional
    var strokesSnapshot: [WBStroke]?
}
