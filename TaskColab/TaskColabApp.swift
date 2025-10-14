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

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(oscManager: oscManager)
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(id: "personal-panel"){
            PersonalPanelView()
                .environment(appModel)
                .environmentObject(sharePlayManager)
        }
        .defaultSize(width: 600, height: 500)
     }
}
