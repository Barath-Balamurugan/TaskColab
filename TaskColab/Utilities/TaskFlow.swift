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
