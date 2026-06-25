import AppKit
import ApplicationServices
import Carbon
import Foundation
import SwiftUI
import TypeWhisperPluginSDK
import os

enum SupertonicDefaultsKey {
    static let selectedVoiceId = "selectedVoiceId"
    static let speed = "speed"
    static let quality = "quality"
    static let inferenceBackend = "inferenceBackend"
    static let readAloudShortcut = "readAloudShortcut"
    static let hfToken = "hf-token"
    static let acceptedModelLicenseId = "acceptedModelLicenseId"
    static let acceptedModelLicenseRevision = "acceptedModelLicenseRevision"
    static let acceptedModelLicenseAt = "acceptedModelLicenseAt"
}

enum SupertonicQuality: String, CaseIterable, Sendable {
    case fast
    case balanced
    case high

    var totalSteps: Int {
        switch self {
        case .fast: 2
        case .balanced: 5
        case .high: 10
        }
    }

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .high: "High"
        }
    }
}

enum SupertonicInferenceBackend: String, CaseIterable, Sendable {
    case cpu
    case coreMLGPU

    var displayName: String {
        switch self {
        case .cpu: "CPU"
        case .coreMLGPU: "Mac GPU"
        }
    }
}

enum SupertonicModelState: Equatable, Sendable {
    case notDownloaded
    case downloading
    case ready
    case error(String)
}

struct SupertonicSynthesisOutput: Sendable {
    let samples: [Float]
    let sampleRate: Int
}

struct SupertonicShortcut: Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    init?(event: NSEvent) {
        guard event.keyCode != UInt16(kVK_Escape) else { return nil }

        let modifiers = event.modifierFlags.intersection(Self.supportedModifierMask)
        guard !modifiers.isEmpty else { return nil }

        self.keyCode = event.keyCode
        self.modifiers = modifiers
    }

    init?(storageValue: String?) {
        guard let storageValue else { return nil }
        let parts = storageValue.split(separator: ":")
        guard parts.count == 2,
              let keyCode = UInt16(parts[0]),
              let rawModifiers = UInt(parts[1]) else {
            return nil
        }

        let modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers).intersection(Self.supportedModifierMask)
        guard !modifiers.isEmpty else { return nil }

        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    var storageValue: String {
        "\(keyCode):\(modifiers.rawValue)"
    }

    var displayName: String {
        let prefix = [
            modifiers.contains(.control) ? "Control" : nil,
            modifiers.contains(.option) ? "Option" : nil,
            modifiers.contains(.shift) ? "Shift" : nil,
            modifiers.contains(.command) ? "Command" : nil,
        ].compactMap { $0 }.joined(separator: " + ")

        let key = Self.keyName(for: keyCode)
        return prefix.isEmpty ? key : "\(prefix) + \(key)"
    }

    func matches(_ event: NSEvent) -> Bool {
        keyCode == event.keyCode
            && modifiers == event.modifierFlags.intersection(Self.supportedModifierMask)
    }

    private static let supportedModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    private static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_LeftArrow: "Left Arrow"
        case kVK_RightArrow: "Right Arrow"
        case kVK_UpArrow: "Up Arrow"
        case kVK_DownArrow: "Down Arrow"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        case kVK_Escape: "Escape"
        default: "Key \(keyCode)"
        }
    }
}

protocol SupertonicSynthesizing: AnyObject, Sendable {
    func synthesize(
        text: String,
        language: String,
        voiceId: String,
        quality: SupertonicQuality,
        speed: Double
    ) throws -> SupertonicSynthesisOutput
}

protocol SupertonicStreamingSynthesizing: SupertonicSynthesizing {
    var sampleRate: Int { get }

    func synthesizeStreaming(
        text: String,
        language: String,
        voiceId: String,
        quality: SupertonicQuality,
        speed: Double,
        onAudio: @escaping @Sendable ([Float]) -> Bool
    ) throws
}

@objc(SupertonicSelectionReaderPlugin)
final class SupertonicPlugin: NSObject, TTSProviderPlugin, ActionPlugin, PluginSettingsActivityReporting, PluginDownloadedModelManaging, @unchecked Sendable {
    static let pluginId = "com.sebk4c.typewhisper.tts.supertonic-read-selection"
    static let pluginName = "Supertonic Read Selection"
    private static let downloadedModelId = "supertonic-3"

