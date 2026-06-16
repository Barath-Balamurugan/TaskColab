//
//  TaskColabApp.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import SwiftUI

@main
struct TaskColabApp: App {

    @State private var appModel = AppModel()
    @StateObject private var sharePlayManager = SharePlayManager()
    @State var oscManager = OSCManager()

    var body: some Scene {
        WindowGroup(id: "content-view"){
            ContentView()
                .environment(appModel)
                .environmentObject(sharePlayManager)
        }
        .defaultSize(width: 980, height: 620)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(oscManager: oscManager)
                .environment(appModel)
                .environmentObject(sharePlayManager)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(id: "personal-panel"){
            PersonalPanelView()
                .environment(appModel)
                .environmentObject(sharePlayManager)
        }
        .defaultSize(width: 820, height: 860)
        .defaultWindowPlacement { _, context in
            if let mainWindow = context.windows.first(where: { $0.id == "content-view" }) {
                WindowPlacement(.trailing(mainWindow), width: 820, height: 860)
            } else {
                WindowPlacement(.utilityPanel, width: 820, height: 860)
            }
        }
        .windowResizability(.contentSize)
     }
}
