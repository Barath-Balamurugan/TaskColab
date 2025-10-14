//
//  TaskFlow.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 13/10/25.
//

import SwiftUI

enum Day: String, CaseIterable, Identifiable{
    case day1 = "Day 1"
    case day2 = "Day 2"
    case day3 = "Day 3"
    case day4 = "Day 4"
    case day5 = "Day 5"
    var id: Self { self }
}

struct ImageResolver {
    static let map: [Day: [Int: String]] = [
        .day1: [1: "SolarIllumination", 2: "EarthIllumination", 3: "GeologicalUnits"],
        .day2: [1: "MaficSignature", 2: "GeologicalUnits", 3: "GeologicalUnits"],
        .day3: [1: "GeologicalUnits", 2: "Topography", 3: "Topography"],
        .day4: [1: "SolarIllumination", 2: "EarthIllumination", 3: "Topography"],
        .day5: [1: "SolarIllumination", 2: "Topography", 3: "EarthIllumination"],
    ]
}
