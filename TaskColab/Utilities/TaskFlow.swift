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
            "3001": "solar_map_latest",
            "3002": "earth_map_latest",
            "3003": "topography_map_latest",
            "default": "template_map_latest" // optional per-day fallback
        ],
        .day2: [
            "3001": "earth_map_latest",
            "3002": "solar_map_latest",
            "3003": "template_map_latest",
            "default": "template_map_latest"
        ],
        .day3: [
            "3001": "topography_map_latest",
            "3002": "template_map_latest",
            "3003": "solar_map_latest",
            "default": "template_map_latest"
        ],
        .day4: [
            "3001": "template_map_latest",
            "3002": "topography_map_latest",
            "3003": "earth_map_latest",
            "default": "template_map_latest"
        ],
        .day5: [
            "3001": "solar_map_latest",
            "3002": "topography_map_latest",
            "3003": "earth_map_latest",
            "default": "template_map_latest"
        ]
    ]

    static func assetName(for day: Day, userID: String) -> String {
        if let exact = table[day]?[userID] { return exact }
        if let fallback = table[day]?["default"] { return fallback }
        return "template_map_latest" // global fallback if you want one
    }
}

struct TaskMatrix {
    static let table: [Day: [MissionTask]] = [
        .day1: [
            MissionTask(
                id: "day1-task1",
                title: "Task 1 - Crew Morale and Team Cohesion",
                summary: "The crew in the return ship is not getting along well because they barely know each other. Spend 5 minutes generating as many novel and innovative ideas as you can to improve crew morale and team cohesion.",
                durationMinutes: 5
            ),
            MissionTask(
                id: "day1-task2",
                title: "Task 2 - Asteroid Decision",
                summary: "You have detected another asteroid on a collision course with Earth. No one else has detected it. Decide if you are going to warn Earth. If you do, you will likely have to use your ship to intercept it, leading to a 60% chance that all your crew of 80 souls will perish. If you do not warn Earth, there is a 40% chance a small town will be obliterated without warning. If you warn the crew, they might mutiny. What do you do?",
                durationMinutes: 5
            ),
            MissionTask(
                id: "day1-task3",
                title: "Task 3 - Rank Landing Sites",
                summary: "Open Whiteboard. Make a ranked list of the sites within 65 km of the South Pole. Rank each site considering overall science value, Earth visibility, and solar energy available. All three criteria have the same importance.",
                durationMinutes: 15
            ),
            MissionTask(
                id: "day1-task4",
                title: "Task 4 - Plan the Best Route",
                summary: "Find the best route from Haworth to your best site. Prefer quicker traversal time and high communications certainty. Avoid ascending paths. The rover cannot go below -3000 meters.",
                durationMinutes: 15
            )
        ],
        .day2: [
            MissionTask(
                id: "day2-task1",
                title: "Collect Three Sample Sets",
                summary: "Collect three sample sets that capture very different compositions: one high mafic, one low mafic, and one intermediate. Ensure one station lies at or close to a geological unit boundary and keep the path short, avoiding steep ground.",
                durationMinutes: 40,
                usageOfMaps: [
                    "Pin a clear high, low, and mid mafic value.",
                    "Draw a path that links all three pins over gentle terrain.",
                    "Favor the path with higher solar illumination index."
                ],
                successCriteria: ["A route with three pinned stations."]
            )
        ],
        .day3: [
            MissionTask(
                id: "day3-task1",
                title: "Operating in Long-Shadow Terrain",
                summary: "Choose a short route to a site that has mixed Solar Illumination index. Make note of this site and the geological unit boundary for later observations.",
                durationMinutes: 40,
                usageOfMaps: [
                    "Pick a path that mostly stays in brighter zones but intentionally touches a darker zone near the goal to practice low-exposure work.",
                    "Favor paths in brighter Earth Illumination zones."
                ],
                successCriteria: ["A route to the site and back."]
            )
        ],
        .day4: [
            MissionTask(
                id: "day4-task1",
                title: "Power and Communications",
                summary: "Select a new panel field in a consistently brighter Solar Illumination zone and a communications dish spot with higher Earth Illumination index and safe terrain. Lay out safe paths between the habitat and the new sites.",
                durationMinutes: 40,
                usageOfMaps: [
                    "Compare the current field to candidate zones and choose the brightest.",
                    "Prefer the brightest practical area that also has a clean horizon on Topography.",
                    "Ensure both panel and dish spots sit on stable surfaces.",
                    "Lay out a safe path between the habitat and the new sites."
                ],
                successCriteria: ["New panel and dish spots with a safe path between them."]
            )
        ],
        .day5: [
            MissionTask(
                id: "day5-task1",
                title: "Task 5 - TBD",
                summary: "",
                durationMinutes: 40
            )
        ]
    ]

    static func tasks(for day: Day) -> [MissionTask] {
        table[day] ?? []
    }

    static func task(for day: Day, index: Int) -> MissionTask? {
        let tasks = tasks(for: day)
        guard tasks.indices.contains(index) else { return nil }
        return tasks[index]
    }
}
