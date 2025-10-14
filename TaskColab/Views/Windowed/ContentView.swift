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
    
    @State private var selectedDay: Day = .day1
    @State private var selectedUserId: Int = 1

    
    var body: some View {
        NavigationStack {
            VStack() {
                
                Text("Moon Reader")
                    .font(.extraLargeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                
//                Label(appModel.isImmersed ? "Immersive: ON" : "Immersive: OFF", systemImage: appModel.isImmersed ? "cube.inside.fill" : "cube.inside.empty")
                
                Spacer()
                
                Section() {
                    // Horizontal radios (scrolls if it gets tight)
                    HStack(spacing: 100) {
                        ForEach(Day.allCases) { day in
                            RadioButton(
                                isSelected: selectedDay == day,
                                title: day.title
                            ) { selectedDay = day }
                        }
                    }
                    .padding(.vertical, 4)
                    
                }
                
                Spacer()
                
                HStack(spacing: 18) {
                    Button {
                        Task {
                            if appModel.isImmersed {
                                // Close first, then flip the flag
                                await closeSpace()
                                appModel.isImmersed = false
                            } else {
                                // Open first, then flip the flag
                                await openSpace()
                                appModel.isImmersed = true
                            }
                        }
                    } label: {
                        Label(appModel.isImmersed ? "Close Immersive Space" : "Open Immersive Space",
                              systemImage: appModel.isImmersed ? "xmark.circle.fill" : "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Open Whiteboard") {      // ← add this
                        showWhiteboard = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    SharePlayButton("SharePlay", activity: ColabGroupActivity())
                        .padding(.vertical, 20)
                }
                
                Spacer()
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
            .navigationTitle("")
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
