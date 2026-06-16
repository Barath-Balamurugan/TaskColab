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

struct MissionTimerStartMessage: Codable, Sendable {
    let startDate: Date
}

@MainActor
final class SharePlayManager: ObservableObject {
    @Published private var session: GroupSession<ColabGroupActivity>?
    @Published private var participants: [Participant] = []
    @Published var isSharing: Bool = false
    @Published var immersiveParticipantIDs: Set<String> = []
    @Published var missionStartDate: Date?
    let missionDuration: TimeInterval = 40 * 60
    
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

            Task { [weak self] in
                await self?.receiveMissionTimerStart()
            }
            
            await session.join()
            
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
                            self?.missionStartDate = nil
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

    private func receiveMissionTimerStart() async {
        guard let messenger else { return }
        for await (message, _) in messenger.messages(of: MissionTimerStartMessage.self) {
            await MainActor.run {
                if let current = self.missionStartDate {
                    self.missionStartDate = min(current, message.startDate)
                } else {
                    self.missionStartDate = message.startDate
                }
            }
        }
    }

    private func applyImmersivePresence(_ message: ImmersivePresenceMessage) {
        if message.isImmersed {
            immersiveParticipantIDs.insert(message.userID)
        } else {
            immersiveParticipantIDs.remove(message.userID)
        }

        if immersiveParticipantIDs.count >= 3, missionStartDate == nil {
            let startDate = Date()
            missionStartDate = startDate
            Task { await sendMissionTimerStart(startDate) }
        }
    }

    private func sendMissionTimerStart(_ startDate: Date) async {
        guard let messenger else { return }
        do {
            try await messenger.send(MissionTimerStartMessage(startDate: startDate))
        } catch {
            print("Mission timer start send failed: \(error)")
        }
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
