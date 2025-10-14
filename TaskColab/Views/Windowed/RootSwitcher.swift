//
//  RootSwitcher.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 14/10/25.
//

import SwiftUI

struct RootSwitcher: View {
    @Environment(AppModel.self) var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    
     var body: some View {
         if hasCompletedSetup {
             ContentView()
                 .environment(appModel)
                 .environmentObject(sharePlayManager)
         }
         else{
             SettingsView()
                 .environment(appModel)
         }
    }
}
