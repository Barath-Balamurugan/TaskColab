//
//  ParentView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 07/10/25.
//

import SwiftUI
import Combine

final class WhiteboardStore: ObservableObject {
    @Published var strokes: [StrokeLocal] = []
    @Published var inProgress: [UUID: StrokeLocal] = [:]
    @Published var lineWidth: CGFloat = 6
    @Published var currentColor: Color = .black
    // add more if you want to persist them across reopen:
    // @Published var canvasSize: CGSize = .zero
}

struct ParentView: View {
    @StateObject private var wbStore = WhiteboardStore()
    @State private var showBoard = false

    var body: some View {
        Button("Open Whiteboard") { showBoard = true }
        .sheet(isPresented: $showBoard) {
            WhiteBoardView()
                .environmentObject(wbStore)   // <— inject
        }
    }
}
