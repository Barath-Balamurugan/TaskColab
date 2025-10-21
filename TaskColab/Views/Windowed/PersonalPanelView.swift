import SwiftUI

struct PersonalPanelView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var showDiagnostics = false
    @State private var localLineWidth: Double = 6

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                Text("Your Personal Panel")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
            }
            
            // --- Image chosen by (selectedDay, userID) ---
            let asset = ImageMatrix.assetName(for: appModel.selectedDay, userID: appModel.userID)

            Image(asset)
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
                .padding(15)

            // Example: quick local info
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

            Spacer()

            HStack {
                Toggle("Show Diagnostics", isOn: $showDiagnostics)
                Spacer()
            }
        }
        .padding(25)
    }
}

