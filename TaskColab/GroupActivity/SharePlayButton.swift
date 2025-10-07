//
//  SharePlayButton.swift
//  WBAv1
//
//  Created by Barath Balamurugan on 07/08/25.
//

import SwiftUI
import GroupActivities
import CoreTransferable
import UIKit


struct SharePlayButton<ActivityType: GroupActivity & Transferable & Sendable>: View {
    @Environment(AppModel.self) var appModel
    @EnvironmentObject private var sharePlay: SharePlayManager
    @ObservedObject private var groupStateObserver = GroupStateObserver()
    
    @State private var showShareSheet = false
    @State private var showActivationError = false
    
    private let activitySharingView: ActivitySharingView<ActivityType>
    let text: any StringProtocol
    let activity: ActivityType
    
    init(_ text: any StringProtocol, activity: ActivityType){
        self.text = text
        self.activity = activity
        self.activitySharingView = ActivitySharingView{ activity }
    }
    
    var body: some View {
        ZStack{
            ShareLink(item: activity, preview: SharePreview(text)).hidden()
            
            Button {
                Task.detached {
                    if groupStateObserver.isEligibleForGroupSession {
                        do { _ = try await activity.activate() }
                        catch { await MainActor.run { showActivationError = true } }
                    } else {
                        // Not in FaceTime/Messages context → show the share sheet
                        await MainActor.run { showShareSheet = true }
                    }
                }
            } label: {
                Label(sharePlay.isSharing ? "Shared" : String(text),
                      systemImage: sharePlay.isSharing ? "checkmark.circle.fill" : "shareplay")
            }
            .tint(sharePlay.isSharing ? .blue : .green)
            .disabled(sharePlay.isSharing) // disable if already shared
            .sheet(isPresented: $showShareSheet) { activitySharingView }
            .alert("Unable to start sharing", isPresented: $showActivationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again later.")
            }
        }
    }
}

struct ActivitySharingView<ActivityType: GroupActivity & Sendable>: UIViewControllerRepresentable{
    let preparationHandler: () async throws -> ActivityType
    
    func makeUIViewController(context: Context) -> GroupActivitySharingController {
        GroupActivitySharingController(preparationHandler: preparationHandler)
    }
    
    func updateUIViewController(_ uiViewController: GroupActivitySharingController, context: Context) {}
}
