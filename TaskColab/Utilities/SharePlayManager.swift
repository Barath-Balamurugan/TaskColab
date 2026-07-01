//
//  SharePlayManager.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import Foundation
import GroupActivities
import Combine

struct ImmersivePresenceMessage: Codable, Sendable {
    let userID: String
    let isImmersed: Bool
}

nonisolated struct TaskReadyMessage: Codable, Sendable {
    let day: Int
    let taskIndex: Int
    let userID: String
}

nonisolated struct TaskTimerStartMessage: Codable, Sendable {
    let day: Int
    let taskIndex: Int
    let startDate: Date
}

nonisolated struct TaskSelectionMessage: Codable, Sendable {
    let day: Int
    let taskIndex: Int
}

nonisolated struct TaskProgressRequestMessage: Codable, Sendable {}

nonisolated struct TaskProgressRecord: Codable, Sendable {
    let day: Int
    let currentTaskIndex: Int
    let readyParticipantIDs: [Int: [String]]
    let startDates: [Int: Date]
}

nonisolated struct TaskProgressSnapshotMessage: Codable, Sendable {
    let records: [TaskProgressRecord]
}

@MainActor
final class SharePlayManager: ObservableObject {
    @Published private var session: GroupSession<ColabGroupActivity>?
    @Published private var participants: [Participant] = []
    @Published var isSharing: Bool = false
    @Published var immersiveParticipantIDs: Set<String> = []
    @Published private var currentTaskIndices: [Day: Int] = [:]
    @Published private var readyParticipantIDs: [Day: [Int: Set<String>]] = [:]
    @Published private var taskStartDates: [Day: [Int: Date]] = [:]

    let requiredParticipantCount = 3
    
    private var messenger: GroupSessionMessenger?
    
    let whiteboardEvents = PassthroughSubject<WBMessage, Never>()
    
    init() {
        Task { await observeSessions() }
    }
    
    private func observeSessions() async {
        for await session in ColabGroupActivity.sessions(){
            self.session = session
            self.messenger = GroupSessionMessenger(session: session)
            self.participants = Array(session.activeParticipants)
            
            // Keep participants list updated
            Task{ [weak self] in
                for await _ in session.$activeParticipants.values{
                    await MainActor.run {self?.participants = Array(session.activeParticipants)}
                }
            }
            
            // Start receiving messages
            Task { [weak self] in await self?.receiveMessages() }
            
            Task { [weak self] in
                await self?.receiveWhiteBoard()
            }

            Task { [weak self] in
                await self?.receiveImmersivePresence()
            }

            Task { [weak self] in await self?.receiveTaskReadyMessages() }
            Task { [weak self] in await self?.receiveTaskTimerStartMessages() }
            Task { [weak self] in await self?.receiveTaskSelectionMessages() }
            Task { [weak self] in await self?.receiveTaskProgressRequests() }
            Task { [weak self] in await self?.receiveTaskProgressSnapshots() }
            
            await session.join()
            await requestTaskProgress()
            
            Task { [weak self] in
                for await state in session.$state.values {
                    await MainActor.run {
                        switch state {
                        case .joined: self?.isSharing = true
                        case .invalidated:
                            self?.isSharing = false
                            self?.session = nil
                            self?.messenger = nil
                            self?.immersiveParticipantIDs.removeAll()
                            self?.currentTaskIndices.removeAll()
                            self?.readyParticipantIDs.removeAll()
                            self?.taskStartDates.removeAll()
                        default: break
                        }
                    }
                }
            }
            
            if let systemCoordinator = await session.systemCoordinator {
                var configuration = SystemCoordinator.Configuration()
                configuration.supportsGroupImmersiveSpace = true
                configuration.spatialTemplatePreference = .sideBySide.contentExtent(200)
                systemCoordinator.configuration = configuration
            }
        }
    }
    
