import Foundation

/// Look up a localized string from the app bundle (`Contents/Resources/*.lproj`).
///
/// The strings deliberately live in the main bundle rather than an SwiftPM
/// resource bundle: SwiftPM's generated `Bundle.module` accessor looks for the
/// bundle at the `.app` root (where code signing forbids unsealed content) and
/// otherwise falls back to an absolute build-machine path, calling
/// `fatalError` when neither exists. That crashed DosMemo 1.0 at launch on
/// every Mac except the one that built it.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