    private let logger = Logger(subsystem: "com.sebk4c.typewhisper.tts.supertonic-read-selection", category: "Plugin")
    private var host: HostServices?
    private let synthesizerLock = NSLock()
    private var synthesizer: (any SupertonicSynthesizing)?
    private var playbackSessionFactory: @Sendable ([Float], Int) throws -> any TTSPlaybackSession = { samples, sampleRate in
        try SupertonicPlaybackSession(samples: samples, sampleRate: sampleRate)
    }
    private let actionPlaybackLock = NSLock()
    private var actionPlaybackSession: (any TTSPlaybackSession)?
    @MainActor private var globalShortcutMonitor: Any?
    @MainActor private var localShortcutMonitor: Any?
    @MainActor private var shortcutTask: Task<Void, Never>?
    private var downloadProgress = 0.0
    private(set) var modelState: SupertonicModelState = .notDownloaded

    required override init() {
        super.init()
    }

    func activate(host: HostServices) {
        self.host = host
        modelState = modelAssetManager.hasDownloadedModel() ? .ready : .notDownloaded
        Task { @MainActor [weak self] in
            self?.refreshShortcutMonitors()
        }
    }

    func deactivate() {
        Task { @MainActor [weak self] in
            self?.removeShortcutMonitors()
        }
        stopActionPlaybackIfActive()
        clearSynthesizerCache()
        host = nil
        downloadProgress = 0
        modelState = .notDownloaded
    }

    var actionName: String { "Read Selection Aloud" }
    var actionId: String { "com.sebk4c.typewhisper.tts.supertonic-read-selection.action" }
    var actionIcon: String { "speaker.wave.2.fill" }

    var providerId: String { "supertonic-read-selection" }
    var providerDisplayName: String { "Supertonic Read Selection" }
    var isConfigured: Bool { modelAssetManager.hasDownloadedModel() }
    var availableVoices: [PluginVoiceInfo] { modelAssetManager.availableVoices() }

    var selectedVoiceId: String? {
        (host?.userDefault(forKey: SupertonicDefaultsKey.selectedVoiceId) as? String) ?? "M1"
    }

