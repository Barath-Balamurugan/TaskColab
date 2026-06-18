//
//  ContentView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI
import RealityKit
import UIKit

enum Route: Hashable {
    case settings
}

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    
    @StateObject private var recorder = AudioRecorder()
    
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var path = NavigationPath()
    @State private var windowScene: UIWindowScene?
    
    var body: some View {
        NavigationStack(path: $path) {
            content
            .padding()
            .frame(
                width: appModel.isWhiteboardVisible ? 420 : 980,
                height: appModel.isWhiteboardVisible ? 150 : 620
            )
            .background(
                WindowSceneReader { scene in
                    if windowScene !== scene {
                        windowScene = scene
                        requestContentWindowSize(isWhiteboardVisible: appModel.isWhiteboardVisible)
                    }
                }
            )
            .onDisappear {
                if !appModel.isImmersed {
                    dismissWindow(id: "personal-panel")
                }
            }
            .onChange(of: sharePlayManager.isSharing) { _, isSharing in
//                if isSharing {
//                    openWindow(id: "personal-panel")
//                }
            }
            .navigationTitle("")
            .toolbar {
                // Optional gear to re-open settings later
                ToolbarItem(placement: .topBarTrailing) {
                    if !appModel.isWhiteboardVisible {
                        Button {
                            path.append(Route.settings)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
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
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { note in
                guard let disconnectedScene = note.object as? UIScene,
                      disconnectedScene === windowScene else { return }
                guard !appModel.isWhiteboardVisible else { return }
                Task{
                    dismissWindow(id: "personal-panel")
                    await closeSpace()
                    appModel.isImmersed = false
                    appModel.isWhiteboardVisible = false
                    await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: false)
                }
            }
            .onChange(of: appModel.isWhiteboardVisible) { _, isVisible in
                requestContentWindowSize(isWhiteboardVisible: isVisible)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if appModel.isWhiteboardVisible {
            whiteboardControlContent
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Text("Moon Reader")
                .font(.extraLargeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.primary)
                .padding(.top, 8)

            Spacer(minLength: 26)

            ImmersiveCountdownView()

            Spacer(minLength: 24)

            Section {
                HStack(spacing: 62) {
                    ForEach(Day.allCases) { day in
                        RadioButton(
                            isSelected: appModel.selectedDay == day,
                            title: day.title
                        ) { appModel.selectedDay = day }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: 780)
            }

            Spacer(minLength: 34)

            HStack(spacing: 18) {
                Button {
                    Task {
                        await toggleImmersiveSpace()
                    }
                } label: {
                    Label(appModel.isImmersed ? "Close Immersive Space" : "Open Immersive Space",
                          systemImage: appModel.isImmersed ? "xmark.circle.fill" : "sparkles")
                }
                .buttonStyle(.borderedProminent)

                Button(appModel.isWhiteboardVisible ? "Close Whiteboard" : "Open Whiteboard") {
                    Task {
                        await toggleWhiteboard()
                    }
                }
                .buttonStyle(.borderedProminent)

//                    Button {
//                        recorder.toggle()
//                    } label: {
//                        Label(recorder.isRecording ? "Stop Recording" : "Record Mic",
//                              systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .tint(recorder.isRecording ? .red : .accentColor)
//                    .disabled(!recorder.permissionGranted)
//
//                    if let url = recorder.lastRecordingURL, !recorder.isRecording {
//                        ShareLink(item: url) {
//                            Label("Share", systemImage: "square.and.arrow.up")
//                        }
//                    }

                SharePlayButton("SharePlay", activity: ColabGroupActivity())
                    .padding(.vertical, 20)
            }
            .frame(maxWidth: 860)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 28)
        .overlay(alignment: .topLeading) {
            Text("v5.0")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .padding(.leading, 20)
                .padding(.top, 18)
        }
    }

    private var whiteboardControlContent: some View {
        VStack(spacing: 16) {
            Label("Whiteboard Open", systemImage: "square.and.pencil")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    closeWhiteboard()
                } label: {
                    Label("Close Whiteboard", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await toggleImmersiveSpace()
                    }
                } label: {
                    Label("Close Immersive", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func toggleImmersiveSpace() async {
        if appModel.isImmersed {
            await closeSpace()
            appModel.isImmersed = false
            appModel.isWhiteboardVisible = false
            await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: false)
            dismissWindow(id: "personal-panel")
        } else {
            await openSpace()
            appModel.isImmersed = true
            await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: true)
            openWindow(id: "personal-panel")
        }
    }

    private func toggleWhiteboard() async {
        if appModel.isWhiteboardVisible {
            closeWhiteboard()
            return
        }

        if !appModel.isImmersed {
            await openSpace()
            appModel.isImmersed = true
            await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: true)
            openWindow(id: "personal-panel")
        }

        appModel.isWhiteboardVisible = true
    }

    private func closeWhiteboard() {
        appModel.isWhiteboardVisible = false
    }

    private func requestContentWindowSize(isWhiteboardVisible: Bool) {
        guard let windowScene else { return }
        let size = CGSize(
            width: isWhiteboardVisible ? 420 : 980,
            height: isWhiteboardVisible ? 150 : 620
        )
        let preferences = UIWindowScene.GeometryPreferences.Vision(
            size: size,
            minimumSize: size,
            maximumSize: size,
            resizingRestrictions: .uniform
        )
        windowScene.requestGeometryUpdate(preferences) { error in
            print("Window resize failed: \(error.localizedDescription)")
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

private struct WindowSceneReader: UIViewRepresentable {
    let onSceneChange: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> SceneReadingView {
        SceneReadingView(onSceneChange: onSceneChange)
    }

    func updateUIView(_ uiView: SceneReadingView, context: Context) {
        uiView.onSceneChange = onSceneChange
        uiView.reportScene()
    }

    final class SceneReadingView: UIView {
        var onSceneChange: (UIWindowScene?) -> Void

        init(onSceneChange: @escaping (UIWindowScene?) -> Void) {
            self.onSceneChange = onSceneChange
            super.init(frame: .zero)
            isHidden = true
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportScene()
        }

        func reportScene() {
            onSceneChange(window?.windowScene)
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
        .environmentObject(SharePlayManager())
}