    func sendWhiteBoard(_ message: WBMessage) async {
        guard let messenger else {return}
        do { try await messenger.send(message) }
        catch { print("WhiteBoard Send failed: \(error)") }
    }
    
    private func receiveWhiteBoard() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: WBMessage.self){
            await MainActor.run { whiteboardEvents.send(message)}
        }
    }

    func sendImmersivePresence(userID: String, isImmersed: Bool) async {
        let id = normalizedPresenceID(userID)
        applyImmersivePresence(ImmersivePresenceMessage(userID: id, isImmersed: isImmersed))

        guard let messenger else { return }
        do {
            try await messenger.send(ImmersivePresenceMessage(userID: id, isImmersed: isImmersed))
        } catch {
            print("Immersive presence send failed: \(error)")
        }
    }

    private func receiveImmersivePresence() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: ImmersivePresenceMessage.self) {
            await MainActor.run { self.applyImmersivePresence(message) }
        }
    }

    func currentTaskIndex(for day: Day) -> Int {
        currentTaskIndices[day, default: 0]
    }

    func readyParticipantCount(for day: Day, taskIndex: Int) -> Int {
        readyParticipantIDs[day]?[taskIndex]?.count ?? 0
    }

    func isParticipantReady(userID: String, for day: Day, taskIndex: Int) -> Bool {
        readyParticipantIDs[day]?[taskIndex]?.contains(normalizedPresenceID(userID)) == true
    }

    func startDate(for day: Day, taskIndex: Int) -> Date? {
        taskStartDates[day]?[taskIndex]
    }

    func missionStartDate(for day: Day) -> Date? {
        startDate(for: day, taskIndex: 0)
    }

    func markReadyToStartTimer(userID: String, for day: Day) async {
        let timerTaskIndex = 0
        guard isSharing,
              messenger != nil,
              TaskMatrix.task(for: day, index: timerTaskIndex) != nil,
              missionStartDate(for: day) == nil else { return }

        let message = TaskReadyMessage(
            day: day.rawValue,
            taskIndex: timerTaskIndex,
            userID: normalizedPresenceID(userID)
        )
        applyTaskReady(message)
        await sendTaskMessage(message)
    }

    func selectTask(for day: Day, taskIndex: Int) async {
        guard TaskMatrix.task(for: day, index: taskIndex) != nil else { return }

        let message = TaskSelectionMessage(day: day.rawValue, taskIndex: taskIndex)
        applyTaskSelection(message)
        await sendTaskMessage(message)
    }

    private func receiveTaskReadyMessages() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: TaskReadyMessage.self) {
            await MainActor.run { self.applyTaskReady(message) }
        }
    }

    private func receiveTaskTimerStartMessages() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: TaskTimerStartMessage.self) {
            await MainActor.run { self.applyTaskTimerStart(message) }
        }
    }

    private func receiveTaskSelectionMessages() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: TaskSelectionMessage.self) {
            await MainActor.run { self.applyTaskSelection(message) }
        }
    }

    private func receiveTaskProgressRequests() async {
        guard let messenger else { return }
        for await _ in messenger.messages(of: TaskProgressRequestMessage.self) {
            await sendTaskProgressSnapshot()
        }
    }

    private func receiveTaskProgressSnapshots() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: TaskProgressSnapshotMessage.self) {
            await MainActor.run { self.applyTaskProgressSnapshot(message) }
        }
    }

    private func applyImmersivePresence(_ message: ImmersivePresenceMessage) {
        if message.isImmersed {
            immersiveParticipantIDs.insert(message.userID)
        } else {
            immersiveParticipantIDs.remove(message.userID)
        }
    }

    private func applyTaskReady(_ message: TaskReadyMessage) {
        guard let day = Day(rawValue: message.day),
              message.taskIndex == 0,
              TaskMatrix.task(for: day, index: 0) != nil,
              missionStartDate(for: day) == nil else { return }

        readyParticipantIDs[day, default: [:]][message.taskIndex, default: []]
            .insert(normalizedPresenceID(message.userID))

        startTaskIfReady(for: day, taskIndex: message.taskIndex)
    }

    private func applyTaskTimerStart(_ message: TaskTimerStartMessage) {
        guard let day = Day(rawValue: message.day),
              message.taskIndex == 0,
              TaskMatrix.task(for: day, index: 0) != nil else { return }

        if let current = taskStartDates[day]?[message.taskIndex] {
            taskStartDates[day, default: [:]][message.taskIndex] = min(current, message.startDate)
        } else {
            taskStartDates[day, default: [:]][message.taskIndex] = message.startDate
        }
    }

    private func applyTaskSelection(_ message: TaskSelectionMessage) {
        guard let day = Day(rawValue: message.day),
              TaskMatrix.task(for: day, index: message.taskIndex) != nil else { return }
        currentTaskIndices[day] = message.taskIndex
    }

    private func applyTaskProgressSnapshot(_ message: TaskProgressSnapshotMessage) {
        for record in message.records {
            guard let day = Day(rawValue: record.day),
                  !TaskMatrix.tasks(for: day).isEmpty else { continue }

            let localIndex = currentTaskIndex(for: day)
            let lastTaskIndex = TaskMatrix.tasks(for: day).count - 1
            let snapshotIndex = min(max(0, record.currentTaskIndex), lastTaskIndex)
            currentTaskIndices[day] = max(localIndex, snapshotIndex)

            for (taskIndex, participantIDs) in record.readyParticipantIDs {
                guard TaskMatrix.task(for: day, index: taskIndex) != nil else { continue }
                readyParticipantIDs[day, default: [:]][taskIndex, default: []]
                    .formUnion(participantIDs.map(normalizedPresenceID))
            }

            for (taskIndex, startDate) in record.startDates {
                guard TaskMatrix.task(for: day, index: taskIndex) != nil else { continue }
                if let localStartDate = taskStartDates[day]?[taskIndex] {
                    taskStartDates[day, default: [:]][taskIndex] = min(localStartDate, startDate)
                } else {
                    taskStartDates[day, default: [:]][taskIndex] = startDate
                }
            }

            startTaskIfReady(for: day, taskIndex: 0)
        }
    }

    private func startTaskIfReady(for day: Day, taskIndex: Int) {
        guard startDate(for: day, taskIndex: taskIndex) == nil,
              readyParticipantCount(for: day, taskIndex: taskIndex) >= requiredParticipantCount else {
            return
        }

        let startMessage = TaskTimerStartMessage(
            day: day.rawValue,
            taskIndex: taskIndex,
            startDate: Date()
        )
        applyTaskTimerStart(startMessage)
        Task { await sendTaskMessage(startMessage) }
    }

    private func requestTaskProgress() async {
        await sendTaskMessage(TaskProgressRequestMessage())
    }

    private func sendTaskProgressSnapshot() async {
        let records = Day.allCases.map { day in
            let readiness = readyParticipantIDs[day, default: [:]]
                .mapValues { Array($0) }
            return TaskProgressRecord(
                day: day.rawValue,
                currentTaskIndex: currentTaskIndex(for: day),
                readyParticipantIDs: readiness,
                startDates: taskStartDates[day, default: [:]]
            )
        }
        await sendTaskMessage(TaskProgressSnapshotMessage(records: records))
    }

    private func sendTaskMessage<Message: Codable & Sendable>(_ message: Message) async {
        guard let messenger else { return }
        do { try await messenger.send(message) }
        catch { print("Task progress send failed: \(error)") }
    }

    private func normalizedPresenceID(_ userID: String) -> String {
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "local" : trimmed
    }
    
    func send(_ msg: ParticipantData) async {
        guard let messenger else { return }
        do { try await messenger.send(msg) }
        catch { print("Send failed: \(error)") }
    }

    private func receiveMessages() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: ParticipantData.self) {
            // Apply incoming state to your UI/scene here
//            print("Received \(message)")
        }
    }
}
