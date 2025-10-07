import SwiftUI

struct PersonalPanelView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager

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

            // Example: local-only tweak
//            HStack(spacing: 12) {
//                Text("Line Width")
//                Slider(value: $localLineWidth, in: 1...16, step: 1)
//                Text("\(Int(localLineWidth))")
//                    .monospacedDigit()
//                    .frame(width: 32)
//            }
            switch appModel.userID {
                case "3001":
                    Image("SolarIllumination")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(15)
                case "3002":
                    Image("EarthIllumination")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(15)
                case "3003":
                    Image("GeologicalUnits")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(15)
                default:
                    Image("SiteRanking")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(15)
            }

            // Example: quick local info
            if showDiagnostics {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IP: \(appModel.ipAddress)")
                    Text("Port: \(appModel.portNumber)")
                    Text(
                      String(
                        format: "Rel. Position → x: %.2f, y: %.2f, z: %.2f",
                        appModel.relativePosition.x,
                        appModel.relativePosition.y,
                        appModel.relativePosition.z
                      )
                    )
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Spacer()

//            HStack {
//                Toggle("Show Diagnostics", isOn: $showDiagnostics)
//                Spacer()
//            }
        }
        .padding(25)
    }
}