    var selectedSpeed: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.speed) as? Double ?? 1.05
        return Self.clampedSpeed(raw)
    }

    var selectedQuality: SupertonicQuality {
        if let raw = host?.userDefault(forKey: SupertonicDefaultsKey.quality) as? String,
           let quality = SupertonicQuality(rawValue: raw) {
            return quality
        }
        return .balanced
    }

    var selectedInferenceBackend: SupertonicInferenceBackend {
        if let raw = host?.userDefault(forKey: SupertonicDefaultsKey.inferenceBackend) as? String,
           let backend = SupertonicInferenceBackend(rawValue: raw) {
            return backend
        }
        return .cpu
    }

    var selectedReadAloudShortcut: SupertonicShortcut? {
        SupertonicShortcut(storageValue: host?.userDefault(forKey: SupertonicDefaultsKey.readAloudShortcut) as? String)
    }

    var settingsSummary: String? {
        let voice = selectedVoiceId ?? "M1"
        let shortcut = selectedReadAloudShortcut?.displayName ?? "Not Set"
        return "Voice: \(voice) - Speed: \(String(format: "%.2fx", selectedSpeed)) - \(selectedQuality.displayName) - \(selectedInferenceBackend.displayName) - Shortcut: \(shortcut)"
    }

    var downloadedModels: [PluginModelInfo] {
        guard modelAssetManager.hasDownloadedModel() else { return [] }
        return [
            PluginModelInfo(
                id: Self.downloadedModelId,
                displayName: "Supertonic 3",
                sizeDescription: "Local TTS assets",
                downloaded: true,
                loaded: modelState == .ready
            )
        ]
    }

    func deleteDownloadedModel(_ modelId: String) async throws {
        guard modelId == Self.downloadedModelId else { return }
        try deleteCachedModel()
    }

    @MainActor
    var settingsView: AnyView? {
        AnyView(SupertonicSettingsView(plugin: self))
    }

    var currentSettingsActivity: PluginSettingsActivity? {
        switch modelState {
        case .notDownloaded, .ready:
            return nil
        case .downloading:
            return PluginSettingsActivity(message: "Downloading Supertonic model", progress: downloadProgress)
        case .error(let message):
            return PluginSettingsActivity(message: message, isError: true)
        }
    }

    var hasAcceptedCurrentModelLicense: Bool {
        guard let host else { return false }
        return host.userDefault(forKey: SupertonicDefaultsKey.acceptedModelLicenseId) as? String == SupertonicModelLicense.id
            && host.userDefault(forKey: SupertonicDefaultsKey.acceptedModelLicenseRevision) as? String == SupertonicModelLicense.revision
    }

    var canDownloadModel: Bool {
        hasAcceptedCurrentModelLicense
    }

    var huggingFaceToken: String? {
        PluginHuggingFaceTokenHelper.loadToken(from: host)
    }

    var modelDownloadProgress: Double {
        downloadProgress
    }

    func selectVoice(_ voiceId: String?) {
        host?.setUserDefault(voiceId, forKey: SupertonicDefaultsKey.selectedVoiceId)
    }

    func setSpeed(_ speed: Double) {
        host?.setUserDefault(Self.clampedSpeed(speed), forKey: SupertonicDefaultsKey.speed)
    }

    func setQuality(_ quality: SupertonicQuality) {
        host?.setUserDefault(quality.rawValue, forKey: SupertonicDefaultsKey.quality)
    }

    func setInferenceBackend(_ backend: SupertonicInferenceBackend) {
        guard selectedInferenceBackend != backend else { return }
        host?.setUserDefault(backend.rawValue, forKey: SupertonicDefaultsKey.inferenceBackend)
        clearSynthesizerCache()
        host?.notifyCapabilitiesChanged()
    }

    func setReadAloudShortcut(_ shortcut: SupertonicShortcut?) {
        host?.setUserDefault(shortcut?.storageValue, forKey: SupertonicDefaultsKey.readAloudShortcut)
        Task { @MainActor [weak self] in
            self?.refreshShortcutMonitors()
        }
    }

    func acceptCurrentModelLicense(now: Date = Date()) {
        host?.setUserDefault(SupertonicModelLicense.id, forKey: SupertonicDefaultsKey.acceptedModelLicenseId)
        host?.setUserDefault(SupertonicModelLicense.revision, forKey: SupertonicDefaultsKey.acceptedModelLicenseRevision)
        host?.setUserDefault(Self.isoDateString(from: now), forKey: SupertonicDefaultsKey.acceptedModelLicenseAt)
        host?.notifyCapabilitiesChanged()
    }

    func saveHuggingFaceToken(_ token: String) {
        PluginHuggingFaceTokenHelper.saveToken(token, to: host)
    }

    func clearHuggingFaceToken() {
        PluginHuggingFaceTokenHelper.clearToken(from: host)
    }

    func validateHuggingFaceToken(
        _ token: String,
        dataFetcher: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = PluginHTTPClient.data
    ) async -> Bool {
        await PluginHuggingFaceTokenHelper.validateToken(token, dataFetcher: dataFetcher)
    }

    func downloadModel() async {
        guard canDownloadModel else {
            modelState = .error(SupertonicPluginError.licenseNotAccepted.localizedDescription)
            host?.notifyCapabilitiesChanged()
            return
        }

        downloadProgress = 0
        modelState = .downloading
        host?.notifyCapabilitiesChanged()

        do {
            try await modelAssetManager.download(token: huggingFaceToken, licenseAccepted: true) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.host?.notifyCapabilitiesChanged()
                }
            }
            clearSynthesizerCache()
            downloadProgress = 1
            modelState = .ready
            host?.notifyCapabilitiesChanged()
        } catch {
            logger.error("Supertonic model download failed: \(error.localizedDescription)")
            downloadProgress = 0
            modelState = .error(error.localizedDescription)
            host?.notifyCapabilitiesChanged()
        }
    }

    func deleteCachedModel() throws {
        stopActionPlaybackIfActive()
        clearSynthesizerCache()
        try modelAssetManager.deleteModelFiles()
        downloadProgress = 0
        modelState = .notDownloaded
        host?.notifyCapabilitiesChanged()
    }

    func execute(input: String, context: ActionContext) async throws -> ActionResult {
        if stopActionPlaybackIfActive() {
            return ActionResult(
                success: true,
                message: "Stopped Supertonic read-aloud",
                icon: "speaker.slash.fill",
                displayDuration: 2
            )
        }

        let text = Self.readAloudText(input: input, originalText: context.originalText)
        guard !text.isEmpty else { throw SupertonicPluginError.emptyText }

        let session = try await speak(TTSSpeakRequest(
            text: text,
            language: context.language,
            purpose: .manualReadback
        ))
        setActionPlaybackSession(session)

        return ActionResult(
            success: true,
            message: "Reading aloud with Supertonic",
            icon: actionIcon,
            displayDuration: 2
        )
    }

    func speak(_ request: TTSSpeakRequest) async throws -> any TTSPlaybackSession {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SupertonicPluginError.emptyText }
        guard modelAssetManager.hasDownloadedModel() else {
            throw SupertonicPluginError.notConfigured
        }

        let voiceId = selectedVoiceId ?? "M1"
        let language = SupertonicLanguageResolver.normalizedLanguageCode(for: request.language)
        let quality = selectedQuality
        let speed = selectedSpeed
        let synthesizer = try await Task.detached(priority: .userInitiated) { [self] in
            try synthesizerForCurrentModel()
        }.value

        if let streamingSynthesizer = synthesizer as? any SupertonicStreamingSynthesizing {
            let session = try SupertonicStreamingPlaybackSession(sampleRate: streamingSynthesizer.sampleRate)
            Task.detached(priority: .userInitiated) { [logger] in
                do {
                    try streamingSynthesizer.synthesizeStreaming(
                        text: text,
                        language: language,
                        voiceId: voiceId,
                        quality: quality,
                        speed: speed
                    ) { samples in
                        session.append(samples: samples)
                    }
                    session.finishInput()
                } catch {
                    logger.error("Supertonic streaming synthesis failed: \(error.localizedDescription)")
                    session.finishInput()
                }
            }
            return session
        }

        let output = try await Task.detached(priority: .userInitiated) {
            try synthesizer.synthesize(
                text: text,
                language: language,
                voiceId: voiceId,
                quality: quality,
                speed: speed
            )
        }.value

        return try playbackSessionFactory(output.samples, output.sampleRate)
    }

    func configureSynthesisForTesting(
        synthesizer: any SupertonicSynthesizing,
        playbackSessionFactory: @escaping @Sendable ([Float], Int) throws -> any TTSPlaybackSession
    ) {
        synthesizerLock.lock()
        self.synthesizer = synthesizer
        synthesizerLock.unlock()
        self.playbackSessionFactory = playbackSessionFactory
    }

    fileprivate var modelAssetManager: SupertonicModelAssetManager {
        SupertonicModelAssetManager(
            rootDirectory: host?.pluginDataDirectory
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("SupertonicPlugin", isDirectory: true)
        )
    }

    private func synthesizerForCurrentModel() throws -> any SupertonicSynthesizing {
        synthesizerLock.lock()
        defer { synthesizerLock.unlock() }

        if let synthesizer {
            return synthesizer
        }
        let backend = selectedInferenceBackend
        let modelDirectory = modelAssetManager.modelDirectory
        let synthesizer: any SupertonicSynthesizing
        do {
            synthesizer = try SupertonicONNXSynthesizer(modelDirectory: modelDirectory, inferenceBackend: backend)
        } catch {
            guard backend == .coreMLGPU else { throw error }
            logger.error("Core ML GPU initialization failed; falling back to CPU: \(error.localizedDescription)")
            synthesizer = try SupertonicONNXSynthesizer(modelDirectory: modelDirectory, inferenceBackend: .cpu)
        }
        self.synthesizer = synthesizer
        return synthesizer
    }

    private func clearSynthesizerCache() {
        synthesizerLock.lock()
        synthesizer = nil
        synthesizerLock.unlock()
    }

    @MainActor
    private func refreshShortcutMonitors() {
        removeShortcutMonitors()
        guard selectedReadAloudShortcut != nil else { return }

        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleShortcutEvent(event)
            }
        }
        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.handleShortcutEvent(event) else {
                return event
            }
            return nil
        }
    }

    @MainActor
    private func removeShortcutMonitors() {
        shortcutTask?.cancel()
        shortcutTask = nil

        if let globalShortcutMonitor {
            NSEvent.removeMonitor(globalShortcutMonitor)
            self.globalShortcutMonitor = nil
        }
        if let localShortcutMonitor {
            NSEvent.removeMonitor(localShortcutMonitor)
            self.localShortcutMonitor = nil
        }
    }

    @MainActor
    @discardableResult
    private func handleShortcutEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              !event.isARepeat,
              selectedReadAloudShortcut?.matches(event) == true else {
            return false
        }

        shortcutTask?.cancel()
        shortcutTask = Task { @MainActor [weak self] in
            await self?.readSelectedTextFromShortcut()
        }
        return true
    }

    @MainActor
    private func readSelectedTextFromShortcut() async {
        if stopActionPlaybackIfActive() {
            return
        }

        do {
            let text = try await selectedTextForReadAloud()
            let session = try await speak(TTSSpeakRequest(
                text: text,
                language: nil,
                purpose: .manualReadback
            ))
            setActionPlaybackSession(session)
        } catch {
            logger.error("Supertonic shortcut read-aloud failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func selectedTextForReadAloud() async throws -> String {
        if let text = Self.accessibilitySelectedText() {
            return text
        }
        if let text = await Self.copySelectedTextPreservingClipboard() {
            return text
        }
        throw SupertonicPluginError.emptyText
    }

    private static func accessibilitySelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedElement = focusedValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }

        var selectedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
              let selectedText = selectedValue as? String else {
            return nil
        }

        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static func copySelectedTextPreservingClipboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        postCommandC()
        try? await Task.sleep(for: .milliseconds(180))

        let copied = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.restore(to: pasteboard)

        guard let copied, !copied.isEmpty else { return nil }
        return copied
    }

    private static func postCommandC() {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    @discardableResult
    private func stopActionPlaybackIfActive() -> Bool {
        guard let session = takeActiveActionPlaybackSession() else { return false }
        session.stop()
        return true
    }

    private func setActionPlaybackSession(_ session: any TTSPlaybackSession) {
        let sessionId = ObjectIdentifier(session as AnyObject)
        session.onFinish = { [weak self] in
            self?.clearActionPlaybackSession(matching: sessionId)
        }

        actionPlaybackLock.lock()
        let previousSession = actionPlaybackSession
        actionPlaybackSession = session
        actionPlaybackLock.unlock()

        if let previousSession,
           previousSession.isActive,
           ObjectIdentifier(previousSession as AnyObject) != sessionId {
            previousSession.stop()
        }
    }

    private func takeActiveActionPlaybackSession() -> (any TTSPlaybackSession)? {
        actionPlaybackLock.lock()
        defer { actionPlaybackLock.unlock() }

        guard let session = actionPlaybackSession else { return nil }
        actionPlaybackSession = nil
        return session.isActive ? session : nil
    }

    private func clearActionPlaybackSession(matching sessionId: ObjectIdentifier) {
        actionPlaybackLock.lock()
        defer { actionPlaybackLock.unlock() }

        guard let session = actionPlaybackSession,
              ObjectIdentifier(session as AnyObject) == sessionId else {
            return
        }
        actionPlaybackSession = nil
    }

    private static func readAloudText(input: String, originalText: String) -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInput.isEmpty {
            return trimmedInput
        }
        return originalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clampedSpeed(_ value: Double) -> Double {
        min(max(value, 0.7), 2.0)
    }

    private static func isoDateString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems = items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}

