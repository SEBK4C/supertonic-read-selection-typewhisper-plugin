import AVFoundation
import Foundation
import TypeWhisperPluginSDK
import os

private let supertonicPlaybackLogger = Logger(
    subsystem: "com.sebk4c.typewhisper.tts.supertonic-read-selection",
    category: "Playback"
)

final class SupertonicPlaybackSession: TTSPlaybackSession, @unchecked Sendable {
    private struct State {
        var isActive = true
        var onFinish: (@Sendable () -> Void)?
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let state = OSAllocatedUnfairLock(initialState: State())

    var isActive: Bool {
        state.withLock { $0.isActive }
    }

    var onFinish: (@Sendable () -> Void)? {
        get { state.withLock { $0.onFinish } }
        set {
            let shouldNotify = state.withLock { state in
                state.onFinish = newValue
                return !state.isActive
            }
            if shouldNotify {
                newValue?()
            }
        }
    }

    init(samples: [Float], sampleRate: Int) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw SupertonicPluginError.playbackUnavailable
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
              ),
              let channel = buffer.floatChannelData?[0] else {
            throw SupertonicPluginError.playbackUnavailable
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for index in samples.indices {
            channel[index] = max(-1, min(1, samples[index]))
        }

        try engine.start()
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.finish()
        }
        player.play()
    }

    func stop() {
        let wasActive = state.withLock { state -> Bool in
            guard state.isActive else { return false }
            state.isActive = false
            return true
        }
        guard wasActive else { return }

        player.stop()
        engine.stop()
        engine.detach(player)
        onFinish?()
    }

    private func finish() {
        let callback = state.withLock { state -> (@Sendable () -> Void)? in
            guard state.isActive else { return nil }
            state.isActive = false
            return state.onFinish
        }
        callback?()
    }
}

final class SupertonicStreamingPlaybackSession: TTSPlaybackSession, @unchecked Sendable {
    private struct State: Sendable {
        var isActive = true
        var onFinish: (@Sendable () -> Void)?
        var scheduledBufferCount = 0
        var inputFinished = false
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let state = OSAllocatedUnfairLock(initialState: State())

    var isActive: Bool {
        state.withLock { $0.isActive }
    }

    var onFinish: (@Sendable () -> Void)? {
        get { state.withLock { $0.onFinish } }
        set {
            let shouldNotify = state.withLock { state in
                state.onFinish = newValue
                return !state.isActive
            }
            if shouldNotify {
                newValue?()
            }
        }
    }

    init(sampleRate: Int) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw SupertonicPluginError.playbackUnavailable
        }

        self.format = format
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.play()
    }

    @discardableResult
    func append(samples: [Float]) -> Bool {
        guard !samples.isEmpty,
              let buffer = Self.makeBuffer(samples: samples, format: format) else {
            return isActive
        }

        let shouldSchedule = state.withLock { state -> Bool in
            guard state.isActive, !state.inputFinished else { return false }
            state.scheduledBufferCount += 1
            return true
        }
        guard shouldSchedule else { return false }

        supertonicPlaybackLogger.info("Scheduling Supertonic streaming buffer samples=\(samples.count, privacy: .public)")
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.completeScheduledBuffer()
        }
        if !player.isPlaying {
            player.play()
        }
        return isActive
    }

    func finishInput() {
        let shouldFinish = state.withLock { state -> Bool in
            guard state.isActive else { return false }
            state.inputFinished = true
            return state.scheduledBufferCount == 0
        }
        if shouldFinish {
            finish()
        }
    }

    func stop() {
        let callback = state.withLock { state -> (@Sendable () -> Void)? in
            guard state.isActive else { return nil }
            state.isActive = false
            state.scheduledBufferCount = 0
            state.inputFinished = true
            return state.onFinish
        }
        guard let callback else { return }

        player.stop()
        engine.stop()
        engine.detach(player)
        callback()
    }

    private func completeScheduledBuffer() {
        let shouldFinish = state.withLock { state -> Bool in
            guard state.isActive else { return false }
            state.scheduledBufferCount = max(0, state.scheduledBufferCount - 1)
            return state.inputFinished && state.scheduledBufferCount == 0
        }
        if shouldFinish {
            finish()
        }
    }

    private func finish() {
        let callback = state.withLock { state -> (@Sendable () -> Void)? in
            guard state.isActive else { return nil }
            state.isActive = false
            state.scheduledBufferCount = 0
            state.inputFinished = true
            return state.onFinish
        }
        callback?()
    }

    private static func makeBuffer(samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for index in samples.indices {
            channel[index] = max(-1, min(1, samples[index]))
        }
        return buffer
    }
}
