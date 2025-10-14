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