private struct SupertonicSettingsView: View {
    let plugin: SupertonicPlugin
    private let bundle = pluginModuleBundle

    @State private var acceptedLicense = false
    @State private var selectedVoiceId = "M1"
    @State private var speed = 1.05
    @State private var quality: SupertonicQuality = .balanced
    @State private var useCoreMLGPU = false
    @State private var modelState: SupertonicModelState = .notDownloaded
    @State private var progress = 0.0
    @State private var readAloudShortcut: SupertonicShortcut?
    @State private var isRecordingShortcut = false
    @State private var hfTokenInput = ""
    @State private var isValidatingToken = false
    @State private var tokenValidationResult: Bool?
    @State private var isDownloading = false

    private let pollTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supertonic Read Selection", bundle: bundle)
                .font(.headline)

            Text("Local text-to-speech powered by Supertonic 3 ONNX models. Model assets are downloaded only after you accept the model license.", bundle: bundle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            licenseSection

            Divider()

            modelSection

            Divider()

            voiceSection

            Divider()

            inferenceSection

            Divider()

            shortcutSection

            Divider()

            tokenSection
        }
        .padding()
        .frame(minWidth: 480)
        .onAppear {
            refreshFromPlugin()
        }
        .onReceive(pollTimer) { _ in
            refreshTransientState()
        }
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model License", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Supertonic 3 model assets are licensed under OpenRAIL-M and include use restrictions. Review the full license before downloading the model.", bundle: bundle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(String(localized: "Open Supertonic 3 OpenRAIL-M license", bundle: bundle), destination: SupertonicModelLicense.url)
                .font(.caption)

