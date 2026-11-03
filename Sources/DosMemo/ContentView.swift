import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: TextDocument

    @State private var fontSize: CGFloat = AppSettings.shared.defaultFontSize
    @State private var fontName: String? = AppSettings.shared.fontName
    @State private var wordWrap: Bool = AppSettings.shared.wordWrap

    @State private var cursorLine: Int = 1
    @State private var cursorCol: Int = 1
    @State private var charCount: Int = 0
    @State private var lineCount: Int = 1
    @State private var selectionCount: Int = 0

    private struct FontChoice: Identifiable {
        let id: String
        let displayKey: String   // localization key, or nil-meaning literal
        let literal: String?
        let psName: String?
        init(key: String, ps: String?) {
            self.id = ps ?? "__system__"
            self.displayKey = key
            self.literal = nil
            self.psName = ps
        }
        init(literal: String, ps: String?) {
            self.id = ps ?? literal
            self.displayKey = ""
            self.literal = literal
            self.psName = ps
        }
    }

    private let fontChoices: [FontChoice] = [
        FontChoice(key: "toolbar.font.system", ps: nil),
        FontChoice(literal: "Menlo", ps: "Menlo-Regular"),
        FontChoice(literal: "Monaco", ps: "Monaco"),
        FontChoice(literal: "Courier", ps: "Courier"),
        FontChoice(literal: "SF Mono", ps: "SFMono-Regular"),
        FontChoice(literal: "Hiragino Sans", ps: "HiraginoSans-W3"),
        FontChoice(literal: "Hiragino Mincho ProN", ps: "HiraMinProN-W3"),
        FontChoice(literal: "Helvetica", ps: "Helvetica"),
    ]

    private let sizeChoices: [Int] = [10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 48]

    private let encodingChoices: [(String, String.Encoding)] = [
        ("UTF-8", .utf8),
        ("UTF-16 LE (BOM)", .utf16LittleEndian),
        ("UTF-16 BE (BOM)", .utf16BigEndian),
        ("Shift_JIS", .shiftJIS),
        ("EUC-JP", .japaneseEUC),
    ]

    private let lineEndingChoices: [(String, LineEnding)] = [
        ("lineEnding.lf", .lf),
        ("lineEnding.crlf", .crlf),
        ("lineEnding.cr", .cr),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            TextEditorView(
                text: $document.text,
                fontSize: $fontSize,
                fontName: $fontName,
                wordWrap: $wordWrap,
                cursorLine: $cursorLine,
                cursorCol: $cursorCol,
                charCount: $charCount,
                lineCount: $lineCount,
                selectionCount: $selectionCount
            )

            StatusBar(
                line: cursorLine,
                col: cursorCol,
                selectionCount: selectionCount,
                chars: charCount,
                lines: lineCount,
                zoom: Int((fontSize / 14.0 * 100).rounded()),
                lineEnding: document.lineEnding,
                encoding: document.encoding
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button(L("menu.file.new")) {
                        NSDocumentController.shared.newDocument(nil)
                    }
                    Button(L("menu.file.open")) {
                        NSDocumentController.shared.openDocument(nil)
                    }
                    Divider()
                    Button(L("menu.file.save")) {
                        NSApp.sendAction(NSSelectorFromString("saveDocument:"), to: nil, from: nil)
                    }
                    Button(L("menu.file.saveAs")) {
                        NSApp.sendAction(NSSelectorFromString("saveDocumentAs:"), to: nil, from: nil)
                    }
                } label: {
                    Label(L("toolbar.file"), systemImage: "folder")
                }
                .help(L("toolbar.file.help"))

                Menu {
                    Section(L("toolbar.font.section")) {
                        ForEach(fontChoices) { choice in
                            Button(choice.literal ?? L(choice.displayKey)) {
                                fontName = choice.psName
                                AppSettings.shared.fontName = choice.psName
                            }
                        }
                        Divider()
                        Button(L("toolbar.font.other")) {
                            NotificationCenter.default.post(name: .dmShowFont, object: nil)
                        }
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

                Menu {
                    Button(L("menu.find.find")) {
                        NotificationCenter.default.post(name: .dmFind, object: nil)
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    Button(L("menu.find.replace")) {
                        NotificationCenter.default.post(name: .dmReplace, object: nil)
                    }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                    Divider()
                    Button(L("menu.find.next")) {
                        NotificationCenter.default.post(name: .dmFindNext, object: nil)
                    }
                    .keyboardShortcut("g", modifiers: .command)
                    Button(L("menu.find.previous")) {
                        NotificationCenter.default.post(name: .dmFindPrev, object: nil)
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    Button(L("menu.find.useSelection")) {
                        NotificationCenter.default.post(name: .dmFindSetSelection, object: nil)
                    }
                    .keyboardShortcut("e", modifiers: .command)
                } label: {
                    Label(L("toolbar.find"), systemImage: "magnifyingglass")
                }
                .help(L("toolbar.find.help"))

                Menu {
                    Section(L("toolbar.encoding.section")) {
                        ForEach(Array(encodingChoices.enumerated()), id: \.offset) { _, item in
                            Button {
                                document.encoding = item.1
                            } label: {
                                if document.encoding == item.1 {
                                    Label(item.0, systemImage: "checkmark")
                                } else {
                                    Text(item.0)
                                }
                            }
                        }
                    }
                    Section(L("toolbar.lineEnding.section")) {
                        ForEach(Array(lineEndingChoices.enumerated()), id: \.offset) { _, item in
                            Button {
                                document.lineEnding = item.1
                            } label: {
                                if document.lineEnding == item.1 {
                                    Label(L(item.0), systemImage: "checkmark")
                                } else {
                                    Text(L(item.0))
                                }
                            }
                        }
                    }
                } label: {
                    Label(L("toolbar.encoding"), systemImage: "doc.text")
                }
                .help(L("toolbar.encoding.help"))

                Divider()

                Button {
                    NotificationCenter.default.post(name: .dmZoomOut, object: nil)
                } label: {
                    Label(L("toolbar.zoomOut"), systemImage: "minus.magnifyingglass")
                }
                .help(L("toolbar.zoomOut.help"))

                Button {
                    NotificationCenter.default.post(name: .dmZoomIn, object: nil)
                } label: {
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
}
