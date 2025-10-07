//
//  AudioRecorder.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 17/09/25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var elapsed: TimeInterval = 0
    @Published var lastRecordingURL: URL?

    private var recorder: AVAudioRecorder?
    private var tick: Timer?

    override init() {
        super.init()
        Task { await requestPermissionIfNeeded() }
    }

    func requestPermissionIfNeeded() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error:", error)
        }

        let status = await AVAudioApplication.requestRecordPermission()
        permissionGranted = status
    }

    func start() {
        guard permissionGranted else { return }

        let filename = Self.timestampedFilename()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            elapsed = 0
            startTick()
        } catch {
            print("Failed to start recording:", error)
            stop()
        }
    }

    func stop() {
        recorder?.stop()
        lastRecordingURL = recorder?.url
        recorder = nil
        isRecording = false
        stopTick()
    }

    func toggle() {
        isRecording ? stop() : start()
    }

    private func startTick() {
        stopTick()
        tick = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let rec = self.recorder, rec.isRecording else { return }
            self.elapsed = rec.currentTime
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    private func stopTick() {
        tick?.invalidate()
        tick = nil
    }

    static func timestampedFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Recording_\(df.string(from: Date())).m4a"
    }

    // MARK: AVAudioRecorderDelegate
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error { print("Recorder encode error:", error) }
        stop()
    }
}
