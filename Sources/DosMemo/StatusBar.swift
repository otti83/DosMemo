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
    let isBinaryPropertyList: Bool

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Text(L("status.position", formatted(line), formatted(col)))
            if selectionCount > 0 {
                Text(L("status.selection", formatted(selectionCount)))
            }
            Spacer(minLength: 12)
            Text(L("status.counts", formatted(chars), formatted(lines)))
            separator
            Text("\(zoom)%")
            separator
            if isBinaryPropertyList {
                Text(L("status.binaryPlist"))
            } else {
                Text(lineEnding.label)
                separator
                Text(TextEncodingInfo.label(for: encoding))
            }
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

    private var separator: some View {
        Divider().frame(height: 14)
    }

    private func formatted(_ n: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
