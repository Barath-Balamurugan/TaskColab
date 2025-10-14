//
//  ContentView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    
    @StateObject private var wbStore = WhiteboardStore()
    
    @State private var showWhiteboard = false
    @StateObject private var recorder = AudioRecorder()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                
                Text("Task Colab")
                    .font(.extraLargeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .padding(20)
                
                Spacer()
                
                HStack{
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                        
                        TextField(
                            "Enter your User ID - (300x)",
                            text: Binding(
                                get: { appModel.userID },
                                set: { appModel.userID = $0 }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(maxWidth: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        
                        TextField(
                            "Enter the IP Address",
                            text: Binding(
                                get: { appModel.ipAddress },
                                set: { appModel.ipAddress = $0 }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(maxWidth: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        
                        TextField(
                            "Enter the Port Number",
                            text: Binding(
                                get: { String(appModel.portNumber) },
                                set: {
                                    let digits = $0.filter(\.isNumber)
                                    if let v = UInt16(digits) { appModel.portNumber = v }
                                }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                //            Text(String(format: "Cube World Position: x: %.2f, y: %.2f, z: %.2f", appModel.anchorPosition.x, appModel.anchorPosition.y, appModel.anchorPosition.z))
                //            Text(String(format: "User World Position: x: %.2f, y: %.2f, z: %.2f", appModel.userPosition.x, appModel.userPosition.y, appModel.userPosition.z))
                //            Text(String(format: "User Relative to Cube: x: %.2f, y: %.2f, z: %.2f", appModel.relativePosition.x, appModel.relativePosition.y, appModel.relativePosition.z))
                
                Label(appModel.isImmersed ? "Immersive: ON" : "Immersive: OFF", systemImage: appModel.isImmersed ? "cube.inside.fill" : "cube.inside.empty")
                
                Group {
                    if recorder.permissionGranted {
                        HStack(spacing: 12) {
                            Button {
                                recorder.toggle()
                            } label: {
                                Label(recorder.isRecording ? "Stop Recording" : "Record Audio",
                                      systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .labelStyle(.titleAndIcon)
                            }
                            //                        .buttonStyle(recorder.isRecording ? .borderedProminent : .bordered)
                            
                            // Elapsed time
                            Text(timeString(recorder.elapsed))
                                .monospacedDigit()
                                .foregroundStyle(recorder.isRecording ? .red : .secondary)
                            
                            // Share last file if exists
                            if let url = recorder.lastRecordingURL {
                                ShareLink(item: url) {
                                    Label("Share Last", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.slash")
                            Text("Microphone access is required to record audio.")
                            Button("Enable") {
                                Task { await recorder.requestPermissionIfNeeded() }
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 18) {
                    Button("Open Immersive Space") {
                        Task { await openSpace() }
                        appModel.isImmersed.toggle()
                    }
                    .disabled(!appModel.isIpEntered || appModel.immersiveSpaceState == .open)
                    
                    Button("Close Immersive Space"){
                        Task{ await closeSpace() }
                        appModel.isImmersed.toggle()
                    }
                    .disabled(appModel.immersiveSpaceState != .open)
                    
                    Button("Open Whiteboard") {      // ← add this
                        showWhiteboard = true
                        //                    Task { await sharePlayManager.send(.init(kind: .openWhiteboard)) }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Open My Personal Window") {
                        openWindow(id: "personal-panel")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                SharePlayButton("SharePlay", activity: ColabGroupActivity())
                    .padding(.vertical, 20)
                
            }
            .padding()
            .sheet(isPresented: $showWhiteboard) {   // ← add this
                WhiteBoardView()
                    .presentationDetents([.medium, .large])
                    .environmentObject(wbStore)
            }
            .onChange(of: sharePlayManager.isSharing) { _, isSharing in
                if isSharing {
                    openWindow(id: "personal-panel")
                }
            }
            .navigationTitle("Colab")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environment(appModel)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
            let s = Int(t.rounded(.towardZero))
            let mm = s / 60
            let ss = s % 60
            return String(format: "%02d:%02d", mm, ss)
        }
    
    private func openSpace() async {
        appModel.immersiveSpaceState = .inTransition
        let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
        switch result {
        case .opened:
            appModel.immersiveSpaceState = .open
        default:
            appModel.immersiveSpaceState = .closed
        }
    }
    
    private func closeSpace() async {
        appModel.immersiveSpaceState = .inTransition
        await dismissImmersiveSpace()
        appModel.immersiveSpaceState = .closed
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
        .environmentObject(SharePlayManager())
}
