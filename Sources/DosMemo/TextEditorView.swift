import SwiftUI
import AppKit

struct TextEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var fontSize: CGFloat
    var fontName: String?
    var wordWrap: Bool
    @Binding var metrics: EditorMetrics
    /// False while the preview covers the editor, so hidden text can't be
    /// typed into or searched.
    var isEditable: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wordWrap
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        // Always-on legacy scrollers — overlay scrollers fade away even when
        // content overflows, which is confusing in a notepad.
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .allowed

        let textView = EditorTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
        // .height in the mask locks the textView to the scrollView's height,
        // which prevents the document from growing as text is added — the
        // result is no vertical scrollbar even for long text.
        textView.autoresizingMask = [.width]

        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.enabledTextCheckingTypes = 0
        textView.allowsCharacterPickerTouchBarItem = false

        textView.textContainerInset = NSSize(width: 6, height: 6)
        if let container = textView.textContainer {
            container.widthTracksTextView = wordWrap
            container.heightTracksTextView = false
            container.containerSize = NSSize(
                width: wordWrap ? max(scrollView.contentSize.width, 100) : CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        textView.font = Self.preferredFont(name: fontName, size: fontSize)
        textView.textColor = .textColor
        textView.string = text
        // Open with the caret at the top, like Notepad.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.delegate = context.coordinator

        textView.onZoom = { [weak coord = context.coordinator] delta in
            coord?.handleZoom(delta: delta)
        }

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        DispatchQueue.main.async {
            context.coordinator.recomputeMetrics()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        // CRITICAL: don't touch textView.string while an IME composition (marked
        // text) is in progress — doing so destroys the pre-edit buffer and the
        // user can't input Japanese / other CJK input. Only sync when nothing
        // is being composed.
        if !textView.hasMarkedText() && textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let len = (text as NSString).length
            let newRange = NSRange(
                location: min(selected.location, len),
                length: min(selected.length, max(0, len - min(selected.location, len)))
            )
            textView.setSelectedRange(newRange)
            textView.sizeToFit()
            context.coordinator.recomputeMetrics()
        }

        // Font is safe to update during composition.
        let targetFont = Self.preferredFont(name: fontName, size: fontSize)
        if textView.font?.fontName != targetFont.fontName || textView.font?.pointSize != targetFont.pointSize {
            textView.font = targetFont
        }

        context.coordinator.applyWordWrap(wordWrap)
        context.coordinator.applyEditable(isEditable)
    }

    static func preferredFont(name: String?, size: CGFloat) -> NSFont {
        if let name = name, !name.isEmpty, let f = NSFont(name: name, size: size) {
            return f
        }
        return NSFont.userFixedPitchFont(ofSize: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorView
        weak var textView: EditorTextView?
        weak var scrollView: NSScrollView?

        init(_ parent: TextEditorView) {
            self.parent = parent
            super.init()
        }

        /// ⌘/⌃-scroll and pinch zoom.
        func handleZoom(delta: CGFloat) {
            let size = parent.fontSize + delta
            let clamped = min(max(size, AppSettings.fontSizeRange.lowerBound), AppSettings.fontSizeRange.upperBound)
            if clamped != parent.fontSize { parent.fontSize = clamped }
        }

        // MARK: - Word wrap

        func applyWordWrap(_ wrap: Bool) {
            guard let textView = textView, let scrollView = scrollView, let container = textView.textContainer else { return }
            let visibleWidth = max(scrollView.contentSize.width, 100)
            if wrap {
                scrollView.hasHorizontalScroller = false
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                container.widthTracksTextView = true
                container.heightTracksTextView = false
                container.containerSize = NSSize(width: visibleWidth,
                                                  height: CGFloat.greatestFiniteMagnitude)
                var frame = textView.frame
                frame.size.width = visibleWidth
                textView.frame = frame
            } else {
                scrollView.hasHorizontalScroller = true
                textView.isHorizontallyResizable = true
                // Keep .height OUT of the mask so the document can grow with
                // text — otherwise NSTextView never lays out lines beyond the
                // initial visible height and the vertical scrollbar never appears.
                textView.autoresizingMask = [.width]
                container.widthTracksTextView = false
                container.heightTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)
            }
            textView.layoutManager?.ensureLayout(for: container)
            textView.sizeToFit()
            textView.needsDisplay = true
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Skip propagating the binding while IME composition is active.
            // Re-rendering SwiftUI during composition wipes out the marked text.
            if textView.hasMarkedText() {
                recomputeMetrics()
                return
            }
            parent.text = textView.string
            recomputeMetrics()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Avoid triggering re-render storms while IME is composing — the
            // selection moves a lot inside the marked range.
            if textView.hasMarkedText() { return }
            recomputeMetrics()
        }

        // MARK: - Editability

        func applyEditable(_ editable: Bool) {
            guard let textView, textView.isEditable != editable else { return }
            textView.isEditable = editable
            textView.isSelectable = editable
            guard let window = textView.window else { return }
            if editable {
                window.makeFirstResponder(textView)
            } else if window.firstResponder === textView {
                window.makeFirstResponder(nil)
            }
        }

        // MARK: - Status bar metrics

        func recomputeMetrics() {
            guard let textView = textView else { return }
            let metrics = EditorMetrics(string: textView.string as NSString, selection: textView.selectedRange())
            if metrics != parent.metrics { parent.metrics = metrics }
        }
    }
}
