import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: TextDocument

    @State private var fontSize: CGFloat = AppSettings.shared.defaultFontSize
    @State private var fontName: String? = AppSettings.shared.fontName
    @State private var wordWrap: Bool = AppSettings.shared.wordWrap
    @State private var metrics = EditorMetrics()

    private struct FontChoice: Identifiable {
        let title: String
        let postScriptName: String?
        var id: String { postScriptName ?? "__system__" }
    }

    private let fontChoices: [FontChoice] = [
        FontChoice(title: L("toolbar.font.system"), postScriptName: nil),
        FontChoice(title: "Menlo", postScriptName: "Menlo-Regular"),
        FontChoice(title: "Monaco", postScriptName: "Monaco"),
        FontChoice(title: "Courier", postScriptName: "Courier"),
        FontChoice(title: "SF Mono", postScriptName: "SFMono-Regular"),
        FontChoice(title: "Hiragino Sans", postScriptName: "HiraginoSans-W3"),
        FontChoice(title: "Hiragino Mincho ProN", postScriptName: "HiraMinProN-W3"),
        FontChoice(title: "Helvetica", postScriptName: "Helvetica"),
    ]

    private let sizeChoices: [Int] = [10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 48]

    private let encodingTitles: [String.Encoding: String] = [
        .utf16LittleEndian: "UTF-16 LE (BOM)",
        .utf16BigEndian: "UTF-16 BE (BOM)",
    ]

    private let lineEndingTitleKeys: [LineEnding: String] = [
        .lf: "lineEnding.lf",
        .crlf: "lineEnding.crlf",
        .cr: "lineEnding.cr",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            TextEditorView(
                text: $document.text,
                fontSize: $fontSize,
                fontName: $fontName,
                wordWrap: $wordWrap,
                metrics: $metrics
            )

            StatusBar(
                line: metrics.cursorLine,
                col: metrics.cursorColumn,
                selectionCount: metrics.selectionLength,
                chars: metrics.characterCount,
                lines: metrics.lineCount,
                zoom: Int((fontSize / AppSettings.baseFontSize * 100).rounded()),
                lineEnding: document.lineEnding,
                encoding: document.encoding,
                isBinaryPropertyList: document.isBinaryPropertyList
            )
        }
        .toolbar {
            ToolbarItemGroup {
                fileMenu
                fontMenu
                Menu {
                    FindMenuItems(withShortcuts: false)
                } label: {
                    Label(L("toolbar.find"), systemImage: "magnifyingglass")
                }
                .help(L("toolbar.find.help"))
                encodingMenu

                Divider()

                Button { EditorCommand.zoomOut.post() } label: {
                    Label(L("toolbar.zoomOut"), systemImage: "minus.magnifyingglass")
                }
                .help(L("toolbar.zoomOut.help"))

                Button { EditorCommand.zoomIn.post() } label: {
                    Label(L("toolbar.zoomIn"), systemImage: "plus.magnifyingglass")
                }
                .help(L("toolbar.zoomIn.help"))

                Divider()

                Toggle(isOn: $wordWrap) {
                    Label(L("toolbar.wrap"), systemImage: "arrow.turn.down.left")
                }
                .toggleStyle(.button)
                .help(L("toolbar.wrap.help"))
                .onChange(of: wordWrap) { newValue in
                    AppSettings.shared.wordWrap = newValue
                }
            }
        }
    }

    private var fileMenu: some View {
        Menu {
            Button(L("menu.file.new"), action: DocumentActions.newDocument)
            Button(L("menu.file.open"), action: DocumentActions.openDocument)
            Divider()
            Button(L("menu.file.save"), action: DocumentActions.save)
            Button(L("menu.file.saveAs"), action: DocumentActions.saveAs)
        } label: {
            Label(L("toolbar.file"), systemImage: "folder")
        }
        .help(L("toolbar.file.help"))
    }

    private var fontMenu: some View {
        Menu {
            Section(L("toolbar.font.section")) {
                ForEach(fontChoices) { choice in
                    Button(choice.title) {
                        fontName = choice.postScriptName
                        AppSettings.shared.fontName = choice.postScriptName
                    }
                }
                Divider()
                Button(L("toolbar.font.other")) { EditorCommand.showFontPanel.post() }
            }
            Section(L("toolbar.size.section")) {
                ForEach(sizeChoices, id: \.self) { size in
                    Button("\(size) pt") {
                        fontSize = CGFloat(size)
                        AppSettings.shared.defaultFontSize = CGFloat(size)
                    }
                }
            }
        } label: {
            Label(L("toolbar.font"), systemImage: "textformat")
        }
        .help(L("toolbar.font.help"))
    }

    private var encodingMenu: some View {
        Menu {
            Section(L("toolbar.encoding.section")) {
                ForEach(TextEncodingInfo.choices, id: \.rawValue) { encoding in
                    checkmarkButton(encodingTitles[encoding] ?? TextEncodingInfo.label(for: encoding),
                                    checked: document.encoding == encoding) {
                        document.encoding = encoding
                    }
                }
            }
            Section(L("toolbar.lineEnding.section")) {
                ForEach(LineEnding.allCases, id: \.self) { ending in
                    checkmarkButton(L(lineEndingTitleKeys[ending] ?? ""), checked: document.lineEnding == ending) {
                        document.lineEnding = ending
                    }
                }
            }
        } label: {
            Label(L("toolbar.encoding"), systemImage: "doc.text")
        }
        .help(L("toolbar.encoding.help"))
        // Binary plists are always written as binary; encoding is irrelevant.
        .disabled(document.isBinaryPropertyList)
    }

    private func checkmarkButton(_ title: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if checked {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
