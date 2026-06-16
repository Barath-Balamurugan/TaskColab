//
//  AppModel.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI

enum OSCOutputMode: String, CaseIterable, Identifiable, Codable {
    case unity = "Unity"
    case slimeVR = "SlimeVR"

    var id: String { rawValue }
}

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    private enum DefaultsKey {
        static let userID = "setup.userId"
        static let unityIPAddress = "setup.ipAddress"
        static let unityPort = "setup.port"
        static let oscOutputMode = "setup.oscOutputMode"
        static let slimeVRIPAddress = "setup.slimeVRIpAddress"
        static let slimeVRPort = "setup.slimeVRPort"
    }

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
    var oscOutputMode: OSCOutputMode = .unity
    var slimeVRIPAddress: String = ""
    var slimeVRPortNumber: UInt16 = 9001
    
    var selectedDay: Day = .day1
    
    var isIpEntered: Bool {
        !ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isImmersed: Bool = false
    var isWhiteboardVisible: Bool = false
    
    var userOrdinal: Int {
        let digits = userID.filter(\.isNumber)
        if let n2 = Int(digits.suffix(2)), n2 > 0 { return n2 }   // "3001" -> 1, "3012" -> 12
        if let n1 = Int(digits.suffix(1))       { return n1 }     // fallback
        return 1
    }

    init() {
        loadSavedSetup()
    }

    var headPoseHost: String {
        ipAddress
    }

    var headPosePort: UInt16 {
        slimeVRPortNumber
    }

    func loadSavedSetup() {
        let defaults = UserDefaults.standard
        userID = defaults.string(forKey: DefaultsKey.userID) ?? ""
        ipAddress = defaults.string(forKey: DefaultsKey.unityIPAddress) ?? ""
        portNumber = Self.portValue(from: defaults.string(forKey: DefaultsKey.unityPort), defaultValue: 9000)
        oscOutputMode = OSCOutputMode(rawValue: defaults.string(forKey: DefaultsKey.oscOutputMode) ?? "") ?? .unity
        slimeVRIPAddress = defaults.string(forKey: DefaultsKey.slimeVRIPAddress) ?? ipAddress
        let savedSlimeVRPort = defaults.string(forKey: DefaultsKey.slimeVRPort)
        if savedSlimeVRPort == nil || savedSlimeVRPort == "39539" || savedSlimeVRPort == "9002" {
            slimeVRPortNumber = 9001
            defaults.set("9001", forKey: DefaultsKey.slimeVRPort)
        } else {
            slimeVRPortNumber = Self.portValue(from: savedSlimeVRPort, defaultValue: 9001)
        }
    }

    func updateSetup(
        userID: String? = nil,
        unityIPAddress: String? = nil,
        unityPort: UInt16? = nil,
        outputMode: OSCOutputMode? = nil,
        slimeVRIPAddress: String? = nil,
        slimeVRPort: UInt16? = nil
    ) {
        let defaults = UserDefaults.standard

        if let userID {
            self.userID = userID
            defaults.set(userID, forKey: DefaultsKey.userID)
        }
        if let unityIPAddress {
            self.ipAddress = unityIPAddress
            self.slimeVRIPAddress = unityIPAddress
            defaults.set(unityIPAddress, forKey: DefaultsKey.unityIPAddress)
            defaults.set(unityIPAddress, forKey: DefaultsKey.slimeVRIPAddress)
        }
        if let unityPort {
            self.portNumber = unityPort
            defaults.set(String(unityPort), forKey: DefaultsKey.unityPort)
        }
        if let outputMode {
            self.oscOutputMode = outputMode
            defaults.set(outputMode.rawValue, forKey: DefaultsKey.oscOutputMode)
        }
        if let slimeVRIPAddress {
            self.slimeVRIPAddress = slimeVRIPAddress
            defaults.set(slimeVRIPAddress, forKey: DefaultsKey.slimeVRIPAddress)
        }
        if let slimeVRPort {
            self.slimeVRPortNumber = slimeVRPort
            defaults.set(String(slimeVRPort), forKey: DefaultsKey.slimeVRPort)
        }
    }

    func oscPosition(fromRealityKit position: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(position.x, position.y, -position.z)
    }

    func oscRotationDegrees(fromRealityKit radians: SIMD3<Float>) -> SIMD3<Float> {
        let degrees = radians * (180 / Float.pi)
        return SIMD3<Float>(degrees.x, degrees.y, -degrees.z)
    }

    private static func portValue(from text: String?, defaultValue: UInt16) -> UInt16 {
        guard let text,
              let intValue = Int(text),
              (1...65535).contains(intValue) else {
            return defaultValue
        }
        return UInt16(intValue)
    }
}