            Toggle(isOn: $acceptedLicense) {
                Text("I have read and accept the Supertonic 3 model license terms", bundle: bundle)
            }
            .onChange(of: acceptedLicense) { _, newValue in
                if newValue {
                    plugin.acceptCurrentModelLicense()
                }
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            switch modelState {
            case .ready:
                HStack {
                    Label(String(localized: "Ready", bundle: bundle), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button(String(localized: "Delete cached model", bundle: bundle)) {
                        try? plugin.deleteCachedModel()
                        refreshFromPlugin()
                    }
                    .controlSize(.small)
                }
            case .downloading:
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 160)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                downloadButton
            case .notDownloaded:
                downloadButton
            }
        }
    }

    private var downloadButton: some View {
        Button {
            isDownloading = true
            Task {
                await plugin.downloadModel()
                await MainActor.run {
                    isDownloading = false
                    refreshFromPlugin()
                }
            }
        } label: {
            Label(String(localized: "Download & Load", bundle: bundle), systemImage: "arrow.down.circle")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!acceptedLicense || isDownloading || modelState == .downloading)
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Picker(String(localized: "Voice", bundle: bundle), selection: $selectedVoiceId) {
                ForEach(plugin.availableVoices, id: \.id) { voice in
                    Text(voice.displayName).tag(voice.id)
                }
            }
            .onChange(of: selectedVoiceId) { _, newValue in
                plugin.selectVoice(newValue)
            }

            HStack {
                Text("Speed", bundle: bundle)
                Spacer()
                Text(speed, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $speed, in: 0.7...2.0, step: 0.05)
                .onChange(of: speed) { _, newValue in
                    plugin.setSpeed(newValue)
                }

            Picker(String(localized: "Quality", bundle: bundle), selection: $quality) {
                ForEach(SupertonicQuality.allCases, id: \.self) { quality in
                    Text(String(localized: String.LocalizationValue(quality.displayName), bundle: bundle)).tag(quality)
                }
            }
            .onChange(of: quality) { _, newValue in
                plugin.setQuality(newValue)
            }
        }
    }

    private var inferenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inference", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Toggle(isOn: $useCoreMLGPU) {
                Text("Use Mac GPU (Core ML)", bundle: bundle)
            }
            .onChange(of: useCoreMLGPU) { _, newValue in
                plugin.setInferenceBackend(newValue ? .coreMLGPU : .cpu)
            }

            Text("Attempts ONNX inference through Core ML on the Mac GPU. If Core ML cannot load the model, speech falls back to CPU.", bundle: bundle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Read Selection Shortcut", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("The plugin listens for this shortcut and reads the current selection with Supertonic. If Accessibility selection is unavailable, it briefly copies the selection and restores your clipboard.", bundle: bundle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(readAloudShortcut?.displayName ?? String(localized: "Not Set", bundle: bundle))
                    .font(.callout.monospaced())
                    .foregroundStyle(readAloudShortcut == nil ? .secondary : .primary)
                    .frame(minWidth: 180, alignment: .leading)

                Button(isRecordingShortcut ? String(localized: "Press Shortcut...", bundle: bundle) : String(localized: "Record", bundle: bundle)) {
                    isRecordingShortcut = true
                }
                .controlSize(.small)

                Button(String(localized: "Clear", bundle: bundle)) {
                    readAloudShortcut = nil
                    isRecordingShortcut = false
                    plugin.setReadAloudShortcut(nil)
                }
                .controlSize(.small)
                .disabled(readAloudShortcut == nil && !isRecordingShortcut)
            }

            if isRecordingShortcut {
                SupertonicShortcutCaptureView { shortcut in
                    readAloudShortcut = shortcut
                    isRecordingShortcut = false
                    plugin.setReadAloudShortcut(shortcut)
                }
                .frame(width: 0, height: 0)

                Text("Press a shortcut with Command, Option, Control, or Shift. Press Escape to cancel.", bundle: bundle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hugging Face Token", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Optional. It can increase download rate limits for the model download.", bundle: bundle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SecureField("hf_...", text: $hfTokenInput)
                    .textFieldStyle(.roundedBorder)

                Button(String(localized: "Save", bundle: bundle)) {
                    validateAndSaveHuggingFaceToken()
                }
                .controlSize(.small)
                .disabled(hfTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidatingToken)

                if plugin.huggingFaceToken != nil {
                    Button(String(localized: "Remove", bundle: bundle)) {
                        hfTokenInput = ""
                        tokenValidationResult = nil
                        plugin.clearHuggingFaceToken()
                    }
                    .controlSize(.small)
                }
            }

            if isValidatingToken {
                ProgressView()
                    .controlSize(.small)
            } else if let tokenValidationResult {
                Label(
                    tokenValidationResult
                        ? String(localized: "Valid Hugging Face token", bundle: bundle)
                        : String(localized: "Invalid Hugging Face token", bundle: bundle),
                    systemImage: tokenValidationResult ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(tokenValidationResult ? .green : .red)
            }
        }
    }

    private func validateAndSaveHuggingFaceToken() {
        let trimmed = hfTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isValidatingToken = true
        tokenValidationResult = nil
        Task {
            let isValid = await plugin.validateHuggingFaceToken(trimmed)
            await MainActor.run {
                isValidatingToken = false
                tokenValidationResult = isValid
                if isValid {
                    plugin.saveHuggingFaceToken(trimmed)
                }
            }
        }
    }

    private func refreshFromPlugin() {
        acceptedLicense = plugin.hasAcceptedCurrentModelLicense
        selectedVoiceId = plugin.selectedVoiceId ?? "M1"
        speed = plugin.selectedSpeed
        quality = plugin.selectedQuality
        useCoreMLGPU = plugin.selectedInferenceBackend == .coreMLGPU
        modelState = plugin.modelState
        progress = plugin.modelDownloadProgress
        readAloudShortcut = plugin.selectedReadAloudShortcut
        hfTokenInput = plugin.huggingFaceToken ?? ""
    }

    private func refreshTransientState() {
        modelState = plugin.modelState
        progress = plugin.modelDownloadProgress
    }
}

private struct SupertonicShortcutCaptureView: NSViewRepresentable {
    let onCapture: (SupertonicShortcut?) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        ShortcutCaptureNSView(onCapture: onCapture)
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class ShortcutCaptureNSView: NSView {
        var onCapture: (SupertonicShortcut?) -> Void

        init(onCapture: @escaping (SupertonicShortcut?) -> Void) {
            self.onCapture = onCapture
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == UInt16(kVK_Escape) {
                onCapture(nil)
                return
            }

            guard let shortcut = SupertonicShortcut(event: event) else {
                NSSound.beep()
                return
            }
            onCapture(shortcut)
        }
    }
}

private let pluginModuleBundle: Bundle = {
    let containingBundle = Bundle(for: SupertonicPlugin.self)
    if containingBundle.url(forResource: "manifest", withExtension: "json") != nil {
        return containingBundle
    }

#if SWIFT_PACKAGE
    return Bundle.module
#else
    return containingBundle
#endif
}()
