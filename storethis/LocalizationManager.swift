import Foundation
import Observation

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            updateBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    init() {
        currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        updateBundle()
    }

    private func updateBundle() {
        if currentLanguage == "system" {
            bundle = .main
        } else if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
                  let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }

    /// Available language options for the picker
    static let availableLanguages: [(code: String, key: String)] = [
        ("system", "settings.languageSystemDefault"),
        ("en", "settings.languageEnglish"),
        ("es", "settings.languageSpanish"),
        ("fr", "settings.languageFrench"),
    ]
}
