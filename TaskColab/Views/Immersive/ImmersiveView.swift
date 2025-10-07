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
    @State var oscManager: OSCManager
    
    @State private var deviceTransform: simd_float4x4 = .init()
    @State private var cube: ModelEntity?
    
    @Environment(\.immersiveSpaceDisplacement) private var spaceDisplacement  // meters

    var body: some View {
        RealityView{ content in
            let cubeEntity = ModelEntity(
                mesh: .generateBox(size: 0.15),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            
            cubeEntity.position = SIMD3<Float>(0, 0, 0)
            
            content.add(cubeEntity)
            
            cube = cubeEntity
            
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
                            sendPosition(deviceTransform.columns.3.xyz)
                            let euler_angle = yawPitchRoll(from: rot_q)
//                            sendOrientation(euler_angle)
                        }
                    }
                    try await Task.sleep(nanoseconds: 33_000_000) // ~30 fps
                }
            }
        }
    }
    
    func sendPosition(_ pos: SIMD3<Float>) {
        oscManager.send(
            .message("/device/position", values: [pos.x, pos.y, -pos.z]),
            to: "\(appModel.ipAddress)", // destination IP address or hostname
            port: appModel.portNumber // standard OSC port but can be changed
        )
        print(appModel.ipAddress)
//        print("Sent position OSC message")
    }
    
    func sendOrientation(_ rot: SIMD3<Float>){
//        let angles: [Float] = [rot_q.imag.x, rot_q.imag.y, rot_q.imag.z, rot_q.real]
        oscManager.send(
            .message("/device/rotation", values: [(-rot.y * 180.0 / .pi), (-rot.x * 180.0 / .pi), (rot.z * 180.0 / .pi)]),
            to: "\(appModel.ipAddress)", // destination IP address or hostname
            port: appModel.portNumber // standard OSC port but can be changed
        )
//        print("Sent Orientation OSC message")
    }
}

func yawPitchRoll(from qIn: simd_quatf) -> SIMD3<Float> {
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

    return SIMD3<Float>(yaw, pitch, roll)
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
