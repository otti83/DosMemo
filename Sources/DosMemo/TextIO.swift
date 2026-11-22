import Foundation

enum LineEnding: CaseIterable {
    case lf, crlf, cr

    var raw: String {
        switch self {
        case .lf:   return "\n"
        case .crlf: return "\r\n"
        case .cr:   return "\r"
        }
    }

    var label: String {
        switch self {
        case .lf:   return "LF"
        case .crlf: return "CRLF"
        case .cr:   return "CR"
        }
    }
}

struct TextDecodeResult {
    let text: String
    let encoding: String.Encoding
    let lineEnding: LineEnding
}

enum TextDecoder {
    static func decode(_ data: Data) -> TextDecodeResult {
        let (raw, encoding) = decodeBytes(data)
        let lineEnding = detectLineEnding(raw)
        let normalized = normalizeNewlines(raw)
        return TextDecodeResult(text: normalized, encoding: encoding, lineEnding: lineEnding)
    }

    private static func decodeBytes(_ data: Data) -> (String, String.Encoding) {
        if data.isEmpty { return ("", .utf8) }

        // BOM detection
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            if let s = String(data: data.dropFirst(3), encoding: .utf8) { return (s, .utf8) }
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) { return (s, .utf16LittleEndian) }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) { return (s, .utf16BigEndian) }
        }

        // Try UTF-8 strict
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }
        // Try common Japanese encodings (Windows メモ帳互換)
        if let s = String(data: data, encoding: .shiftJIS) { return (s, .shiftJIS) }
        if let s = String(data: data, encoding: .japaneseEUC) { return (s, .japaneseEUC) }
        // UTF-16 without BOM
        if let s = String(data: data, encoding: .utf16) { return (s, .utf16) }
        // Fallback
        return (String(data: data, encoding: .isoLatin1) ?? "", .isoLatin1)
    }

    static func detectLineEnding(_ text: String) -> LineEnding {
        // Iterate unicode scalars so CRLF is seen as two distinct scalars,
        // not a single grapheme cluster.
        var prev: Unicode.Scalar? = nil
        for ch in text.unicodeScalars {
            if ch.value == 0x0A {
                return (prev?.value == 0x0D) ? .crlf : .lf
            }
            if prev?.value == 0x0D { return .cr }
            prev = ch
        }
        return (prev?.value == 0x0D) ? .cr : .lf
    }

    private static func normalizeNewlines(_ text: String) -> String {
        // Normalize all newline styles to LF for internal use
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        return s
    }
}

enum TextEncoder {
    /// Encodes `text` for saving. Throws instead of silently replacing
    /// characters the target encoding cannot represent (e.g. emoji in
    /// Shift_JIS), so a save never loses data without the user knowing.
    static func encode(_ text: String, encoding: String.Encoding, lineEnding: LineEnding) throws -> Data {
        let translated = lineEnding == .lf
            ? text
            : text.replacingOccurrences(of: "\n", with: lineEnding.raw)
        guard let data = translated.data(using: encoding, allowLossyConversion: false) else {
            throw DosMemoError.unrepresentableCharacters(encodingName: TextEncodingInfo.label(for: encoding))
        }
        switch encoding {
        case .utf16LittleEndian: return Data([0xFF, 0xFE]) + data
        case .utf16BigEndian:    return Data([0xFE, 0xFF]) + data
        default:                 return data   // `.utf16` already writes its own BOM
        }
    }
}

enum TextEncodingInfo {
    /// Encodings selectable for saving, in menu order.
    static let choices: [String.Encoding] = [.utf8, .utf16LittleEndian, .utf16BigEndian, .shiftJIS, .japaneseEUC]

    static func label(for encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8:              return "UTF-8"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian:    return "UTF-16 BE"
        case .utf16:             return "UTF-16"
        case .shiftJIS:          return "Shift_JIS"
        case .japaneseEUC:       return "EUC-JP"
        case .isoLatin1:         return "ISO Latin-1"
        case .ascii:             return "ASCII"
        default:                 return "Unknown"
        }
    }
}

/// Binary property lists are not text; DosMemo edits them as XML and writes
/// them back in binary form so files such as `Info.plist` caches or
/// preference files keep their original format.
enum BinaryPropertyList {
    static func isBinary(_ data: Data) -> Bool {
        data.starts(with: Array("bplist".utf8))
    }

    static func xmlText(from data: Data) throws -> String {
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let xml = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        return String(decoding: xml, as: UTF8.self)
    }

    static func binaryData(fromXMLText text: String) throws -> Data {
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: Data(text.utf8), options: [], format: nil)
        } catch {
            throw DosMemoError.invalidPropertyList(underlying: error)
        }
        return try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    }
}

enum DosMemoError: LocalizedError {
    case unrepresentableCharacters(encodingName: String)
    case invalidPropertyList(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unrepresentableCharacters(let name): return L("error.encoding.lossy", name)
        case .invalidPropertyList:                 return L("error.plist.invalid")
        }
    }

    var failureReason: String? {
        switch self {
        case .unrepresentableCharacters:           return L("error.encoding.lossy.reason")
        case .invalidPropertyList(let underlying): return (underlying as NSError).localizedDescription
        }
    }
}
