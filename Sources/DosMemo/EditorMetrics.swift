import Foundation

/// Cursor position and document counts shown in the status bar.
struct EditorMetrics: Equatable {
    var cursorLine = 1
    var cursorColumn = 1
    var selectionLength = 0
    var characterCount = 0
    var lineCount = 1

    /// Computes metrics from the editor's backing string. Line counting scans
    /// UTF-16 code units in bulk because this runs on every keystroke and
    /// selection change, and per-character `character(at:)` calls made large
    /// files sluggish.
    init(string: NSString, selection: NSRange) {
        let length = string.length
        let location = min(selection.location, length)
        let lineStart = string.lineRange(for: NSRange(location: location, length: 0)).location
        cursorLine = Self.countNewlines(in: string, range: NSRange(location: 0, length: lineStart)) + 1
        cursorColumn = location - lineStart + 1

        let selected = NSRange(location: location, length: min(selection.length, length - location))
        selectionLength = selected.length > 0 ? (string.substring(with: selected) as String).count : 0

        characterCount = (string as String).count
        lineCount = Self.countNewlines(in: string, range: NSRange(location: 0, length: length)) + 1
    }

    init() {}

    static func countNewlines(in string: NSString, range: NSRange) -> Int {
        let chunkSize = 64 * 1024
        var buffer = [unichar](repeating: 0, count: chunkSize)
        var count = 0
        var position = range.location
        let end = NSMaxRange(range)
        while position < end {
            let length = min(chunkSize, end - position)
            buffer.withUnsafeMutableBufferPointer { ptr in
                string.getCharacters(ptr.baseAddress!, range: NSRange(location: position, length: length))
                for i in 0..<length where ptr[i] == 0x0A { count += 1 }
            }
            position += length
        }
        return count
    }
}
