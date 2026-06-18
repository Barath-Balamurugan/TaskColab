import SwiftUI

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
