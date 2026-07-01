import SwiftUI

struct ImmersiveCountdownView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let day = appModel.selectedDay
            let tasks = TaskMatrix.tasks(for: day)
            let startDate = sharePlayManager.missionStartDate(for: day)

            if !tasks.isEmpty {
                let totalDuration = tasks.reduce(0) { $0 + $1.duration }
                let elapsed = startDate.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
                let remaining = max(0, totalDuration - elapsed)
                let suggestedTaskIndex = suggestedTaskIndex(for: tasks, elapsed: elapsed)
                let suggestedTaskRemaining = taskTimeRemaining(for: tasks, elapsed: elapsed)
                let readyCount = min(
                    sharePlayManager.readyParticipantCount(for: day, taskIndex: 0),
                    sharePlayManager.requiredParticipantCount
                )

                HStack(spacing: 14) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(startDate == nil ? "Mission not started" : "Mission guidance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(startDate == nil ? "Waiting for participants (\(readyCount)/\(sharePlayManager.requiredParticipantCount))" : "You should be on Task \(suggestedTaskIndex + 1)")
                            .font(.title2.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Task \(suggestedTaskIndex + 1) Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerText(suggestedTaskRemaining))
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerText(remaining))
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                    }
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func suggestedTaskIndex(for tasks: [MissionTask], elapsed: TimeInterval) -> Int {
        var scheduledEnd: TimeInterval = 0
        for (index, task) in tasks.enumerated() {
            scheduledEnd += task.duration
            if elapsed < scheduledEnd { return index }
        }
        return max(0, tasks.count - 1)
    }

    private func taskTimeRemaining(for tasks: [MissionTask], elapsed: TimeInterval) -> TimeInterval {
        var scheduledEnd: TimeInterval = 0
        for task in tasks {
            scheduledEnd += task.duration
            if elapsed < scheduledEnd {
                return scheduledEnd - elapsed
            }
        }
        return 0
    }

    private func timerText(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded(.down)))
        let minutes = seconds / 60
        return String(format: "%02d:%02d", minutes, seconds % 60)
    }
}
