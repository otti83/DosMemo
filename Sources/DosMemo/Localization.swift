import Foundation
import SwiftUI

/// Look up a localized string from the SPM resource bundle.
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, value: key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: .module, value: key, comment: "")
    return String(format: format, arguments: args)
}

extension Text {
    /// SwiftUI Text that resolves the key against the SPM bundle.
    init(localized key: String) {
        self.init(LocalizedStringKey(key), bundle: .module)
    }
}
