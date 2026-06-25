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
    static let playbackRate = "playbackRate"
    static let playbackPitchSemitones = "playbackPitchSemitones"
    static let timePitchOverlap = "timePitchOverlap"
    static let lowPassEnabled = "lowPassEnabled"
    static let lowPassCutoff = "lowPassCutoff"
    static let resonanceEQEnabled = "resonanceEQEnabled"
    static let resonanceEQFrequency = "resonanceEQFrequency"
    static let resonanceEQGain = "resonanceEQGain"
    static let resonanceEQBandwidth = "resonanceEQBandwidth"
    static let clarityEnabled = "clarityEnabled"
    static let clarityFrequency = "clarityFrequency"
    static let clarityGain = "clarityGain"
    static let sibilanceTamerEnabled = "sibilanceTamerEnabled"
    static let sibilanceFrequency = "sibilanceFrequency"
    static let sibilanceGain = "sibilanceGain"
    static let sibilanceBandwidth = "sibilanceBandwidth"
    static let automaticExpressionTagsEnabled = "automaticExpressionTagsEnabled"
    static let breathBetweenSentencesEnabled = "breathBetweenSentencesEnabled"
    static let laughShorthandEnabled = "laughShorthandEnabled"
    static let sighForEllipsesEnabled = "sighForEllipsesEnabled"
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

struct SupertonicPlaybackSettings: Equatable, Sendable {
    static let defaultRate = 1.0
    static let defaultPitchSemitones = 0.0
    static let defaultTimePitchOverlap = 8.0
    static let defaultLowPassCutoff = 9_000.0
    static let defaultResonanceEQFrequency = 900.0
    static let defaultResonanceEQGain = -3.0
    static let defaultResonanceEQBandwidth = 1.0
    static let defaultClarityFrequency = 3_500.0
    static let defaultClarityGain = 2.0
    static let defaultSibilanceFrequency = 6_500.0
    static let defaultSibilanceGain = -3.0
    static let defaultSibilanceBandwidth = 1.0

    let rate: Double
    let pitchSemitones: Double
    let timePitchOverlap: Double
    let lowPassEnabled: Bool
    let lowPassCutoff: Double
    let resonanceEQEnabled: Bool
    let resonanceEQFrequency: Double
    let resonanceEQGain: Double
    let resonanceEQBandwidth: Double
    let clarityEnabled: Bool
    let clarityFrequency: Double
    let clarityGain: Double
    let sibilanceTamerEnabled: Bool
    let sibilanceFrequency: Double
    let sibilanceGain: Double
    let sibilanceBandwidth: Double

    var pitchCents: Double {
        pitchSemitones * 100
    }

    init(
        rate: Double = Self.defaultRate,
        pitchSemitones: Double = Self.defaultPitchSemitones,
        timePitchOverlap: Double = Self.defaultTimePitchOverlap,
        lowPassEnabled: Bool = false,
        lowPassCutoff: Double = Self.defaultLowPassCutoff,
        resonanceEQEnabled: Bool = false,
        resonanceEQFrequency: Double = Self.defaultResonanceEQFrequency,
        resonanceEQGain: Double = Self.defaultResonanceEQGain,
        resonanceEQBandwidth: Double = Self.defaultResonanceEQBandwidth,
        clarityEnabled: Bool = false,
        clarityFrequency: Double = Self.defaultClarityFrequency,
        clarityGain: Double = Self.defaultClarityGain,
        sibilanceTamerEnabled: Bool = false,
        sibilanceFrequency: Double = Self.defaultSibilanceFrequency,
        sibilanceGain: Double = Self.defaultSibilanceGain,
        sibilanceBandwidth: Double = Self.defaultSibilanceBandwidth
    ) {
        self.rate = Self.clampedRate(rate)
        self.pitchSemitones = Self.clampedPitchSemitones(pitchSemitones)
        self.timePitchOverlap = Self.clampedTimePitchOverlap(timePitchOverlap)
        self.lowPassEnabled = lowPassEnabled
        self.lowPassCutoff = Self.clampedLowPassCutoff(lowPassCutoff)
        self.resonanceEQEnabled = resonanceEQEnabled
        self.resonanceEQFrequency = Self.clampedResonanceEQFrequency(resonanceEQFrequency)
        self.resonanceEQGain = Self.clampedCutGain(resonanceEQGain)
        self.resonanceEQBandwidth = Self.clampedEQBandwidth(resonanceEQBandwidth)
        self.clarityEnabled = clarityEnabled
        self.clarityFrequency = Self.clampedClarityFrequency(clarityFrequency)
        self.clarityGain = Self.clampedShelfGain(clarityGain)
        self.sibilanceTamerEnabled = sibilanceTamerEnabled
        self.sibilanceFrequency = Self.clampedSibilanceFrequency(sibilanceFrequency)
        self.sibilanceGain = Self.clampedCutGain(sibilanceGain)
        self.sibilanceBandwidth = Self.clampedEQBandwidth(sibilanceBandwidth)
    }

