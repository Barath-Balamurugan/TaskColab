//
//  OSCManager.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 27/08/25.
//

import Foundation
import OSCKit

final class OSCManager: Sendable {
    private let client = OSCUDPClient()
    private let server = OSCUDPServer(port: 8000)
    
    init () {
        start()
    }
}

extension OSCManager {
    /// Call this once on app launch.
    func start() {
        // setup client
        do { try client.start() } catch { print(error) }
        
        // setup server
        server.setReceiveHandler { [weak self] message, timeTag, host, port in
            self?.handle(message: message, timeTag: timeTag, host: host, port: port)
        }
        do { try server.start() } catch { print(error) }
    }
    
    func stop() {
        client.stop()
        server.stop()
    }
}

extension OSCManager {
    func handle(message: OSCMessage, timeTag: OSCTimeTag, host: String, port: UInt16) {
//        print("\(message) with time tag: \(timeTag) from: \(host):\(port)")
    }
}

extension OSCManager {
    func send(_ message: OSCMessage, to host: String, port: UInt16) {
        do {
            try client.send(message, to: host, port: port)
        } catch {
            print(error)
        }
    }
}

