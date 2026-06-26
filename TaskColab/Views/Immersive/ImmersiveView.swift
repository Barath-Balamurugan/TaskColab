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
    @State private var leftPalmSphere: ModelEntity?
    @State private var rightPalmSphere: ModelEntity?
    @State private var leftHandJointSpheres: [HandSkeleton.JointName: ModelEntity] = [:]
    @State private var rightHandJointSpheres: [HandSkeleton.JointName: ModelEntity] = [:]
    @StateObject private var wbStore = WhiteboardStore()
    @State private var lastSlimeVRPoseLogDate = Date.distantPast
    
    @Environment(\.immersiveSpaceDisplacement) private var spaceDisplacement  // meters

    private let whiteboardPosition = SIMD3<Float>(0, 1.2, 0.25)
    private let whiteboardSizeMeters = CGSize(width: 0.95, height: 0.85)
    private let palmSphereRadius: Float = 0.035
    private let fingertipSphereRadius: Float = 0.012
    private let forearmSphereRadius: Float = 0.02
    private let fingertipJointNames: [HandSkeleton.JointName] = [
        .thumbTip,
        .indexFingerTip,
        .middleFingerTip,
        .ringFingerTip,
        .littleFingerTip
    ]
    private let forearmJointNames: [HandSkeleton.JointName] = [
        .forearmWrist,
        .forearmArm
    ]

    var body: some View {
        RealityView { content, attachments in
            let cubeEntity = ModelEntity(
                mesh: .generateBox(size: 0.15),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            
            cubeEntity.position = SIMD3<Float>(0, 0, 0)
            
            content.add(cubeEntity)
            
            cube = cubeEntity

            let leftSphere = ModelEntity(
                mesh: .generateSphere(radius: palmSphereRadius),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            )
            leftSphere.isEnabled = false
            content.add(leftSphere)
            leftPalmSphere = leftSphere

            let rightSphere = ModelEntity(
                mesh: .generateSphere(radius: palmSphereRadius),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            rightSphere.isEnabled = false
            content.add(rightSphere)
            rightPalmSphere = rightSphere

            var leftJointMarkers: [HandSkeleton.JointName: ModelEntity] = [:]
            var rightJointMarkers: [HandSkeleton.JointName: ModelEntity] = [:]

            for jointName in fingertipJointNames + forearmJointNames {
                let radius = fingertipJointNames.contains(jointName)
                    ? fingertipSphereRadius
                    : forearmSphereRadius

                let leftMarker = ModelEntity(
                    mesh: .generateSphere(radius: radius),
                    materials: [SimpleMaterial(color: .green, isMetallic: false)]
                )
                leftMarker.isEnabled = false
                content.add(leftMarker)
                leftJointMarkers[jointName] = leftMarker

                let rightMarker = ModelEntity(
                    mesh: .generateSphere(radius: radius),
                    materials: [SimpleMaterial(color: .orange, isMetallic: false)]
                )
                rightMarker.isEnabled = false
                content.add(rightMarker)
                rightJointMarkers[jointName] = rightMarker
            }

            leftHandJointSpheres = leftJointMarkers
            rightHandJointSpheres = rightJointMarkers

            if appModel.isWhiteboardVisible,
               let whiteboard = attachments.entity(for: "immersive-whiteboard") {
                whiteboard.setTransformMatrix(whiteboardWorldTransform, relativeTo: nil)
                content.add(whiteboard)
            }
            
            Task{
                let session = ARKitSession()
                let tracking = WorldTrackingProvider()
                let handTracking = HandTrackingProvider.isSupported ? HandTrackingProvider() : nil
                var isHandTrackingRunning = false

                if let handTracking {
                    let authorization = await session.requestAuthorization(for: [.worldSensing, .handTracking])
                    if authorization[.handTracking] == .allowed {
                        try await session.run([tracking, handTracking])
                        isHandTrackingRunning = true
                    } else {
                        print("Hand tracking authorization was not granted.")
                        try await session.run([tracking])
                    }
                } else {
                    print("Hand tracking is not supported on this device.")
                    try await session.run([tracking])
                }
                
                while true {
                    if let cube = cube {
                        let timestamp = CACurrentMediaTime()

                        // Get cube world position
                        let cubeWorldPos = cube.position(relativeTo: nil)
                        appModel.anchorPosition = cubeWorldPos
                        
                        // Get device (head) position from ARKit
                        if let deviceAnchor = tracking.queryDeviceAnchor(atTimestamp: timestamp) {
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

                        if isHandTrackingRunning, let handTracking {
                            let hands = handTracking.handAnchors(at: timestamp)
                            updatePalmSphere(leftPalmSphere, from: hands.leftHand)
                            updatePalmSphere(rightPalmSphere, from: hands.rightHand)
                            updateJointSpheres(leftHandJointSpheres, from: hands.leftHand)
                            updateJointSpheres(rightHandJointSpheres, from: hands.rightHand)
                            sendHandPointsToUnity(from: hands.leftHand, chirality: .left)
                            sendHandPointsToUnity(from: hands.rightHand, chirality: .right)
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

    func updatePalmSphere(_ sphere: ModelEntity?, from handAnchor: HandAnchor?) {
        guard let sphere else { return }

        guard let palmPosition = estimatedPalmPosition(from: handAnchor) else {
            sphere.isEnabled = false
            return
        }

        sphere.position = palmPosition
        sphere.isEnabled = true
    }

    func updateJointSpheres(
        _ spheres: [HandSkeleton.JointName: ModelEntity],
        from handAnchor: HandAnchor?
    ) {
        guard handAnchor?.isTracked == true else {
            spheres.values.forEach { $0.isEnabled = false }
            return
        }

        for (jointName, sphere) in spheres {
            guard let position = jointPosition(jointName, from: handAnchor) else {
                sphere.isEnabled = false
                continue
            }

            sphere.position = position
            sphere.isEnabled = true
        }
    }

    func estimatedPalmPosition(from handAnchor: HandAnchor?) -> SIMD3<Float>? {
        guard let wristPosition = jointPosition(.wrist, from: handAnchor),
              let middleKnucklePosition = jointPosition(.middleFingerKnuckle, from: handAnchor) else {
            return nil
        }

        return (wristPosition + middleKnucklePosition) / 2
    }

    func jointPosition(
        _ jointName: HandSkeleton.JointName,
        from handAnchor: HandAnchor?
    ) -> SIMD3<Float>? {
        jointTransform(jointName, from: handAnchor)?.columns.3.xyz
    }

    func jointTransform(
        _ jointName: HandSkeleton.JointName,
        from handAnchor: HandAnchor?
    ) -> simd_float4x4? {
        guard let handAnchor,
              handAnchor.isTracked,
              let skeleton = handAnchor.handSkeleton else {
            return nil
        }

        let joint = skeleton.joint(jointName)
        guard joint.isTracked else { return nil }

        return handAnchor.originFromAnchorTransform * joint.anchorFromJointTransform
    }

    // Payload: user ID, then [tracked, x, y, z] for palm, five fingertips, and two forearm joints.
    func sendHandPointsToUnity(
        from handAnchor: HandAnchor?,
        chirality: HandAnchor.Chirality
    ) {
        guard appModel.isIpEntered else { return }

        let positions = [estimatedPalmPosition(from: handAnchor)]
            + fingertipJointNames.map { jointPosition($0, from: handAnchor) }
            + forearmJointNames.map { jointPosition($0, from: handAnchor) }

        var values: [any OSCValue] = [appModel.userID]
        for position in positions {
            guard let position else {
                values.append(Float(0))
                values.append(Float(0))
                values.append(Float(0))
                values.append(Float(0))
                continue
            }

            let unityPosition = appModel.oscPosition(fromRealityKit: position)
            values.append(Float(1))
            values.append(unityPosition.x)
            values.append(unityPosition.y)
            values.append(unityPosition.z)
        }

        let side = chirality == .left ? "left" : "right"
        oscManager.send(
            .message("/tracking/hand/\(side)/points", values: values),
            to: appModel.ipAddress,
            port: appModel.portNumber
        )
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
    let m = simd_float3x3(q)

    let m13 = m.columns.2.x
    let m21 = m.columns.0.y
    let m22 = m.columns.1.y
    let m23 = m.columns.2.y
    let m33 = m.columns.2.z

    // Y-X-Z keeps headset yaw continuous through 180 degrees.
    let pitch = asin(max(-1, min(1, -m23)))
    let yaw: Float
    let roll: Float

    if abs(m23) < 0.999_999 {
        yaw = atan2(m13, m33)
        roll = atan2(m21, m22)
    } else {
        yaw = atan2(-m.columns.0.z, m.columns.0.x)
        roll = 0
    }

    return SIMD3<Float>(pitch, yaw, roll)
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
