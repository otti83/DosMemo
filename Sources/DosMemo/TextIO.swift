import Foundation

enum LineEnding {
    case lf, crlf, cr

    var raw: String {
        switch self {
        case .lf:   return "\n"
        case .crlf: return "\r\n"
        case .cr:   return "\r"
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
            if let s = String(data: data, encoding: .utf16LittleEndian) { return (s, .utf16LittleEndian) }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data, encoding: .utf16BigEndian) { return (s, .utf16BigEndian) }
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

    private static func detectLineEnding(_ text: String) -> LineEnding {
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
    static func encode(_ text: String, encoding: String.Encoding, lineEnding: LineEnding) -> Data {
        let translated: String
        switch lineEnding {
        case .lf:   translated = text
        case .crlf: translated = text.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:   translated = text.replacingOccurrences(of: "\n", with: "\r")
        }
        if let data = translated.data(using: encoding, allowLossyConversion: false) {
            if encoding == .utf16LittleEndian {
                return Data([0xFF, 0xFE]) + data
            }
            if encoding == .utf16BigEndian {
                return Data([0xFE, 0xFF]) + data
            }
            return data
        }
        // Fallback: lossy in target encoding, else UTF-8
        if let data = translated.data(using: encoding, allowLossyConversion: true) {
            return data
        }
        return Data(translated.utf8)
    }
}
