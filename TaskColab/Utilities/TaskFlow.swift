//
//  TaskFlow.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 13/10/25.
//

import SwiftUI

enum Day: Int, CaseIterable, Identifiable {
    case day1 = 1, day2, day3, day4, day5
    var id: Int { rawValue }
    var title: String { "Day \(rawValue)" }
}

struct ImageResolver {
    /// Optional explicit overrides per day/user.
    static let map: [Day: [Int: String]] = [:]

    /// Naming convention fallback: "day{n}_user{m}"
    static func byConvention(day: Day, userId: Int) -> String {
        "day\(day.rawValue)_user\(userId)"
    }

    static func imageName(for day: Day, userId: Int) -> String {
        if let name = map[day]?[userId] { return name }
        return byConvention(day: day, userId: userId)
    }
}

struct ImageMatrix {
    // Map: Day -> (userID string -> asset name)
    static let table: [Day: [String: String]] = [
        .day1: [
            "3001": "SolarIllumination",
            "3002": "EarthIllumination",
            "3003": "GeologicalUnits",
            "default": "SiteRanking" // optional per-day fallback
        ],
        .day2: [
            "3001": "EarthIllumination",
            "3002": "SolarIllumination",
            "3003": "SiteRanking",
            "default": "SiteRanking"
        ],
        .day3: [
            "3001": "GeologicalUnits",
            "3002": "SiteRanking",
            "3003": "SolarIllumination",
            "default": "SiteRanking"
        ],
        .day4: [
            "3001": "SiteRanking",
            "3002": "GeologicalUnits",
            "3003": "EarthIllumination",
            "default": "SiteRanking"
        ],
        .day5: [
            "3001": "SolarIllumination",
            "3002": "GeologicalUnits",
            "3003": "EarthIllumination",
            "default": "SiteRanking"
        ]
    ]

    static func assetName(for day: Day, userID: String) -> String {
        if let exact = table[day]?[userID] { return exact }
        if let fallback = table[day]?["default"] { return fallback }
        return "SiteRanking" // global fallback if you want one
    }
}

struct TaskMatrix {
    // Map: Day -> (userID string -> MissionTask)Usage
    static let table: [Day: [String: MissionTask]] = [
        .day1: [
            // User 3001 – Day 1
            "3001": MissionTask(
                title: "Task 1 - Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.",
                summary: """
                Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.
                """,
                usageOfMaps: [
                    "Eliminate any site with local slope that looks steep or rim-like.",
                    "Prefer brighter index zones for steadier exposure.",
                    "Prefer brighter index zones for better line-of-sight to Earth.",
                    "Prefer being within a certain range of a unit boundary.",
                    "Note nearby high and low zones for the next day."
                ],
                successCriteria: [
                    "One chosen pad, with justification."
                ]
            ),
            
            // User 3002 – Day 1 (can be same or slightly customized)
            "3002": MissionTask(
                title: "Task 1 - Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.",
                summary: """
                Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.
                """,
                usageOfMaps: [
                    "Eliminate any site with local slope that looks steep or rim-like.",
                    "Prefer brighter index zones for steadier exposure.",
                    "Prefer brighter index zones for better line-of-sight to Earth.",
                    "Prefer being within a certain range of a unit boundary.",
                    "Note nearby high and low zones for the next day."
                ],
                successCriteria: [
                    "One chosen pad, with justification."
                ]
            ),
            
            // User 3003 – Day 1
            "3003": MissionTask(
                title: "Task 1 - Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.",
                summary: """
                Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.
                """,
                usageOfMaps: [
                    "Eliminate any site with local slope that looks steep or rim-like.",
                    "Prefer brighter index zones for steadier exposure.",
                    "Prefer brighter index zones for better line-of-sight to Earth.",
                    "Prefer being within a certain range of a unit boundary.",
                    "Note nearby high and low zones for the next day."
                ],
                successCriteria: [
                    "One chosen pad, with justification."
                ]
            ),
            
            // Optional per-day fallback if userID not found
            "default": MissionTask(
                title: "Task 1 - Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.",
                summary: """
                Pick a permanent habitat pad and cargo staging spot within a circle of 500 meters from your current marker.
                """,
                usageOfMaps: [
                    "Eliminate any site with local slope that looks steep or rim-like.",
                    "Prefer brighter index zones for steadier exposure.",
                    "Prefer brighter index zones for better line-of-sight to Earth.",
                    "Prefer being within a certain range of a unit boundary.",
                    "Note nearby high and low zones for the next day."
                ],
                successCriteria: [
                    "One chosen pad, with justification."
                ]
            )
        ],
        
        .day2: [
            "3001": MissionTask(
                title: "Task 2 – Collect three sample sets that capture very different compositions ",
                summary: """
                Collect three sample sets that capture very different compositions: one high mafic, one low mafic and one intermediate. Ensure one station lies at or close to a geological unit boundary and keep the path small, avoiding steep grounds.
                """,
                usageOfMaps: [
                    "Pin a clear high, low, and mid mafic value.",
                    "Draw a path that links all three pins over gentle terrain.",
                    "Favor the path with higher solar illumination index."
                ],
                successCriteria: [
                    "A route with three pinned stations."
                ]
            ),
            "default": MissionTask(
                title: "Task 2 – Collect three sample sets that capture very different compositions ",
                summary: """
                Collect three sample sets that capture very different compositions: one high mafic, one low mafic and one intermediate.
                """,
                usageOfMaps: [
                    "Pin a clear high, low, and mid mafic value.",
                    "Draw a path that links all three pins over gentle terrain.",
                    "Favor the path with higher solar illumination index."
                ],
                successCriteria: [
                    "A route with three pinned stations."
                ]
            )
        ],
        
        .day3: [
            "default": MissionTask(
                title: "Task 3 - Operating in long-shadow terrain",
                summary: """
                Choose a short route to a site that has mixed Solar Illumination index. Make note of this site and the geological unit boundary for later observations.
                """,
                usageOfMaps: [
                    "Pick a path that mostly stays in brighter zones but intentionally touches a darker zone near the goal to practice low-exposure work.",
                    "Favor paths in brighter Earth Illumination zones."
                ],
                successCriteria: [
                    "A route to the site and back."
                ]
            )
        ],
        
        .day4: [
            "default": MissionTask(
                title: "Task 4 – Power and Communications",
                summary: """
                Select a new panel field in a consistently brighter Solar Illumination zone and a communications dish spot with higher Earth Illumination index and safe terrain. Lay out safe paths between the habitat and the new sites.
                """,
                usageOfMaps: [
                    "Compare the current field to candidate zones and choose the brightest.",
                    "Prefer the brightest practical area that also has a clean horizon on Topography.",
                    "Ensure both panel and dish spots sit on stable surfaces.",
                    "Layout a safe path between habitat and the new sites."
                ],
                successCriteria: [
                    "New panel and dish spot with a safe path between them."
                ]
            )
        ],
        
        .day5: [
            "default": MissionTask(
                title: "Task 5 – TBD",
                summary: "",
                usageOfMaps: [],
                successCriteria: []
            )
        ]
    ]
    
    static func task(for day: Day, userID: String) -> MissionTask {
        if let exact = table[day]?[userID] {
            return exact
        }
        if let fallback = table[day]?["default"] {
            return fallback
        }
        // Global ultra-fallback
        return MissionTask(
            title: "No task configured",
            summary: "No task found for this day and user.",
            usageOfMaps: [],
            successCriteria: []
        )
    }
}

