import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText, .text, .utf8PlainText, .log, .sourceCode, .json, .yaml, .xml, .html, .data]
    }

    static var writableContentTypes: [UTType] {
        [.plainText, .utf8PlainText]
    }

    var text: String
    var encoding: String.Encoding
    var lineEnding: LineEnding

    init() {
        self.text = ""
        self.encoding = .utf8
        self.lineEnding = .lf
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let result = TextDecoder.decode(data)
        self.text = result.text
        self.encoding = result.encoding
        self.lineEnding = result.lineEnding
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = TextEncoder.encode(text, encoding: encoding, lineEnding: lineEnding)
        return FileWrapper(regularFileWithContents: data)
    }
}
