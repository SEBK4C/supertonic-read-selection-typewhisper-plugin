import Foundation
import TypeWhisperPluginSDK
import TypeWhisperPluginSDKTesting
import XCTest
@testable import SupertonicPlugin

final class SupertonicPluginTests: XCTestCase {
    func testManifestDeclaresLocalTTSPluginForHost14AndArm64() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("manifest.json")

        let manifest = try JSONDecoder().decode(
            PluginManifest.self,
            from: try Data(contentsOf: manifestURL)
        )

        XCTAssertEqual(manifest.id, "com.sebk4c.typewhisper.tts.supertonic-read-selection")
        XCTAssertEqual(manifest.name, "Supertonic Read Selection")
        XCTAssertEqual(manifest.category, "tts")
        XCTAssertEqual(manifest.categories, ["tts", "action"])
        XCTAssertEqual(manifest.hosting, .local)
        XCTAssertEqual(manifest.requiresAPIKey, false)
        XCTAssertEqual(manifest.minHostVersion, "1.4.0")
        XCTAssertEqual(manifest.supportedArchitectures, ["arm64"])
    }

    func testActionMetadataExposesReadSelectionTarget() throws {
        let plugin = SupertonicPlugin()

        XCTAssertEqual(plugin.actionName, "Read Selection Aloud")
        XCTAssertEqual(plugin.actionId, "com.sebk4c.typewhisper.tts.supertonic-read-selection.action")
        XCTAssertEqual(plugin.actionIcon, "speaker.wave.2.fill")
    }

    func testDownloadRequiresCurrentModelLicenseAcceptance() throws {
        let host = try PluginTestHostServices()
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        XCTAssertFalse(plugin.hasAcceptedCurrentModelLicense)
        XCTAssertFalse(plugin.canDownloadModel)

        plugin.acceptCurrentModelLicense(now: Date(timeIntervalSince1970: 1_716_000_000))

        XCTAssertTrue(plugin.hasAcceptedCurrentModelLicense)
        XCTAssertTrue(plugin.canDownloadModel)
        XCTAssertEqual(host.userDefault(forKey: "acceptedModelLicenseId") as? String, SupertonicModelLicense.id)
        XCTAssertEqual(host.userDefault(forKey: "acceptedModelLicenseRevision") as? String, SupertonicModelLicense.revision)
        XCTAssertEqual(host.userDefault(forKey: "acceptedModelLicenseAt") as? String, "2024-05-18T02:40:00Z")
    }

    func testDownloadWithoutAcceptedLicenseDoesNotStartDownloadFlow() async throws {
        let host = try PluginTestHostServices()
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        await plugin.downloadModel()

        XCTAssertEqual(plugin.modelState, .error(SupertonicPluginError.licenseNotAccepted.localizedDescription))
        let modelDirectory = SupertonicModelAssetManager(rootDirectory: host.pluginDataDirectory).modelDirectory
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDirectory.path))
    }

    func testChangedModelLicenseRevisionInvalidatesPriorAcceptance() throws {
        let host = try PluginTestHostServices(defaults: [
            "acceptedModelLicenseId": SupertonicModelLicense.id,
            "acceptedModelLicenseRevision": "old-revision",
            "acceptedModelLicenseAt": "2024-05-18T08:00:00Z",
        ])
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        XCTAssertFalse(plugin.hasAcceptedCurrentModelLicense)
        XCTAssertFalse(plugin.canDownloadModel)
    }

    func testSelectVoiceSpeedPlaybackDSPQualityAndInferenceBackendPersistChoices() throws {
        let host = try PluginTestHostServices()
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        plugin.selectVoice("F1")
        plugin.setSpeed(1.35)
        plugin.setPlaybackRate(2.25)
        plugin.setPlaybackPitchSemitones(-1.5)
        plugin.setLowPassEnabled(true)
        plugin.setLowPassCutoff(7_500)
        plugin.setQuality(.high)
        plugin.setInferenceBackend(.coreMLGPU)

        XCTAssertEqual(plugin.selectedVoiceId, "F1")
        XCTAssertEqual(plugin.selectedSpeed, 1.35, accuracy: 0.001)
        XCTAssertEqual(plugin.selectedPlaybackRate, 2.25, accuracy: 0.001)
        XCTAssertEqual(plugin.selectedPlaybackPitchSemitones, -1.5, accuracy: 0.001)
        XCTAssertEqual(plugin.selectedLowPassEnabled, true)
        XCTAssertEqual(plugin.selectedLowPassCutoff, 7_500, accuracy: 0.001)
        XCTAssertEqual(plugin.selectedQuality, .high)
        XCTAssertEqual(plugin.selectedInferenceBackend, .coreMLGPU)
        XCTAssertEqual(host.userDefault(forKey: "selectedVoiceId") as? String, "F1")
        XCTAssertEqual(host.userDefault(forKey: "speed") as? Double, 1.35)
        XCTAssertEqual(host.userDefault(forKey: "playbackRate") as? Double, 2.25)
        XCTAssertEqual(host.userDefault(forKey: "playbackPitchSemitones") as? Double, -1.5)
        XCTAssertEqual(host.userDefault(forKey: "lowPassEnabled") as? Bool, true)
        XCTAssertEqual(host.userDefault(forKey: "lowPassCutoff") as? Double, 7_500)
        XCTAssertEqual(host.userDefault(forKey: "quality") as? String, "high")
        XCTAssertEqual(host.userDefault(forKey: "inferenceBackend") as? String, "coreMLGPU")
    }

    func testPlaybackAndInferenceDefaults() throws {
        let host = try PluginTestHostServices()
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        XCTAssertEqual(plugin.selectedSpeed, 1.0)
        XCTAssertEqual(plugin.selectedPlaybackRate, 1.0)
        XCTAssertEqual(plugin.selectedPlaybackPitchSemitones, 0.0)
        XCTAssertEqual(plugin.selectedLowPassEnabled, false)
        XCTAssertEqual(plugin.selectedLowPassCutoff, 9_000)
        XCTAssertEqual(plugin.selectedInferenceBackend, .cpu)
    }

    func testLanguageNormalizationFallsBackToEnglish() {
        XCTAssertEqual(SupertonicLanguageResolver.normalizedLanguageCode(for: "de-DE"), "de")
        XCTAssertEqual(SupertonicLanguageResolver.normalizedLanguageCode(for: "ja"), "ja")
        XCTAssertEqual(SupertonicLanguageResolver.normalizedLanguageCode(for: nil), "en")
        XCTAssertEqual(SupertonicLanguageResolver.normalizedLanguageCode(for: "ga-IE"), "en")
    }

    func testModelInstallerDoesNotWriteFinalDirectoryWhenRequiredFileIsMissing() throws {
        let root = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let installer = SupertonicModelAssetManager(rootDirectory: root)
        var files = SupertonicModelAssetManager.requiredRelativePaths.reduce(into: [String: Data]()) { result, path in
            result[path] = Data("fixture-\(path)".utf8)
        }
        files.removeValue(forKey: "onnx/vocoder.onnx")

        XCTAssertThrowsError(try installer.install(files: files, licenseAccepted: true)) { error in
            XCTAssertEqual((error as? SupertonicPluginError), .incompleteModelAssets)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.modelDirectory.path))
    }

    func testSpeakBeforeModelSetupThrowsNotConfigured() async throws {
        let host = try PluginTestHostServices()
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        do {
            _ = try await plugin.speak(TTSSpeakRequest(text: "Hello", language: "en", purpose: .manualReadback))
            XCTFail("Expected speak to fail before model setup")
        } catch {
            XCTAssertEqual(error as? SupertonicPluginError, .notConfigured)
        }
    }

    func testReadSelectionActionSpeaksInputText() async throws {
        let host = try PluginTestHostServices()
        try installModelFixtures(in: host.pluginDataDirectory)
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)
        plugin.setPlaybackRate(2.0)
        plugin.setPlaybackPitchSemitones(-1.25)
        plugin.setLowPassEnabled(true)
        plugin.setLowPassCutoff(8_000)

        let synthesizer = RecordingSupertonicSynthesizer()
        let sessionFactory = PlaybackSessionFactorySpy()
        plugin.configureSynthesisForTesting(
            synthesizer: synthesizer,
            playbackSessionFactory: { samples, sampleRate, playbackSettings in
                try sessionFactory.make(samples: samples, sampleRate: sampleRate, playbackSettings: playbackSettings)
            }
        )

        let result = try await plugin.execute(
            input: "  Selected text  ",
            context: ActionContext(language: "de-DE", originalText: "Fallback text")
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Reading aloud with Supertonic")
        XCTAssertEqual(result.icon, "speaker.wave.2.fill")
        XCTAssertEqual(synthesizer.lastRequest?.text, "Selected text")
        XCTAssertEqual(synthesizer.lastRequest?.language, "de")
        XCTAssertEqual(synthesizer.lastRequest?.voiceId, "M1")
        XCTAssertEqual(sessionFactory.latestSession?.isActive, true)
        XCTAssertEqual(sessionFactory.latestSession?.playbackSettings.rate ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(sessionFactory.latestSession?.playbackSettings.pitchSemitones ?? 0, -1.25, accuracy: 0.001)
        XCTAssertEqual(sessionFactory.latestSession?.playbackSettings.lowPassEnabled, true)
        XCTAssertEqual(sessionFactory.latestSession?.playbackSettings.lowPassCutoff ?? 0, 8_000, accuracy: 0.001)
    }

    func testReadSelectionActionFallsBackToOriginalText() async throws {
        let host = try PluginTestHostServices()
        try installModelFixtures(in: host.pluginDataDirectory)
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        let synthesizer = RecordingSupertonicSynthesizer()
        let sessionFactory = PlaybackSessionFactorySpy()
        plugin.configureSynthesisForTesting(
            synthesizer: synthesizer,
            playbackSessionFactory: { samples, sampleRate, playbackSettings in
                try sessionFactory.make(samples: samples, sampleRate: sampleRate, playbackSettings: playbackSettings)
            }
        )

        _ = try await plugin.execute(
            input: "  ",
            context: ActionContext(language: "en", originalText: "  Original selected text  ")
        )

        XCTAssertEqual(synthesizer.lastRequest?.text, "Original selected text")
    }

    func testReadSelectionActionStopsActivePlaybackOnSecondShortcut() async throws {
        let host = try PluginTestHostServices()
        try installModelFixtures(in: host.pluginDataDirectory)
        let plugin = SupertonicPlugin()
        plugin.activate(host: host)

        let synthesizer = RecordingSupertonicSynthesizer()
        let sessionFactory = PlaybackSessionFactorySpy()
        plugin.configureSynthesisForTesting(
            synthesizer: synthesizer,
            playbackSessionFactory: { samples, sampleRate, playbackSettings in
                try sessionFactory.make(samples: samples, sampleRate: sampleRate, playbackSettings: playbackSettings)
            }
        )

        _ = try await plugin.execute(
            input: "Read this",
            context: ActionContext(language: "en", originalText: "Read this")
        )
        let activeSession = try XCTUnwrap(sessionFactory.latestSession)

        let result = try await plugin.execute(
            input: "Read this",
            context: ActionContext(language: "en", originalText: "Read this")
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Stopped Supertonic read-aloud")
        XCTAssertEqual(result.icon, "speaker.slash.fill")
        XCTAssertFalse(activeSession.isActive)
        XCTAssertEqual(activeSession.stopCount, 1)
        XCTAssertEqual(synthesizer.requests.count, 1)
    }
}

private func installModelFixtures(in rootDirectory: URL) throws {
    let files = SupertonicModelAssetManager.requiredRelativePaths.reduce(into: [String: Data]()) { result, path in
        result[path] = Data("fixture-\(path)".utf8)
    }
    try SupertonicModelAssetManager(rootDirectory: rootDirectory).install(files: files, licenseAccepted: true)
}

private final class RecordingSupertonicSynthesizer: SupertonicSynthesizing, @unchecked Sendable {
    struct Request: Equatable {
        let text: String
        let language: String
        let voiceId: String
        let quality: SupertonicQuality
        let speed: Double
    }

    private let lock = NSLock()
    private(set) var requests: [Request] = []

    var lastRequest: Request? {
        lock.lock()
        defer { lock.unlock() }
        return requests.last
    }

    func synthesize(
        text: String,
        language: String,
        voiceId: String,
        quality: SupertonicQuality,
        speed: Double
    ) throws -> SupertonicSynthesisOutput {
        lock.lock()
        requests.append(Request(
            text: text,
            language: language,
            voiceId: voiceId,
            quality: quality,
            speed: speed
        ))
        lock.unlock()

        return SupertonicSynthesisOutput(samples: [0, 0.1, -0.1], sampleRate: 16_000)
    }
}

private final class PlaybackSessionFactorySpy: @unchecked Sendable {
    private let lock = NSLock()
    private var sessions: [TestPlaybackSession] = []

    var latestSession: TestPlaybackSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions.last
    }

    func make(samples: [Float], sampleRate: Int, playbackSettings: SupertonicPlaybackSettings) throws -> any TTSPlaybackSession {
        let session = TestPlaybackSession(samples: samples, sampleRate: sampleRate, playbackSettings: playbackSettings)
        lock.lock()
        sessions.append(session)
        lock.unlock()
        return session
    }
}

private final class TestPlaybackSession: TTSPlaybackSession, @unchecked Sendable {
    let samples: [Float]
    let sampleRate: Int
    let playbackSettings: SupertonicPlaybackSettings

    private let lock = NSLock()
    private var active = true
    private var finishHandler: (@Sendable () -> Void)?
    private(set) var stopCount = 0

    init(samples: [Float], sampleRate: Int, playbackSettings: SupertonicPlaybackSettings) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.playbackSettings = playbackSettings
    }

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    var onFinish: (@Sendable () -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return finishHandler
        }
        set {
            lock.lock()
            finishHandler = newValue
            let shouldNotify = !active
            lock.unlock()

            if shouldNotify {
                newValue?()
            }
        }
    }

    func stop() {
        let callback: (@Sendable () -> Void)?
        lock.lock()
        if active {
            active = false
            stopCount += 1
            callback = finishHandler
        } else {
            callback = nil
        }
        lock.unlock()

        callback?()
    }
}
