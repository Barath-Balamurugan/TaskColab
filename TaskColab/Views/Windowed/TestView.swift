//
//  TestView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 13/10/25.
//

import SwiftUI

struct TestView: View {
    @State private var selectedDay: Day = .day1
    @State private var selectedUserId: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Pick a Day") {
                    // Horizontal radios (scrolls if it gets tight)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Day.allCases) { day in
                                RadioButton(
                                    isSelected: selectedDay == day,
                                    title: day.title
                                ) { selectedDay = day }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Who’s the viewer?") {
                    Picker("User", selection: $selectedUserId) {
                        ForEach(1...6, id: \.self) { id in
                            Text("User \(id)").tag(id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Preview") {
                    VStack(spacing: 12) {
                        Text("\(selectedDay.title) • User \(selectedUserId)")
                            .font(.headline)

                        let name = ImageResolver.imageName(for: selectedDay, userId: selectedUserId)

                        if UIImage(named: name) != nil {
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 6)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .foregroundStyle(.secondary)
                                .overlay(
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8),
                                    alignment: .bottom
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Day → User Image")
        }
    }
}

// MARK: - Preview

#Preview {
    TestView()
}
