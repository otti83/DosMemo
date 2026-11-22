import XCTest
import UniformTypeIdentifiers
@testable import DosMemo

final class TextIOTests: XCTestCase {
    func testUTF8RoundTripPreservesCRLF() throws {
        let original = Data("a\r\nb\r\n".utf8)
        let doc = try TextDocument(data: original)
        XCTAssertEqual(doc.text, "a\nb\n")
        XCTAssertEqual(doc.lineEnding, .crlf)
        XCTAssertEqual(doc.encoding, .utf8)
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testUTF16LittleEndianBOMIsNotDuplicated() throws {
        let original = Data([0xFF, 0xFE]) + "あ\n".data(using: .utf16LittleEndian)!
        let doc = try TextDocument(data: original)
        XCTAssertEqual(doc.text, "あ\n")
        XCTAssertEqual(doc.encoding, .utf16LittleEndian)
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testShiftJISDetection() throws {
        let original = "日本語テキスト\r\n".data(using: .shiftJIS)!
        let doc = try TextDocument(data: original)
        XCTAssertEqual(doc.encoding, .shiftJIS)
        XCTAssertEqual(doc.text, "日本語テキスト\n")
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testUnrepresentableCharactersThrowInsteadOfLosingData() {
        var doc = TextDocument(text: "絵文字😀")
        doc.encoding = .shiftJIS
        XCTAssertThrowsError(try doc.data(for: .plainText)) { error in
            guard case DosMemoError.unrepresentableCharacters = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testDetectLineEndings() {
        XCTAssertEqual(TextDecoder.detectLineEnding("a\nb"), .lf)
        XCTAssertEqual(TextDecoder.detectLineEnding("a\r\nb"), .crlf)
        XCTAssertEqual(TextDecoder.detectLineEnding("a\rb"), .cr)
        XCTAssertEqual(TextDecoder.detectLineEnding("a"), .lf)
    }
}

final class PropertyListTests: XCTestCase {
    private func binaryPlist(_ object: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    }

    func testBinaryPlistIsEditedAsXMLAndSavedAsBinary() throws {
        let original = try binaryPlist(["name": "DosMemo", "count": 3])
        var doc = try TextDocument(data: original)
        XCTAssertTrue(doc.isBinaryPropertyList)
        XCTAssertTrue(doc.text.contains("<key>name</key>"))

        doc.text = doc.text.replacingOccurrences(of: "DosMemo", with: "Edited")
        let saved = try doc.data(for: .propertyList)
        XCTAssertTrue(BinaryPropertyList.isBinary(saved))
        let decoded = try PropertyListSerialization.propertyList(from: saved, format: nil) as? [String: Any]
        XCTAssertEqual(decoded?["name"] as? String, "Edited")
        XCTAssertEqual(decoded?["count"] as? Int, 3)
    }

    func testInvalidBinaryPlistEditFailsToSave() throws {
        var doc = try TextDocument(data: try binaryPlist(["a": 1]))
        doc.text = "<plist><dict><key>broken"
        XCTAssertThrowsError(try doc.data(for: .propertyList)) { error in
            guard case DosMemoError.invalidPropertyList = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testBinaryPlistSavedAsPlainTextWritesXML() throws {
        let doc = try TextDocument(data: try binaryPlist(["a": 1]))
        let saved = try doc.data(for: .plainText)
        XCTAssertFalse(BinaryPropertyList.isBinary(saved))
        XCTAssertTrue(String(decoding: saved, as: UTF8.self).contains("<plist"))
    }

    func testXMLPlistStaysText() throws {
        let xml = try PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .xml, options: 0)
        let doc = try TextDocument(data: xml)
        XCTAssertFalse(doc.isBinaryPropertyList)
        XCTAssertEqual(try doc.data(for: .propertyList), xml)
    }
}

final class TextFormatTests: XCTestCase {
    func testCommonExtensionsAreWritable() {
        for ext in ["txt", "md", "json", "yaml", "xml", "plist", "html", "css", "js", "sh", "py", "csv", "tsv", "toml", "ini", "log", "swift"] {
            guard let type = UTType(filenameExtension: ext) else {
                XCTFail("no type for .\(ext)"); continue
            }
            XCTAssertTrue(TextFormat.writable.contains { type.conforms(to: $0) }, ".\(ext) (\(type.identifier)) is not writable")
        }
    }

    func testNewDocumentsDefaultToPlainText() {
        XCTAssertEqual(TextFormat.writable.first, .plainText)
    }
}

final class EditorMetricsTests: XCTestCase {
    func testCursorAndCounts() {
        let text = "ab\ncdé\n\nxyz" as NSString
        let metrics = EditorMetrics(string: text, selection: NSRange(location: 5, length: 3))
        XCTAssertEqual(metrics.cursorLine, 2)
        XCTAssertEqual(metrics.cursorColumn, 3)
        XCTAssertEqual(metrics.selectionLength, 3)
        XCTAssertEqual(metrics.characterCount, 11)
        XCTAssertEqual(metrics.lineCount, 4)
    }

    func testCursorAtEndOfLargeText() {
        let line = String(repeating: "あ", count: 50) + "\n"
        let text = String(repeating: line, count: 100_000) as NSString
        let metrics = EditorMetrics(string: text, selection: NSRange(location: text.length, length: 0))
        XCTAssertEqual(metrics.cursorLine, 100_001)
        XCTAssertEqual(metrics.cursorColumn, 1)
        XCTAssertEqual(metrics.lineCount, 100_001)
    }

    func testSelectionBeyondEndIsClamped() {
        let metrics = EditorMetrics(string: "abc", selection: NSRange(location: 10, length: 5))
        XCTAssertEqual(metrics.cursorColumn, 4)
        XCTAssertEqual(metrics.selectionLength, 0)
    }
}
