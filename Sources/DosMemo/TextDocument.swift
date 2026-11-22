import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { TextFormat.readable }
    static var writableContentTypes: [UTType] { TextFormat.writable }

    var text: String
    var encoding: String.Encoding
    var lineEnding: LineEnding
    /// The file was a binary property list; `text` holds its XML form.
    var isBinaryPropertyList: Bool

    init(text: String = "") {
        self.text = text
        self.encoding = .utf8
        self.lineEnding = .lf
        self.isBinaryPropertyList = false
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    init(data: Data) throws {
        if BinaryPropertyList.isBinary(data) {
            self.text = try BinaryPropertyList.xmlText(from: data)
            self.encoding = .utf8
            self.lineEnding = .lf
            self.isBinaryPropertyList = true
        } else {
            let result = TextDecoder.decode(data)
            self.text = result.text
            self.encoding = result.encoding
            self.lineEnding = result.lineEnding
            self.isBinaryPropertyList = false
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try data(for: configuration.contentType))
    }

    func data(for contentType: UTType) throws -> Data {
        // Saving a binary plist as e.g. .txt writes the XML text instead.
        if isBinaryPropertyList && TextFormat.isPropertyList(contentType) {
            return try BinaryPropertyList.binaryData(fromXMLText: text)
        }
        return try TextEncoder.encode(text, encoding: encoding, lineEnding: lineEnding)
    }
}
