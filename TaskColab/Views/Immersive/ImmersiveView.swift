//
//  ImmersiveView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI
import RealityKit
import ARKit
import simd
import Spatial
internal import OSCKitCore

struct ImmersiveView: View {
    
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    @State var oscManager: OSCManager
    
    @State private var deviceTransform: simd_float4x4 = .init()
    @State private var cube: ModelEntity?
    @StateObject private var wbStore = WhiteboardStore()
    @State private var lastSlimeVRPoseLogDate = Date.distantPast
    
    @Environment(\.immersiveSpaceDisplacement) private var spaceDisplacement  // meters

    private let whiteboardPosition = SIMD3<Float>(0, 1.2, 0.25)
    private let whiteboardSizeMeters = CGSize(width: 1.2, height: 0.928)

    var body: some View {
        RealityView { content, attachments in
            let cubeEntity = ModelEntity(
                mesh: .generateBox(size: 0.15),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            
            cubeEntity.position = SIMD3<Float>(0, 0, 0)
            
            content.add(cubeEntity)
            
            cube = cubeEntity

            if appModel.isWhiteboardVisible,
               let whiteboard = attachments.entity(for: "immersive-whiteboard") {
                whiteboard.setTransformMatrix(whiteboardWorldTransform, relativeTo: nil)
                content.add(whiteboard)
            }
            
            Task{
                let session = ARKitSession()
                let tracking = WorldTrackingProvider()
                try await session.run([tracking])
                
                while true {
                    if let cube = cube {
                        // Get cube world position
                        let cubeWorldPos = cube.position(relativeTo: nil)
                        appModel.anchorPosition = cubeWorldPos
                        
                        // Get device (head) position from ARKit
                        if let deviceAnchor = tracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
                            let deviceTransform = deviceAnchor.originFromAnchorTransform
                            let rot_q = simd_normalize(simd_quatf(deviceTransform))
                            let deviceWorldPos = SIMD3<Float>(
                                deviceTransform.columns.3.x,
                                deviceTransform.columns.3.y,
                                deviceTransform.columns.3.z
                            )
                            appModel.userPosition = deviceWorldPos
                            
                            // Calculate user position relative to cube
                            let relativePos = deviceWorldPos - cubeWorldPos
                            appModel.relativePosition = relativePos
                            
//                            print("=== Position Data ===")
//                            print("Cube World Position: X: \(cubeWorldPos.x), Y: \(cubeWorldPos.y), Z: \(cubeWorldPos.z)")
//                            print("User World Position: X: \(deviceWorldPos.x), Y: \(deviceWorldPos.y), Z: \(deviceWorldPos.z)")
//                            print("User Relative to Cube: X: \(relativePos.x), Y: \(relativePos.y), Z: \(relativePos.z)")
//                            print("Distance to Cube: \(length(relativePos)) meters")
//                            print("Device Tranform: \(deviceTransform)")
//                            print("---")
                            let rotationRadians = pitchYawRoll(from: rot_q)
                            sendHeadPose(position: deviceTransform.columns.3.xyz, rotationRadians: rotationRadians)
                        }
                    }
                    try await Task.sleep(nanoseconds: 33_000_000) // ~30 fps
                }
            }
        } update: { content, attachments in
            guard let whiteboard = attachments.entity(for: "immersive-whiteboard") else { return }
            if appModel.isWhiteboardVisible {
                whiteboard.setTransformMatrix(whiteboardWorldTransform, relativeTo: nil)
                if whiteboard.parent == nil {
                    content.add(whiteboard)
                }
            } else {
                whiteboard.removeFromParent()
            }
        } attachments: {
            Attachment(id: "immersive-whiteboard") {
                WhiteBoardView(
                    boardWorldTransform: whiteboardWorldTransform,
                    boardSizeMeters: whiteboardSizeMeters,
                    onClose: {
                        appModel.isWhiteboardVisible = false
                    }
                )
                .frame(width: 1200, height: 1030)
                .environment(appModel)
                .environmentObject(sharePlayManager)
                .environmentObject(wbStore)
            }
        }
        .onAppear {
            Task {
                await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: true)
            }
        }
        .onDisappear {
            Task {
                await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: false)
            }
        }
    }
    
    private var whiteboardWorldTransform: simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(whiteboardPosition.x, whiteboardPosition.y, whiteboardPosition.z, 1)
        return transform
    }

    func sendHeadPose(position: SIMD3<Float>, rotationRadians: SIMD3<Float>) {
        sendSlimeVRPose(position: position, rotationRadians: rotationRadians)
    }

    func sendUnityPosition(_ pos: SIMD3<Float>) {
        let oscPosition = appModel.oscPosition(fromRealityKit: pos)
        oscManager.send(
            .message("/device/position", values: [oscPosition.x, oscPosition.y, oscPosition.z]),
            to: "\(appModel.ipAddress)", // destination IP address or hostname
            port: appModel.portNumber // standard OSC port but can be changed
        )
//        print("Sent position OSC message")
    }
    
    func sendUnityOrientation(_ rot: SIMD3<Float>){
        let oscRotation = appModel.oscRotationDegrees(fromRealityKit: rot)
//        let angles: [Float] = [rot_q.imag.x, rot_q.imag.y, rot_q.imag.z, rot_q.real]
        oscManager.send(
            .message("/device/rotation", values: [oscRotation.x, oscRotation.y, oscRotation.z]),
            to: "\(appModel.ipAddress)", // destination IP address or hostname
            port: appModel.portNumber // standard OSC port but can be changed
        )
//        print("Sent Orientation OSC message")
    }

    func sendSlimeVRPose(position: SIMD3<Float>, rotationRadians: SIMD3<Float>) {
        let oscPosition = appModel.oscPosition(fromRealityKit: position)
        let oscRotation = appModel.oscRotationDegrees(fromRealityKit: rotationRadians)
        let pitch = -oscRotation.x
        let yaw = -oscRotation.y
        let roll = oscRotation.z

        oscManager.send(
            .message(
                "/tracking/vrsystem/head/pose",
                values: [oscPosition.x, oscPosition.y, oscPosition.z, pitch, yaw, roll]
            ),
            to: appModel.ipAddress,
            port: appModel.slimeVRPortNumber
        )

        let now = Date()
        if now.timeIntervalSince(lastSlimeVRPoseLogDate) >= 1 {
            lastSlimeVRPoseLogDate = now
            print("/tracking/vrsystem/head/pose -> \(appModel.ipAddress):\(appModel.slimeVRPortNumber)")
            print("position: \(oscPosition.x) \(oscPosition.y) \(oscPosition.z)")
            print("rotation: \(pitch) \(yaw) \(roll)")
        }
    }
}

func wrap360(_ d: Float) -> Float {
    let m = fmodf(d, 360)
    return m < 0 ? m + 360 : m
}

func pitchYawRoll(from qIn: simd_quatf) -> SIMD3<Float> {
    let q = simd_normalize(qIn)
    let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real

    // pitch (X)
    let sinp = 2*(w*x - y*z)
    let pitch = abs(sinp) >= 1 ? copysign(.pi/2, sinp) : asin(sinp)

    // yaw (Y)
    let siny = 2*(w*y + z*x)
    let yaw  = abs(siny) >= 1 ? copysign(.pi/2, siny) : asin(siny)

    // roll (Z)
    let sinr = 2*(w*z - x*y)
    let cosr = 1 - 2*(z*z + y*y)
    let roll = atan2(sinr, cosr)
    
//    print(yaw, pitch, roll)

    return SIMD3<Float>(pitch, yaw, roll)
//    return SIMD3<Float>(yaw, 0, 0)
}


extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

//#Preview(immersionStyle: .mixed) {
//    ImmersiveView()
//        .environment(AppModel())
//}
