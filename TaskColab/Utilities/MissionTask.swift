//
//  MissionTask.swift.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 21/11/25.
//

import Foundation

struct MissionTask: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let duration: TimeInterval
    let usageOfMaps: [String]
    let successCriteria: [String]

    init(
        id: String,
        title: String,
        summary: String,
        durationMinutes: Int,
        usageOfMaps: [String] = [],
        successCriteria: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.duration = TimeInterval(durationMinutes * 60)
        self.usageOfMaps = usageOfMaps
        self.successCriteria = successCriteria
    }
}
