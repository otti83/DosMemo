import SwiftUI
import AppKit

struct TextEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var fontSize: CGFloat
    @Binding var fontName: String?
    @Binding var wordWrap: Bool
    @Binding var cursorLine: Int
    @Binding var cursorCol: Int
    @Binding var charCount: Int
    @Binding var lineCount: Int
    @Binding var selectionCount: Int

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
        textView.delegate = context.coordinator

        textView.onZoom = { [weak coord = context.coordinator] delta in
            coord?.handleZoom(delta: delta)
        }

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.installNotificationObservers()
        DispatchQueue.main.async {
            context.coordinator.recomputeAll()
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
            context.coordinator.recomputeAll()
        }

        // Font is safe to update during composition.
        let targetFont = Self.preferredFont(name: fontName, size: fontSize)
        if textView.font?.fontName != targetFont.fontName || textView.font?.pointSize != targetFont.pointSize {
            textView.font = targetFont
        }

        context.coordinator.applyWordWrap(wordWrap)
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

        private var observers: [NSObjectProtocol] = []

        init(_ parent: TextEditorView) {
            self.parent = parent
            super.init()
        }

        deinit {
            for o in observers { NotificationCenter.default.removeObserver(o) }
            NSFontManager.shared.target = nil
        }

        // MARK: - Notification hooks (menu actions)

        func installNotificationObservers() {
            let nc = NotificationCenter.default
            observers.append(nc.addObserver(forName: .dmZoomIn,    object: nil, queue: .main) { [weak self] _ in self?.menuZoomIn() })
            observers.append(nc.addObserver(forName: .dmZoomOut,   object: nil, queue: .main) { [weak self] _ in self?.menuZoomOut() })
            observers.append(nc.addObserver(forName: .dmZoomReset, object: nil, queue: .main) { [weak self] _ in self?.menuZoomReset() })
            observers.append(nc.addObserver(forName: .dmShowFont,  object: nil, queue: .main) { [weak self] _ in self?.menuShowFontPanel() })
            observers.append(nc.addObserver(forName: .dmToggleWrap, object: nil, queue: .main) { [weak self] _ in self?.menuToggleWordWrap() })
            observers.append(nc.addObserver(forName: .dmFind,             object: nil, queue: .main) { [weak self] _ in self?.performFinder(.showFindInterface) })
            observers.append(nc.addObserver(forName: .dmReplace,          object: nil, queue: .main) { [weak self] _ in self?.performFinder(.showReplaceInterface) })
            observers.append(nc.addObserver(forName: .dmFindNext,         object: nil, queue: .main) { [weak self] _ in self?.performFinder(.nextMatch) })
            observers.append(nc.addObserver(forName: .dmFindPrev,         object: nil, queue: .main) { [weak self] _ in self?.performFinder(.previousMatch) })
            observers.append(nc.addObserver(forName: .dmFindSetSelection, object: nil, queue: .main) { [weak self] _ in self?.performFinder(.setSearchString) })
        }

        private func performFinder(_ action: NSTextFinder.Action) {
            guard isOurWindowActive, let textView = textView else { return }
            let item = NSMenuItem()
            item.tag = action.rawValue
            textView.performTextFinderAction(item)
        }

        private var isOurWindowActive: Bool {
            textView?.window?.isKeyWindow ?? false
        }

        private func menuZoomIn()    { if isOurWindowActive { handleZoom(delta: 1) } }
        private func menuZoomOut()   { if isOurWindowActive { handleZoom(delta: -1) } }
        private func menuZoomReset() { if isOurWindowActive { setFontSize(14) } }
        private func menuToggleWordWrap() { if isOurWindowActive { parent.wordWrap.toggle(); AppSettings.shared.wordWrap = parent.wordWrap } }

        private func menuShowFontPanel() {
            guard isOurWindowActive, let textView = textView else { return }
            let manager = NSFontManager.shared
            manager.setSelectedFont(textView.font ?? .systemFont(ofSize: parent.fontSize), isMultiple: false)
            manager.target = self
            manager.action = #selector(changeFont(_:))
            NSFontPanel.shared.makeKeyAndOrderFront(nil)
        }

        @objc func changeFont(_ sender: Any?) {
            let manager = (sender as? NSFontManager) ?? NSFontManager.shared
            guard let textView = textView else { return }
            let current = textView.font ?? .systemFont(ofSize: parent.fontSize)
            let new = manager.convert(current)
            let clamped = max(8, min(72, new.pointSize))
            let finalFont = (clamped == new.pointSize)
                ? new
                : NSFontManager.shared.convert(new, toSize: clamped)
            textView.font = finalFont
            parent.fontName = finalFont.fontName
            parent.fontSize = finalFont.pointSize
            AppSettings.shared.fontName = finalFont.fontName
            AppSettings.shared.defaultFontSize = finalFont.pointSize
        }

        // MARK: - Zoom

        func handleZoom(delta: CGFloat) {
            setFontSize(parent.fontSize + delta)
        }

        private func setFontSize(_ size: CGFloat) {
            let clamped = max(8, min(72, size))
            guard clamped != parent.fontSize else { return }
            parent.fontSize = clamped
            AppSettings.shared.defaultFontSize = clamped
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
                recomputeAll()
                return
            }
            parent.text = textView.string
            recomputeAll()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Avoid triggering re-render storms while IME is composing — the
            // selection moves a lot inside the marked range.
            if textView.hasMarkedText() { return }
            recomputeCursor()
        }

        // MARK: - Counts

        func recomputeAll() {
            recomputeCounts()
            recomputeCursor()
        }

        private func recomputeCounts() {
            guard let textView = textView else { return }
            let text = textView.string
            parent.charCount = text.count
            var lines = 1
            for scalar in text.unicodeScalars where scalar.value == 0x0A {
                lines += 1
            }
            parent.lineCount = lines
        }

        private func recomputeCursor() {
            guard let textView = textView else { return }
            let str = textView.string as NSString
            let range = textView.selectedRange()
            let loc = min(range.location, str.length)

            var line = 1
            var lineStart = 0
            var i = 0
            while i < loc {
                if str.character(at: i) == 0x0A {
                    line += 1
                    lineStart = i + 1
                }
                i += 1
            }
            parent.cursorLine = line
            parent.cursorCol = loc - lineStart + 1

            if range.length > 0 {
                let sel = str.substring(with: range)
                parent.selectionCount = sel.count
            } else {
                parent.selectionCount = 0
            }
        }
    }
}

extension Notification.Name {
    static let dmZoomIn     = Notification.Name("DosMemo.zoomIn")
    static let dmZoomOut    = Notification.Name("DosMemo.zoomOut")
    static let dmZoomReset  = Notification.Name("DosMemo.zoomReset")
    static let dmShowFont   = Notification.Name("DosMemo.showFontPanel")
    static let dmToggleWrap = Notification.Name("DosMemo.toggleWrap")
    static let dmFind             = Notification.Name("DosMemo.find")
    static let dmReplace          = Notification.Name("DosMemo.replace")
    static let dmFindNext         = Notification.Name("DosMemo.findNext")
    static let dmFindPrev         = Notification.Name("DosMemo.findPrev")
    static let dmFindSetSelection = Notification.Name("DosMemo.findSetSelection")
}
