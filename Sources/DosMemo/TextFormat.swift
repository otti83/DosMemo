import UniformTypeIdentifiers

/// The text-based file formats DosMemo opens and saves.
///
/// Types that macOS does not declare itself are imported in `Info.plist`
/// (`UTImportedTypeDeclarations`); keep the identifiers below in sync with it.
enum TextFormat {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    static let toml = UTType(importedAs: "public.toml", conformingTo: .plainText)
    static let ini = UTType(importedAs: "com.microsoft.ini", conformingTo: .plainText)
    /// `.conf` has no system type; without this it would be a dynamic type.
    static let conf = UTType(importedAs: "com.dosmemo.conf", conformingTo: .plainText)

    /// System-declared types that have no static member on `UTType`.
    private static let css = UTType("public.css")

    /// Formats offered in the Save panel, in display order. The first entry is
    /// the default for new documents.
    static let writable: [UTType] = [
        .plainText,
        markdown,
        .json,
        .yaml,
        .xml,
        .propertyList,
        .html,
        css,
        .javaScript,
        .shellScript,
        .pythonScript,
        .commaSeparatedText,
        .tabSeparatedText,
        toml,
        ini,
        conf,
        .log,
        .sourceCode,
    ].compactMap { $0 }

    /// Everything that can be opened. `.data` keeps files with unknown
    /// extensions (`.env`, `.gitignore`, …) openable as text.
    static let readable: [UTType] = writable + [.text, .utf8PlainText, .data]

    static func isPropertyList(_ type: UTType) -> Bool {
        type.conforms(to: .propertyList)
    }
}
