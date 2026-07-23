//
//  AppSettings.swift
//  PetApp
//
//  App-wide user preferences. Persisted to UserDefaults and applied at the
//  root so changes to text size, theme, and language take effect everywhere.
//

import SwiftUI
import Combine

// MARK: - Preference value types

enum AppTextSize: String, CaseIterable, Codable {
    case small, medium, large

    /// The Dynamic Type size the whole app is clamped to for this choice.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small:  return .large
        case .medium: return .xLarge
        case .large:  return .xxxLarge
        }
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case light, dark

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french  = "fr"
    case hindi   = "hi"
    case mandarin = "zh"

    var id: String { rawValue }

    /// Short label shown in the compact selector (e.g. "Eng").
    var shortLabel: String {
        switch self {
        case .english:  return "Eng"
        case .spanish:  return "Esp"
        case .french:   return "Fra"
        case .hindi:    return "हिं"
        case .mandarin: return "中文"
        }
    }

    var displayName: String {
        switch self {
        case .english:  return "English"
        case .spanish:  return "Español"
        case .french:   return "Français"
        case .hindi:    return "हिन्दी"
        case .mandarin: return "中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// BCP-47 locale used for speech recognition (transcribing recordings).
    /// Region-qualified so `SFSpeechRecognizer` reliably finds a dictation model.
    var speechLocaleIdentifier: String {
        switch self {
        case .english:  return "en-US"
        case .spanish:  return "es-ES"
        case .french:   return "fr-FR"
        case .hindi:    return "hi-IN"
        case .mandarin: return "zh-CN"
        }
    }

    /// The `.lproj` bundle for this language, so text can be localized to the
    /// *in-app* selected language regardless of the device's system language.
    /// Falls back to the main bundle if the language isn't compiled in.
    var bundle: Bundle {
        Bundle.main.path(forResource: rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
    }

    /// Resolves `englishText` to the wording (and the BCP-47 language it should
    /// be *voiced* in) for this app language.
    ///
    /// If a translation exists in the selected language's catalog, that wording
    /// is spoken in that language. If none exists, the original English text is
    /// returned to be voiced in English — so read-aloud never reads English
    /// words with a foreign accent.
    func spoken(_ englishText: String) -> (text: String, voiceLanguage: String) {
        guard self != .english else { return (englishText, "en") }
        let translated = NSLocalizedString(englishText,
                                           bundle: bundle,
                                           value: englishText,
                                           comment: "")
        return translated == englishText ? (englishText, "en")
                                         : (translated, rawValue)
    }
}

// MARK: - Settings store

@MainActor
final class AppSettings: ObservableObject {

    private let defaults = UserDefaults.standard

    @Published var name: String {
        didSet { defaults.set(name, forKey: Keys.name) }
    }
    @Published var birthday: Date {
        didSet { defaults.set(birthday.timeIntervalSince1970, forKey: Keys.birthday) }
    }
    @Published var lockScreenNotifications: Bool {
        didSet { defaults.set(lockScreenNotifications, forKey: Keys.lockNotif) }
    }
    @Published var textToVoice: Bool {
        didSet { defaults.set(textToVoice, forKey: Keys.textToVoice) }
    }
    @Published var textSize: AppTextSize {
        didSet { defaults.set(textSize.rawValue, forKey: Keys.textSize) }
    }
    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }
    /// Speech rate for text-to-voice, 0...1 (maps to AVSpeechUtterance rate).
    @Published var voiceSpeed: Double {
        didSet { defaults.set(voiceSpeed, forKey: Keys.voiceSpeed) }
    }

    init() {
        name = defaults.string(forKey: Keys.name) ?? ""

        let stored = defaults.double(forKey: Keys.birthday)
        birthday = stored > 0
            ? Date(timeIntervalSince1970: stored)
            : AppSettings.defaultBirthday

        lockScreenNotifications = defaults.object(forKey: Keys.lockNotif) as? Bool ?? true
        textToVoice = defaults.object(forKey: Keys.textToVoice) as? Bool ?? false

        textSize = AppTextSize(rawValue: defaults.string(forKey: Keys.textSize) ?? "")
            ?? .medium
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "")
            ?? .light
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "")
            ?? .english
        voiceSpeed = defaults.object(forKey: Keys.voiceSpeed) as? Double ?? 0.5
    }

    /// Seeds the display name from onboarding if the user hasn't set one yet.
    func seedNameIfEmpty(_ candidate: String) {
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        if name.isEmpty && !trimmed.isEmpty {
            name = trimmed
        }
    }

    private static var defaultBirthday: Date {
        var components = DateComponents()
        components.year = 1955
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    private enum Keys {
        static let name = "settings.name"
        static let birthday = "settings.birthday"
        static let lockNotif = "settings.lockScreenNotifications"
        static let textToVoice = "settings.textToVoice"
        static let textSize = "settings.textSize"
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let voiceSpeed = "settings.voiceSpeed"
    }
}
