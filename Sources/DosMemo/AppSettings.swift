import Foundation

final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let fontSize = "fontSize"
        static let wordWrap = "wordWrap"
        static let fontName = "fontName"
    }

    var fontName: String? {
        get { defaults.string(forKey: Keys.fontName) }
        set { defaults.set(newValue, forKey: Keys.fontName) }
    }

    var defaultFontSize: CGFloat {
        get {
            let v = defaults.double(forKey: Keys.fontSize)
            return v >= 8 ? CGFloat(v) : 14
        }
        set { defaults.set(Double(newValue), forKey: Keys.fontSize) }
    }

    var wordWrap: Bool {
        get {
            if defaults.object(forKey: Keys.wordWrap) == nil { return true }
            return defaults.bool(forKey: Keys.wordWrap)
        }
        set { defaults.set(newValue, forKey: Keys.wordWrap) }
    }
}
