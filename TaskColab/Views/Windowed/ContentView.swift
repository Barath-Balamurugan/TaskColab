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
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    
    @StateObject private var recorder = AudioRecorder()
    
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            content
            .padding()
            .frame(
                width: appModel.isWhiteboardVisible ? 420 : 980,
                height: appModel.isWhiteboardVisible ? 150 : 620
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
                Task{
                    dismissWindow(id: "personal-panel")
                    await closeSpace()
                    appModel.isImmersed = false
                    appModel.isWhiteboardVisible = false
                    await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: false)
                }
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
        VStack {
            Text("Moon Reader")
                .font(.extraLargeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            Spacer()
            Spacer()
            Spacer()
            Spacer()

            Section {
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
            Spacer()
            Spacer()
            Spacer()
            Spacer()

            ImmersiveCountdownView()

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

            Spacer()
        }
    }

    private var whiteboardControlContent: some View {
        VStack(spacing: 16) {
            Label("Whiteboard Open", systemImage: "square.and.pencil")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    appModel.isWhiteboardVisible = false
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
        if !appModel.isImmersed {
            await openSpace()
            appModel.isImmersed = true
            await sharePlayManager.sendImmersivePresence(userID: appModel.userID, isImmersed: true)
            openWindow(id: "personal-panel")
        }
        appModel.isWhiteboardVisible.toggle()
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

struct ImmersiveCountdownView: View {
    @EnvironmentObject private var sharePlayManager: SharePlayManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 8) {
                Text("Mission Timer")
                    .font(.title2.weight(.semibold))

                if let startDate = sharePlayManager.missionStartDate {
                    let remaining = max(0, sharePlayManager.missionDuration - context.date.timeIntervalSince(startDate))
                    Text(timeString(remaining))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                    Text("Started with \(sharePlayManager.immersiveParticipantIDs.count) immersive participants")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeString(sharePlayManager.missionDuration))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                    Text("Waiting for 3 immersive participants (\(sharePlayManager.immersiveParticipantIDs.count)/3)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.towardZero)))
        let mm = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
        .environmentObject(SharePlayManager())
}
