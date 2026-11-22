import XCTest
import UniformTypeIdentifiers
@testable import DosMemo

final class TextIOTests: XCTestCase {
    func testUTF8RoundTripPreservesCRLF() throws {
        let original = Data("a\r\nb\r\n".utf8)
        let doc = try TextContent(data: original)
        XCTAssertEqual(doc.text, "a\nb\n")
        XCTAssertEqual(doc.lineEnding, .crlf)
        XCTAssertEqual(doc.encoding, .utf8)
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testUTF16LittleEndianBOMIsNotDuplicated() throws {
        let original = Data([0xFF, 0xFE]) + "あ\n".data(using: .utf16LittleEndian)!
        let doc = try TextContent(data: original)
        XCTAssertEqual(doc.text, "あ\n")
        XCTAssertEqual(doc.encoding, .utf16LittleEndian)
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testShiftJISDetection() throws {
        let original = "日本語テキスト\r\n".data(using: .shiftJIS)!
        let doc = try TextContent(data: original)
        XCTAssertEqual(doc.encoding, .shiftJIS)
        XCTAssertEqual(doc.text, "日本語テキスト\n")
        XCTAssertEqual(try doc.data(for: .plainText), original)
    }

    func testUnrepresentableCharactersThrowInsteadOfLosingData() {
        var doc = TextContent(text: "絵文字😀")
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
        var doc = try TextContent(data: original)
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
        var doc = try TextContent(data: try binaryPlist(["a": 1]))
        doc.text = "<plist><dict><key>broken"
        XCTAssertThrowsError(try doc.data(for: .propertyList)) { error in
            guard case DosMemoError.invalidPropertyList = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testBinaryPlistSavedAsPlainTextWritesXML() throws {
        let doc = try TextContent(data: try binaryPlist(["a": 1]))
        let saved = try doc.data(for: .plainText)
        XCTAssertFalse(BinaryPropertyList.isBinary(saved))
        XCTAssertTrue(String(decoding: saved, as: UTF8.self).contains("<plist"))
    }

    func testXMLPlistStaysText() throws {
        let xml = try PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .xml, options: 0)
        let doc = try TextContent(data: xml)
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

final class MarkdownRendererTests: XCTestCase {
    func testHeadingsAndEscapedCode() {
        let html = MarkdownRenderer.html(from: "# Title\n\nText with a < b & c\n\n```html\n<div>x</div>\n```\n")
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("a &lt; b &amp; c"))
        XCTAssertTrue(html.contains("&lt;div&gt;x&lt;/div&gt;"), html)
        XCTAssertTrue(html.contains("lang=\"html\""), html)
    }

    func testGitHubExtensions() {
        let html = MarkdownRenderer.html(from: "| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n\n~~gone~~ https://example.com\n")
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("type=\"checkbox\""))
        XCTAssertTrue(html.contains("<del>gone</del>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">"))
    }

    func testScriptTagsAreFiltered() {
        let html = MarkdownRenderer.html(from: "<script>alert(1)</script>\n\n<b>ok</b>\n")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("<b>ok</b>"))
    }

    func testJapaneseText() {
        XCTAssertTrue(MarkdownRenderer.html(from: "## 見出し\n本文").contains("<h2>見出し</h2>"))
    }
}

final class StructuredFormatTests: XCTestCase {
    func testJSONTree() throws {
        let root = try StructuredFormat.json.parse(#"{"b": [1, true, null], "a": {"x/y": "s"}}"#)
        XCTAssertEqual(root.kind, .dictionary)
        XCTAssertEqual(root.children?.map(\.key), ["a", "b"])
        let array = try XCTUnwrap(root.children?[1])
        XCTAssertEqual(array.children?.map(\.kind), [.number, .boolean, .null])
        XCTAssertEqual(array.children?.map(\.id), ["/b/0", "/b/1", "/b/2"])
        XCTAssertEqual(root.children?[0].children?[0].id, "/a/x~1y")
    }

    func testPropertyListTree() throws {
        let xml = try PropertyListSerialization.data(
            fromPropertyList: ["date": Date(timeIntervalSince1970: 0), "data": Data([1, 2]), "flag": false],
            format: .xml, options: 0)
        let root = try StructuredFormat.propertyList.parse(String(decoding: xml, as: UTF8.self))
        XCTAssertEqual(root.children?.map(\.kind), [.data, .date, .boolean])
        XCTAssertEqual(root.children?[1].value, "1970-01-01T00:00:00Z")
    }

    func testJSONSyntaxErrorReportsPosition() {
        XCTAssertThrowsError(try StructuredFormat.json.parse("{\n  \"a\": ,\n}")) { error in
            let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? ""
            XCTAssertTrue(detail.contains("line 2"), detail)
        }
    }
}

final class PreviewKindTests: XCTestCase {
    func testKindsByExtension() {
        XCTAssertEqual(PreviewKind(fileURL: URL(fileURLWithPath: "/a/README.md"), isBinaryPropertyList: false), .markdown)
        XCTAssertEqual(PreviewKind(fileURL: URL(fileURLWithPath: "/a/x.json"), isBinaryPropertyList: false), .tree(.json))
        XCTAssertEqual(PreviewKind(fileURL: URL(fileURLWithPath: "/a/Info.plist"), isBinaryPropertyList: false), .tree(.propertyList))
        XCTAssertNil(PreviewKind(fileURL: URL(fileURLWithPath: "/a/x.txt"), isBinaryPropertyList: false))
        XCTAssertNil(PreviewKind(fileURL: nil, isBinaryPropertyList: false))
        XCTAssertEqual(PreviewKind(fileURL: nil, isBinaryPropertyList: true), .tree(.propertyList))
    }
}

final class InfoPlistTests: XCTestCase {
    private let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")

    private var documentTypes: [[String: Any]] {
        let data = try! Data(contentsOf: resources.appendingPathComponent("Info.plist"))
        let plist = try! PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
        return plist["CFBundleDocumentTypes"] as! [[String: Any]]
    }

    /// NSDocument's File Format popup lists writable types by document type
    /// name; a duplicate name silently drops an entry and selects the wrong
    /// default format.
    func testEachWritableTypeHasAUniqueDocumentTypeName() {
        let names = TextFormat.writable.map { type in
            documentTypes.first { ($0["LSItemContentTypes"] as? [String])?.contains(type.identifier) == true }?["CFBundleTypeName"] as? String
        }
        XCTAssertFalse(names.contains(nil), "writable type without a document type")
        XCTAssertEqual(Set(names.compactMap { $0 }).count, names.count, "duplicate names: \(names)")
        XCTAssertEqual((documentTypes.first?["LSItemContentTypes"] as? [String])?.first, "public.plain-text",
                       "the first document type is the default for new documents")
    }

    func testDocumentTypeNamesAreLocalized() throws {
        for language in ["en", "ja", "fr", "de"] {
            let url = resources.appendingPathComponent("\(language).lproj/InfoPlist.strings")
            let strings = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            for type in documentTypes {
                let name = try XCTUnwrap(type["CFBundleTypeName"] as? String)
                XCTAssertNotNil(strings[name], "\(language): \(name)")
            }
        }
    }

    func testLocalizableStringsHaveTheSameKeys() throws {
        func keys(_ language: String) throws -> Set<String> {
            let url = resources.appendingPathComponent("\(language).lproj/Localizable.strings")
            return Set(try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String]).keys)
        }
        let english = try keys("en")
        for language in ["ja", "fr", "de"] {
            XCTAssertEqual(try keys(language), english, language)
        }
    }
}
