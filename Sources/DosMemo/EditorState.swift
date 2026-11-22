import AppKit
import Combine

/// Observable document contents shared by the NSDocument and its SwiftUI view.
final class DocumentModel: ObservableObject {
    @Published var content = TextContent()
    @Published var fileURL: URL?

    var previewKind: PreviewKind? {
        PreviewKind(fileURL: fileURL, isBinaryPropertyList: content.isBinaryPropertyList)
    }
}

/// Per-window view settings. Changes are remembered as the default for new
/// windows.
final class EditorState: ObservableObject {
    @Published var fontSize = AppSettings.shared.defaultFontSize {
        didSet { AppSettings.shared.defaultFontSize = fontSize }
    }
    @Published var fontName = AppSettings.shared.fontName {
        didSet { AppSettings.shared.fontName = fontName }
    }
    @Published var wordWrap = AppSettings.shared.wordWrap {
        didSet { AppSettings.shared.wordWrap = wordWrap }
    }
    @Published var layout = AppSettings.shared.editorLayout {
        didSet { AppSettings.shared.editorLayout = layout }
    }
    @Published var metrics = EditorMetrics()

    var font: NSFont { TextEditorView.preferredFont(name: fontName, size: fontSize) }

    func setFontSize(_ size: CGFloat) {
        let clamped = min(max(size, AppSettings.fontSizeRange.lowerBound), AppSettings.fontSizeRange.upperBound)
        if clamped != fontSize { fontSize = clamped }
    }
}
