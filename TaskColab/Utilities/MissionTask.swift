//
//  MissionTask.swift.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 21/11/25.
//

import Foundation

struct MissionTask: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let summary: String
    let usageOfMaps: [String]
    let successCriteria: [String]
}

