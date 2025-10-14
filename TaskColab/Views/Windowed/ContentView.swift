//
//  ContentView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI
import RealityKit

enum Route: Hashable {
    case settings
}

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    
    @StateObject private var wbStore = WhiteboardStore()
    
    @State private var showWhiteboard = false
    @StateObject private var recorder = AudioRecorder()
    
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack() {
                
                Text("Moon Reader")
                    .font(.extraLargeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Section() {
                    // Horizontal radios (scrolls if it gets tight)
                    HStack(spacing: 100) {
                        ForEach(Day.allCases) { day in
                            RadioButton(
                                isSelected: appModel.selectedDay == day,
                                title: day.title
                            ) { appModel.selectedDay = day }
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
                    
                    Button("Open Whiteboard") {      // ← add this
                        openWindow(id: "personal-panel")
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
            .navigationTitle("Home")
            .toolbar {
                // Optional gear to re-open settings later
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(Route.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView ()
                        .environment(appModel)
                }
            }
            .task {
                // Auto-push Settings only if not completed
                if !hasCompletedSetup {
                    // tiny delay to ensure the stack is ready before pushing
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    path.append(Route.settings)
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
