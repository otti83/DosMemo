import Foundation

final class AppSettings {
    static let shared = AppSettings()
    static let baseFontSize: CGFloat = 14
    static let fontSizeRange: ClosedRange<CGFloat> = 8...72

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
            let v = CGFloat(defaults.double(forKey: Keys.fontSize))
            return Self.fontSizeRange.contains(v) ? v : Self.baseFontSize
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
