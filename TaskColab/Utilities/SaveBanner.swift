//
//  SaveBanner.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 07/10/25.
//

import SwiftUI

struct SaveBanner: View {
    var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
            Text(text).font(.headline)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThickMaterial, in: Capsule())
        .shadow(radius: 8)
    }
}
