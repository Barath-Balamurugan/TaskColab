//
//  SharePlayManager.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import Foundation
import GroupActivities
import Combine

@MainActor
final class SharePlayManager: ObservableObject {
    @Published private var session: GroupSession<ColabGroupActivity>?
    @Published private var participants: [Participant] = []
    @Published var isSharing: Bool = false
    
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
