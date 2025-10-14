//
//  AppModel.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState: ImmersiveSpaceState = .closed
    
    var userPosition: SIMD3<Float> = .zero
    var anchorPosition: SIMD3<Float> = .zero
    var relativePosition: SIMD3<Float> = .zero
    
    var drawingPoints: [SIMD3<Float>] = []
    var isDrawing: Bool = false
    
    var userID: String = ""
    var ipAddress: String = ""
    var portNumber: UInt16 = 9000
    
    var selectedDay: Day = .day1
    
    var isIpEntered: Bool {
        !ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isImmersed: Bool = false
    
    var userOrdinal: Int {
        let digits = userID.filter(\.isNumber)
        if let n2 = Int(digits.suffix(2)), n2 > 0 { return n2 }   // "3001" -> 1, "3012" -> 12
        if let n1 = Int(digits.suffix(1))       { return n1 }     // fallback
        return 1
    }
}
