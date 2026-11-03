import SwiftUI

struct StatusBar: View {
    let line: Int
    let col: Int
    let selectionCount: Int
    let chars: Int
    let lines: Int
    let zoom: Int
    let lineEnding: LineEnding
    let encoding: String.Encoding

    var body: some View {
        HStack(spacing: 12) {
            Text(L("status.position", formatted(line), formatted(col)))
            if selectionCount > 0 {
                Text(L("status.selection", formatted(selectionCount)))
            }
            Spacer(minLength: 12)
            Text(L("status.counts", formatted(chars), formatted(lines)))
            Divider().frame(height: 14)
            Text("\(zoom)%")
            Divider().frame(height: 14)
            Text(lineEndingLabel)
            Divider().frame(height: 14)
            Text(encodingLabel)
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }

    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var lineEndingLabel: String {
        switch lineEnding {
        case .lf:   return "LF"
        case .crlf: return "CRLF"
        case .cr:   return "CR"
        }
    }

    private var encodingLabel: String {
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
