import SwiftUI

/// Editor, optional preview and status bar of one window. The toolbar and
/// menus live in EditorWindowController.
struct ContentView: View {
    @ObservedObject var model: DocumentModel
    @ObservedObject var state: EditorState

    /// Documents without a preview always show their source.
    private var effectiveLayout: EditorLayout {
        model.previewKind == nil ? .source : state.layout
    }

    var body: some View {
        VStack(spacing: 0) {
            // The editor stays first in the same container in every layout so
            // switching layouts never recreates it (which would drop undo
            // history and the caret position).
            HSplitView {
                ZStack {
                    TextEditorView(
                        text: $model.content.text,
                        fontSize: $state.fontSize,
                        fontName: state.fontName,
                        wordWrap: state.wordWrap,
                        metrics: $state.metrics,
                        isEditable: effectiveLayout != .preview
                    )
                    if effectiveLayout == .preview { preview }
                }
                .frame(minWidth: 200)
                if effectiveLayout == .split {
                    preview.frame(minWidth: 200)
                }
            }

            StatusBar(
                line: state.metrics.cursorLine,
                col: state.metrics.cursorColumn,
                selectionCount: state.metrics.selectionLength,
                chars: state.metrics.characterCount,
                lines: state.metrics.lineCount,
                zoom: Int((state.fontSize / AppSettings.baseFontSize * 100).rounded()),
                lineEnding: model.content.lineEnding,
                encoding: model.content.encoding,
                isBinaryPropertyList: model.content.isBinaryPropertyList
            )
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let kind = model.previewKind {
            DocumentPreview(kind: kind, text: model.content.text, fileURL: model.fileURL, fontSize: state.fontSize)
        }
    }
}