    static func clampedRate(_ value: Double) -> Double {
        min(max(value, 1.0), 4.0)
    }

    static func clampedPitchSemitones(_ value: Double) -> Double {
        min(max(value, -6.0), 6.0)
    }

    static func clampedTimePitchOverlap(_ value: Double) -> Double {
        min(max(value, 4.0), 64.0)
    }

    static func clampedLowPassCutoff(_ value: Double) -> Double {
        min(max(value, 4_000), 12_000)
    }

    static func clampedResonanceEQFrequency(_ value: Double) -> Double {
        min(max(value, 250), 2_500)
    }

    static func clampedClarityFrequency(_ value: Double) -> Double {
        min(max(value, 2_000), 8_000)
    }

    static func clampedSibilanceFrequency(_ value: Double) -> Double {
        min(max(value, 3_000), 10_000)
    }

    static func clampedCutGain(_ value: Double) -> Double {
        min(max(value, -18.0), 0.0)
    }

    static func clampedShelfGain(_ value: Double) -> Double {
        min(max(value, -6.0), 6.0)
    }

    static func clampedEQBandwidth(_ value: Double) -> Double {
        min(max(value, 0.2), 4.0)
    }
}

struct SupertonicExpressionSettings: Equatable, Sendable {
    static let confirmedTags = ["<laugh>", "<breath>", "<sigh>"]

    let automaticTagsEnabled: Bool
    let breathBetweenSentencesEnabled: Bool
    let laughShorthandEnabled: Bool
    let sighForEllipsesEnabled: Bool
}

enum SupertonicExpressionTagger {
    static func apply(to text: String, settings: SupertonicExpressionSettings) -> String {
        guard settings.automaticTagsEnabled else { return text }

        var taggedText = text
        if settings.laughShorthandEnabled {
            taggedText = replaceLaughShorthand(in: taggedText)
        }
        if settings.sighForEllipsesEnabled {
            taggedText = replaceEllipses(in: taggedText)
        }
        if settings.breathBetweenSentencesEnabled {
            taggedText = insertBreathsBetweenSentences(in: taggedText)
        }
        return collapseTagWhitespace(taggedText)
    }

