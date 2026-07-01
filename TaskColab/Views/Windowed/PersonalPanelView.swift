import SwiftUI

struct PersonalPanelView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var showDiagnostics = false
    @State private var localLineWidth: Double = 6

    private var currentTaskIndex: Int {
        sharePlayManager.currentTaskIndex(for: appModel.selectedDay)
    }

    private var selectedTask: MissionTask? {
        TaskMatrix.task(for: appModel.selectedDay, index: currentTaskIndex)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                Text("Your Personal Panel")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
            }

            ImmersiveCountdownView()

            if sharePlayManager.missionStartDate(for: appModel.selectedDay) != nil {
                VStack(spacing: 16) {
                    taskContent
                    taskNavigation
                }
            } else {
                startTimerAction
                Spacer()
            }

            if showDiagnostics {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Day: \(appModel.selectedDay.title)")
                    Text("User Ordinal: \(appModel.userOrdinal)")
                    Text("IP: \(appModel.ipAddress)")
                    Text("Port: \(appModel.portNumber)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            HStack {
                Toggle("Show Diagnostics", isOn: $showDiagnostics)
                Spacer()
            }
        }
        .padding(25)
        .frame(width: 820, height: 860)
    }

    @ViewBuilder
    private var taskContent: some View {
        if let task = selectedTask {
            let asset = ImageMatrix.assetName(
                for: appModel.selectedDay,
                userID: appModel.userID
            )

            ScrollView {
                VStack(spacing: 16) {
                    if shouldShowMap {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 390)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    TaskCardView(task: task)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        } else {
            ContentUnavailableView(
                "No Task Configured",
                systemImage: "exclamationmark.triangle",
                description: Text("There is no task available for \(appModel.selectedDay.title).")
            )
        }
    }

    @ViewBuilder
    private var startTimerAction: some View {
        let day = appModel.selectedDay
        let isSharing = sharePlayManager.isSharing
        let isReady = sharePlayManager.isParticipantReady(
            userID: appModel.userID,
            for: day,
            taskIndex: 0
        )

        Button {
            Task {
                await sharePlayManager.markReadyToStartTimer(
                    userID: appModel.userID,
                    for: day
                )
            }
        } label: {
            Label(
                startButtonTitle(isSharing: isSharing, isReady: isReady),
                systemImage: isReady ? "checkmark.circle.fill" : "timer"
            )
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isReady || !isSharing)
    }

    @ViewBuilder
    private var taskNavigation: some View {
        if selectedTask != nil {
            let day = appModel.selectedDay
            let taskIndex = currentTaskIndex
            let hasPreviousTask = taskIndex > 0
            let hasNextTask = TaskMatrix.task(for: day, index: taskIndex + 1) != nil

            HStack(spacing: 16) {
                Button {
                    Task {
                        await sharePlayManager.selectTask(for: day, taskIndex: taskIndex - 1)
                    }
                } label: {
                    Label("Previous", systemImage: "arrow.left")
                }
                .buttonStyle(.bordered)
                .disabled(!hasPreviousTask)

                Spacer()

                Text("Task \(taskIndex + 1) of \(TaskMatrix.tasks(for: day).count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task {
                        await sharePlayManager.selectTask(for: day, taskIndex: taskIndex + 1)
                    }
                } label: {
                    Label("Next", systemImage: "arrow.right")
                }
                .buttonStyle(.bordered)
                .disabled(!hasNextTask)
            }
        }
    }

    private func startButtonTitle(isSharing: Bool, isReady: Bool) -> String {
        if !isSharing { return "Start SharePlay to Start Timer" }
        if isReady { return "Ready - Waiting for Participants" }
        return "Start"
    }

    private var shouldShowMap: Bool {
        appModel.selectedDay != .day1 || currentTaskIndex >= 2
    }
}
