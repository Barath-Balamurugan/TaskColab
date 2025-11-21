//
//  TaskCardView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 21/11/25.
//

import SwiftUI

struct TaskCardView: View {
    let task: MissionTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.title3)
                .fontWeight(.semibold)
            
//            Text(task.summary)
//                .font(.body)
//                .foregroundStyle(.secondary)
            
            if !task.usageOfMaps.isEmpty {
                Text("Conditions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.usageOfMaps, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.footnote)
            }
            
            if !task.successCriteria.isEmpty {
                Text("Completion")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.successCriteria, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.footnote)
            }
        }
        .padding()
        .frame(maxWidth: 1000, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