    private static func replaceLaughShorthand(in text: String) -> String {
        let pattern = #"(?i)(^|[\s,.;:!?])[\(\[]\s*(lol|laughs?|haha+|hehe+)\s*[\)\]]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let range = NSRange(result.startIndex..., in: result)
        for match in regex.matches(in: result, range: range).reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let prefixRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            result.replaceSubrange(fullRange, with: "\(result[prefixRange])<laugh>")
        }
        return result
    }

    private static func replaceEllipses(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\.\.\.|…)"#) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " <sigh> ")
    }

    private static func insertBreathsBetweenSentences(in text: String) -> String {
        let paragraphs = text.components(separatedBy: "\n\n")
        return paragraphs
            .map { paragraph in
                let sentences = splitSentences(paragraph)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard sentences.count > 1 else { return paragraph }
                return sentences.joined(separator: " <breath> ")
            }
            .joined(separator: "\n\n")
    }

    private static func splitSentences(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "([.!?])\\s+") else {
            return [text]
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return [text] }

        var sentences: [String] = []
        var lastEnd = text.startIndex
        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let punctuationRange = Range(NSRange(location: match.range.location, length: 1), in: text) else {
                continue
            }

            let sentenceEnd = punctuationRange.upperBound
            let candidate = String(text[lastEnd..<sentenceEnd])
            if isLikelyAbbreviation(candidate) {
                continue
            }

            sentences.append(candidate)
            lastEnd = matchRange.upperBound
        }

        let remainder = String(text[lastEnd...])
        if !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences.append(remainder)
        }
        return sentences.isEmpty ? [text] : sentences
    }

    private static func isLikelyAbbreviation(_ sentence: String) -> Bool {
        let words = sentence.split(separator: " ")
        guard let lastWord = words.last else { return false }
        return abbreviations.contains(String(lastWord))
    }

    private static func collapseTagWhitespace(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"[ \t]+"#) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let abbreviations: Set<String> = [
        "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.",
        "St.", "Ave.", "Rd.", "Blvd.", "Dept.", "Inc.", "Ltd.",
        "Co.", "Corp.", "etc.", "vs.", "i.e.", "e.g.", "Ph.D.",
    ]
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
    private var playbackSessionFactory: @Sendable ([Float], Int, SupertonicPlaybackSettings) throws -> any TTSPlaybackSession = { samples, sampleRate, playbackSettings in
        try SupertonicPlaybackSession(samples: samples, sampleRate: sampleRate, playbackSettings: playbackSettings)
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
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.speed) as? Double ?? 1.0
        return Self.clampedSpeed(raw)
    }

    var selectedPlaybackRate: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.playbackRate) as? Double ?? 1.0
        return SupertonicPlaybackSettings.clampedRate(raw)
    }

    var selectedPlaybackPitchSemitones: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.playbackPitchSemitones) as? Double ?? SupertonicPlaybackSettings.defaultPitchSemitones
        return SupertonicPlaybackSettings.clampedPitchSemitones(raw)
    }

    var selectedTimePitchOverlap: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.timePitchOverlap) as? Double ?? SupertonicPlaybackSettings.defaultTimePitchOverlap
        return SupertonicPlaybackSettings.clampedTimePitchOverlap(raw)
    }

    var selectedLowPassEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.lowPassEnabled) as? Bool ?? false
    }

    var selectedLowPassCutoff: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.lowPassCutoff) as? Double ?? SupertonicPlaybackSettings.defaultLowPassCutoff
        return SupertonicPlaybackSettings.clampedLowPassCutoff(raw)
    }

    var selectedResonanceEQEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.resonanceEQEnabled) as? Bool ?? false
    }

    var selectedResonanceEQFrequency: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.resonanceEQFrequency) as? Double ?? SupertonicPlaybackSettings.defaultResonanceEQFrequency
        return SupertonicPlaybackSettings.clampedResonanceEQFrequency(raw)
    }

    var selectedResonanceEQGain: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.resonanceEQGain) as? Double ?? SupertonicPlaybackSettings.defaultResonanceEQGain
        return SupertonicPlaybackSettings.clampedCutGain(raw)
    }

    var selectedResonanceEQBandwidth: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.resonanceEQBandwidth) as? Double ?? SupertonicPlaybackSettings.defaultResonanceEQBandwidth
        return SupertonicPlaybackSettings.clampedEQBandwidth(raw)
    }

    var selectedClarityEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.clarityEnabled) as? Bool ?? false
    }

    var selectedClarityFrequency: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.clarityFrequency) as? Double ?? SupertonicPlaybackSettings.defaultClarityFrequency
        return SupertonicPlaybackSettings.clampedClarityFrequency(raw)
    }

    var selectedClarityGain: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.clarityGain) as? Double ?? SupertonicPlaybackSettings.defaultClarityGain
        return SupertonicPlaybackSettings.clampedShelfGain(raw)
    }

    var selectedSibilanceTamerEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.sibilanceTamerEnabled) as? Bool ?? false
    }

    var selectedSibilanceFrequency: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.sibilanceFrequency) as? Double ?? SupertonicPlaybackSettings.defaultSibilanceFrequency
        return SupertonicPlaybackSettings.clampedSibilanceFrequency(raw)
    }

    var selectedSibilanceGain: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.sibilanceGain) as? Double ?? SupertonicPlaybackSettings.defaultSibilanceGain
        return SupertonicPlaybackSettings.clampedCutGain(raw)
    }

    var selectedSibilanceBandwidth: Double {
        let raw = host?.userDefault(forKey: SupertonicDefaultsKey.sibilanceBandwidth) as? Double ?? SupertonicPlaybackSettings.defaultSibilanceBandwidth
        return SupertonicPlaybackSettings.clampedEQBandwidth(raw)
    }

    var selectedAutomaticExpressionTagsEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.automaticExpressionTagsEnabled) as? Bool ?? false
    }

    var selectedBreathBetweenSentencesEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.breathBetweenSentencesEnabled) as? Bool ?? false
    }

    var selectedLaughShorthandEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.laughShorthandEnabled) as? Bool ?? false
    }

    var selectedSighForEllipsesEnabled: Bool {
        host?.userDefault(forKey: SupertonicDefaultsKey.sighForEllipsesEnabled) as? Bool ?? false
    }

    var selectedExpressionSettings: SupertonicExpressionSettings {
        SupertonicExpressionSettings(
            automaticTagsEnabled: selectedAutomaticExpressionTagsEnabled,
            breathBetweenSentencesEnabled: selectedBreathBetweenSentencesEnabled,
            laughShorthandEnabled: selectedLaughShorthandEnabled,
            sighForEllipsesEnabled: selectedSighForEllipsesEnabled
        )
    }

    var selectedPlaybackSettings: SupertonicPlaybackSettings {
        SupertonicPlaybackSettings(
            rate: selectedPlaybackRate,
            pitchSemitones: selectedPlaybackPitchSemitones,
            timePitchOverlap: selectedTimePitchOverlap,
            lowPassEnabled: selectedLowPassEnabled,
            lowPassCutoff: selectedLowPassCutoff,
            resonanceEQEnabled: selectedResonanceEQEnabled,
            resonanceEQFrequency: selectedResonanceEQFrequency,
            resonanceEQGain: selectedResonanceEQGain,
            resonanceEQBandwidth: selectedResonanceEQBandwidth,
            clarityEnabled: selectedClarityEnabled,
            clarityFrequency: selectedClarityFrequency,
            clarityGain: selectedClarityGain,
            sibilanceTamerEnabled: selectedSibilanceTamerEnabled,
            sibilanceFrequency: selectedSibilanceFrequency,
            sibilanceGain: selectedSibilanceGain,
            sibilanceBandwidth: selectedSibilanceBandwidth
        )
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
        return "Voice: \(voice) - Generation: \(String(format: "%.2fx", selectedSpeed)) - Playback: \(String(format: "%.2fx", selectedPlaybackRate)) - \(selectedQuality.displayName) - \(selectedInferenceBackend.displayName) - Shortcut: \(shortcut)"
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

    func setPlaybackRate(_ playbackRate: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedRate(playbackRate), forKey: SupertonicDefaultsKey.playbackRate)
    }

    func setPlaybackPitchSemitones(_ pitchSemitones: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedPitchSemitones(pitchSemitones), forKey: SupertonicDefaultsKey.playbackPitchSemitones)
    }

    func setTimePitchOverlap(_ overlap: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedTimePitchOverlap(overlap), forKey: SupertonicDefaultsKey.timePitchOverlap)
    }

    func setLowPassEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.lowPassEnabled)
    }

    func setLowPassCutoff(_ cutoff: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedLowPassCutoff(cutoff), forKey: SupertonicDefaultsKey.lowPassCutoff)
    }

    func setResonanceEQEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.resonanceEQEnabled)
    }

    func setResonanceEQFrequency(_ frequency: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedResonanceEQFrequency(frequency), forKey: SupertonicDefaultsKey.resonanceEQFrequency)
    }

    func setResonanceEQGain(_ gain: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedCutGain(gain), forKey: SupertonicDefaultsKey.resonanceEQGain)
    }

    func setResonanceEQBandwidth(_ bandwidth: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedEQBandwidth(bandwidth), forKey: SupertonicDefaultsKey.resonanceEQBandwidth)
    }

    func setClarityEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.clarityEnabled)
    }

    func setClarityFrequency(_ frequency: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedClarityFrequency(frequency), forKey: SupertonicDefaultsKey.clarityFrequency)
    }

    func setClarityGain(_ gain: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedShelfGain(gain), forKey: SupertonicDefaultsKey.clarityGain)
    }

    func setSibilanceTamerEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.sibilanceTamerEnabled)
    }

    func setSibilanceFrequency(_ frequency: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedSibilanceFrequency(frequency), forKey: SupertonicDefaultsKey.sibilanceFrequency)
    }

    func setSibilanceGain(_ gain: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedCutGain(gain), forKey: SupertonicDefaultsKey.sibilanceGain)
    }

    func setSibilanceBandwidth(_ bandwidth: Double) {
        host?.setUserDefault(SupertonicPlaybackSettings.clampedEQBandwidth(bandwidth), forKey: SupertonicDefaultsKey.sibilanceBandwidth)
    }

    func setAutomaticExpressionTagsEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.automaticExpressionTagsEnabled)
    }

    func setBreathBetweenSentencesEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.breathBetweenSentencesEnabled)
    }

    func setLaughShorthandEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.laughShorthandEnabled)
    }

    func setSighForEllipsesEnabled(_ enabled: Bool) {
        host?.setUserDefault(enabled, forKey: SupertonicDefaultsKey.sighForEllipsesEnabled)
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

    func playSettingsPreview() async throws {
        stopActionPlaybackIfActive()
        let session = try await speak(TTSSpeakRequest(
            text: "This is a Supertonic playback test. Tune the speed, pitch, and cleanup controls until this voice sounds clear.",
            language: "en",
            purpose: .manualReadback
        ))
        setActionPlaybackSession(session)
    }

    func stopSettingsPreview() {
        stopActionPlaybackIfActive()
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
        let expressionSettings = selectedExpressionSettings
        let synthesisText = SupertonicExpressionTagger.apply(to: text, settings: expressionSettings)
        let playbackSettings = selectedPlaybackSettings
        let synthesizer = try await Task.detached(priority: .userInitiated) { [self] in
            try synthesizerForCurrentModel()
        }.value

        if let streamingSynthesizer = synthesizer as? any SupertonicStreamingSynthesizing {
            let session = try SupertonicStreamingPlaybackSession(sampleRate: streamingSynthesizer.sampleRate, playbackSettings: playbackSettings)
            Task.detached(priority: .userInitiated) { [logger] in
                do {
                    try streamingSynthesizer.synthesizeStreaming(
                        text: synthesisText,
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
                text: synthesisText,
                language: language,
                voiceId: voiceId,
                quality: quality,
                speed: speed
            )
        }.value

        return try playbackSessionFactory(output.samples, output.sampleRate, playbackSettings)
    }

    func configureSynthesisForTesting(
        synthesizer: any SupertonicSynthesizing,
        playbackSessionFactory: @escaping @Sendable ([Float], Int, SupertonicPlaybackSettings) throws -> any TTSPlaybackSession
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
    @State private var speed = 1.0
    @State private var playbackRate = 1.0
    @State private var playbackPitchSemitones = 0.0
    @State private var timePitchOverlap = SupertonicPlaybackSettings.defaultTimePitchOverlap
    @State private var lowPassEnabled = false
    @State private var lowPassCutoff = SupertonicPlaybackSettings.defaultLowPassCutoff
    @State private var resonanceEQEnabled = false
    @State private var resonanceEQFrequency = SupertonicPlaybackSettings.defaultResonanceEQFrequency
    @State private var resonanceEQGain = SupertonicPlaybackSettings.defaultResonanceEQGain
    @State private var resonanceEQBandwidth = SupertonicPlaybackSettings.defaultResonanceEQBandwidth
    @State private var clarityEnabled = false
    @State private var clarityFrequency = SupertonicPlaybackSettings.defaultClarityFrequency
    @State private var clarityGain = SupertonicPlaybackSettings.defaultClarityGain
    @State private var sibilanceTamerEnabled = false
    @State private var sibilanceFrequency = SupertonicPlaybackSettings.defaultSibilanceFrequency
    @State private var sibilanceGain = SupertonicPlaybackSettings.defaultSibilanceGain
    @State private var sibilanceBandwidth = SupertonicPlaybackSettings.defaultSibilanceBandwidth
    @State private var advancedAudioExpanded = false
    @State private var automaticExpressionTagsEnabled = false
    @State private var breathBetweenSentencesEnabled = false
    @State private var laughShorthandEnabled = false
    @State private var sighForEllipsesEnabled = false
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
    @State private var isStartingPreview = false
    @State private var previewError: String?

    private let pollTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
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

            playbackSection

            Divider()

            expressionSection

            Divider()

            inferenceSection

                Divider()

                shortcutSection

                Divider()

                tokenSection
            }
            .padding()
            .frame(minWidth: 480, alignment: .leading)
        }
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
                Text("Generation Speed", bundle: bundle)
                Spacer()
                Text("\(speed, specifier: "%.2f")x")
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

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            playbackRateControl
            playbackPitchControl

            DisclosureGroup(isExpanded: $advancedAudioExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    timePitchOverlapControl
                    lowPassControls
                    resonanceControls
                    clarityControls
                    sibilanceControls
                }
                .padding(.top, 4)
            } label: {
                Text("Advanced Audio", bundle: bundle)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            playbackPreviewControls
        }
    }

    private var playbackRateControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Speed", bundle: bundle)
                Spacer()
                Text("\(playbackRate, specifier: "%.2f")x")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $playbackRate, in: 1.0...4.0, step: 0.05)
                .onChange(of: playbackRate) { _, newValue in
                    plugin.setPlaybackRate(newValue)
                }
        }
    }

    private var playbackPitchControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Pitch", bundle: bundle)
                Spacer()
                Text("\(playbackPitchSemitones, specifier: "%+.2f") st")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $playbackPitchSemitones, in: -6.0...6.0, step: 0.25)
                .onChange(of: playbackPitchSemitones) { _, newValue in
                    plugin.setPlaybackPitchSemitones(newValue)
                }
        }
    }

    private var timePitchOverlapControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Time-Stretch Overlap", bundle: bundle)
                Spacer()
                Text("\(timePitchOverlap, specifier: "%.0f")")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $timePitchOverlap, in: 4.0...64.0, step: 1.0)
                .onChange(of: timePitchOverlap) { _, newValue in
                    plugin.setTimePitchOverlap(newValue)
                }
        }
    }

    private var lowPassControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $lowPassEnabled) {
                Text("Low-Pass Cleanup", bundle: bundle)
            }
            .onChange(of: lowPassEnabled) { _, newValue in
                plugin.setLowPassEnabled(newValue)
            }

            HStack {
                Text("Cutoff", bundle: bundle)
                Spacer()
                Text("\(lowPassCutoff / 1_000, specifier: "%.1f") kHz")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $lowPassCutoff, in: 4_000...12_000, step: 250)
                .disabled(!lowPassEnabled)
                .onChange(of: lowPassCutoff) { _, newValue in
                    plugin.setLowPassCutoff(newValue)
                }
        }
    }

    private var resonanceControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $resonanceEQEnabled) {
                Text("Resonance Cut", bundle: bundle)
            }
            .onChange(of: resonanceEQEnabled) { _, newValue in
                plugin.setResonanceEQEnabled(newValue)
            }

            HStack {
                Text("Resonance Frequency", bundle: bundle)
                Spacer()
                Text("\(resonanceEQFrequency / 1_000, specifier: "%.2f") kHz")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $resonanceEQFrequency, in: 250...2_500, step: 50)
                .disabled(!resonanceEQEnabled)
                .onChange(of: resonanceEQFrequency) { _, newValue in
                    plugin.setResonanceEQFrequency(newValue)
                }

            HStack {
                Text("Resonance Gain", bundle: bundle)
                Spacer()
                Text("\(resonanceEQGain, specifier: "%.1f") dB")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $resonanceEQGain, in: -18.0...0.0, step: 0.5)
                .disabled(!resonanceEQEnabled)
                .onChange(of: resonanceEQGain) { _, newValue in
                    plugin.setResonanceEQGain(newValue)
                }

            HStack {
                Text("Resonance Width", bundle: bundle)
                Spacer()
                Text("\(resonanceEQBandwidth, specifier: "%.1f")")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $resonanceEQBandwidth, in: 0.2...4.0, step: 0.1)
                .disabled(!resonanceEQEnabled)
                .onChange(of: resonanceEQBandwidth) { _, newValue in
                    plugin.setResonanceEQBandwidth(newValue)
                }
        }
    }

    private var clarityControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $clarityEnabled) {
                Text("Clarity Shelf", bundle: bundle)
            }
            .onChange(of: clarityEnabled) { _, newValue in
                plugin.setClarityEnabled(newValue)
            }

            HStack {
                Text("Clarity Frequency", bundle: bundle)
                Spacer()
                Text("\(clarityFrequency / 1_000, specifier: "%.1f") kHz")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $clarityFrequency, in: 2_000...8_000, step: 250)
                .disabled(!clarityEnabled)
                .onChange(of: clarityFrequency) { _, newValue in
                    plugin.setClarityFrequency(newValue)
                }

            HStack {
                Text("Clarity Gain", bundle: bundle)
                Spacer()
                Text("\(clarityGain, specifier: "%+.1f") dB")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $clarityGain, in: -6.0...6.0, step: 0.5)
                .disabled(!clarityEnabled)
                .onChange(of: clarityGain) { _, newValue in
                    plugin.setClarityGain(newValue)
                }
        }
    }

    private var sibilanceControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $sibilanceTamerEnabled) {
                Text("Sibilance Tamer", bundle: bundle)
            }
            .onChange(of: sibilanceTamerEnabled) { _, newValue in
                plugin.setSibilanceTamerEnabled(newValue)
            }

            HStack {
                Text("Sibilance Frequency", bundle: bundle)
                Spacer()
                Text("\(sibilanceFrequency / 1_000, specifier: "%.1f") kHz")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $sibilanceFrequency, in: 3_000...10_000, step: 250)
                .disabled(!sibilanceTamerEnabled)
                .onChange(of: sibilanceFrequency) { _, newValue in
                    plugin.setSibilanceFrequency(newValue)
                }

            HStack {
                Text("Sibilance Gain", bundle: bundle)
                Spacer()
                Text("\(sibilanceGain, specifier: "%.1f") dB")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $sibilanceGain, in: -18.0...0.0, step: 0.5)
                .disabled(!sibilanceTamerEnabled)
                .onChange(of: sibilanceGain) { _, newValue in
                    plugin.setSibilanceGain(newValue)
                }

            HStack {
                Text("Sibilance Width", bundle: bundle)
                Spacer()
                Text("\(sibilanceBandwidth, specifier: "%.1f")")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: $sibilanceBandwidth, in: 0.2...4.0, step: 0.1)
                .disabled(!sibilanceTamerEnabled)
                .onChange(of: sibilanceBandwidth) { _, newValue in
                    plugin.setSibilanceBandwidth(newValue)
                }
        }
    }

    private var playbackPreviewControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    startPreview()
                } label: {
                    Label(String(localized: "Test Playback", bundle: bundle), systemImage: "play.fill")
                }
                .disabled(isStartingPreview || modelState != .ready)

                Button {
                    plugin.stopSettingsPreview()
                } label: {
                    Label(String(localized: "Stop", bundle: bundle), systemImage: "stop.fill")
                }
                .disabled(modelState != .ready)
            }
            .controlSize(.small)

            if let previewError {
                Label(previewError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var expressionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Expression Tags", bundle: bundle)
                .font(.subheadline)
                .fontWeight(.medium)

            Toggle(isOn: $automaticExpressionTagsEnabled) {
                Text("Automatic Expression Tags", bundle: bundle)
            }
            .onChange(of: automaticExpressionTagsEnabled) { _, newValue in
                plugin.setAutomaticExpressionTagsEnabled(newValue)
            }

            Toggle(isOn: $breathBetweenSentencesEnabled) {
                Text("Add <breath> Between Sentences", bundle: bundle)
            }
            .disabled(!automaticExpressionTagsEnabled)
            .onChange(of: breathBetweenSentencesEnabled) { _, newValue in
                plugin.setBreathBetweenSentencesEnabled(newValue)
            }

            Toggle(isOn: $laughShorthandEnabled) {
                Text("Convert (lol) to <laugh>", bundle: bundle)
            }
            .disabled(!automaticExpressionTagsEnabled)
            .onChange(of: laughShorthandEnabled) { _, newValue in
                plugin.setLaughShorthandEnabled(newValue)
            }

            Toggle(isOn: $sighForEllipsesEnabled) {
                Text("Convert Ellipses to <sigh>", bundle: bundle)
            }
            .disabled(!automaticExpressionTagsEnabled)
            .onChange(of: sighForEllipsesEnabled) { _, newValue in
                plugin.setSighForEllipsesEnabled(newValue)
            }

            Text("Confirmed upstream tags: \(SupertonicExpressionSettings.confirmedTags.joined(separator: " "))")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func startPreview() {
        isStartingPreview = true
        previewError = nil
        Task {
            do {
                try await plugin.playSettingsPreview()
                await MainActor.run {
                    isStartingPreview = false
                }
            } catch {
                await MainActor.run {
                    isStartingPreview = false
                    previewError = error.localizedDescription
                }
            }
        }
    }

    private func refreshFromPlugin() {
        acceptedLicense = plugin.hasAcceptedCurrentModelLicense
        selectedVoiceId = plugin.selectedVoiceId ?? "M1"
        speed = plugin.selectedSpeed
        playbackRate = plugin.selectedPlaybackRate
        playbackPitchSemitones = plugin.selectedPlaybackPitchSemitones
        timePitchOverlap = plugin.selectedTimePitchOverlap
        lowPassEnabled = plugin.selectedLowPassEnabled
        lowPassCutoff = plugin.selectedLowPassCutoff
        resonanceEQEnabled = plugin.selectedResonanceEQEnabled
        resonanceEQFrequency = plugin.selectedResonanceEQFrequency
        resonanceEQGain = plugin.selectedResonanceEQGain
        resonanceEQBandwidth = plugin.selectedResonanceEQBandwidth
        clarityEnabled = plugin.selectedClarityEnabled
        clarityFrequency = plugin.selectedClarityFrequency
        clarityGain = plugin.selectedClarityGain
        sibilanceTamerEnabled = plugin.selectedSibilanceTamerEnabled
        sibilanceFrequency = plugin.selectedSibilanceFrequency
        sibilanceGain = plugin.selectedSibilanceGain
        sibilanceBandwidth = plugin.selectedSibilanceBandwidth
        automaticExpressionTagsEnabled = plugin.selectedAutomaticExpressionTagsEnabled
        breathBetweenSentencesEnabled = plugin.selectedBreathBetweenSentencesEnabled
        laughShorthandEnabled = plugin.selectedLaughShorthandEnabled
        sighForEllipsesEnabled = plugin.selectedSighForEllipsesEnabled
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
