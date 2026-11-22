import AppKit
import UniformTypeIdentifiers

/// A text file. Documents save only when asked (no autosave-in-place), like
/// Notepad, so closing an edited document asks a plain
/// Save / Don't Save / Cancel question.
@objc(TextFileDocument)
final class TextFileDocument: NSDocument {
    let model = DocumentModel()

    override class var autosavesInPlace: Bool { false }

    override class var writableTypes: [String] { TextFormat.writable.map(\.identifier) }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        Self.writableTypes
    }

    override var fileURL: URL? {
        didSet { model.fileURL = fileURL }
    }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    // MARK: - Reading and writing

    override func read(from data: Data, ofType typeName: String) throws {
        model.content = try TextContent(data: data)
    }

    override func data(ofType typeName: String) throws -> Data {
        try model.content.data(for: UTType(typeName) ?? .plainText)
    }

    /// Changes that don't go through the text view's undo manager
    /// (encoding, line endings).
    func noteSettingsChanged() {
        updateChangeCount(.changeDone)
    }

    // MARK: - Save panel

    /// The format chosen in the save panel. DosMemo shows its own compact
    /// "Format" popup instead of AppKit's "File Format" control.
    private var savePanelType: String?

    override var shouldRunSavePanelWithAccessoryView: Bool { false }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        guard super.prepareSavePanel(savePanel) else { return false }
        let types = writableTypes(for: .saveAsOperation)
        let selected = Self.defaultSaveType(for: fileType, among: types)
        savePanelType = selected
        savePanel.allowedContentTypes = UTType(selected).map { [$0] } ?? []
        savePanel.accessoryView = SaveFormatAccessory(types: types, selected: selected) { [weak self, weak savePanel] type in
            self?.savePanelType = type
            savePanel?.allowedContentTypes = UTType(type).map { [$0] } ?? []
        }
        return true
    }

    override var fileTypeFromLastRunSavePanel: String? {
        savePanelType ?? super.fileTypeFromLastRunSavePanel
    }

    /// The document's own type when it is writable, else the most specific
    /// writable type it conforms to (e.g. Source Code for .swift), else
    /// plain text.
    static func defaultSaveType(for fileType: String?, among types: [String]) -> String {
        if let fileType, types.contains(fileType) { return fileType }
        let plainText = UTType.plainText.identifier
        if let type = fileType.flatMap(UTType.init),
           let match = types.first(where: { $0 != plainText && UTType($0).map(type.conforms(to:)) == true }) {
            return match
        }
        return types.contains(plainText) ? plainText : types[0]
    }

    // MARK: - Closing

    private var pendingCloseReply: ((Bool) -> Void)?

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?,
                           contextInfo: UnsafeMutableRawPointer?) {
        let reply: (Bool) -> Void = { shouldClose in
            Self.invoke(delegate, shouldCloseSelector, document: self, flag: shouldClose, contextInfo: contextInfo)
        }
        guard isDocumentEdited, let window = windowForSheet else {
            reply(true)
            return
        }
        let alert = NSAlert()
        alert.messageText = L("close.message", displayName)
        alert.addButton(withTitle: L("close.save"))
        let dontSave = alert.addButton(withTitle: L("close.dontSave"))
        dontSave.keyEquivalent = "d"
        dontSave.keyEquivalentModifierMask = .command
        let cancel = alert.addButton(withTitle: L("close.cancel"))
        cancel.keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                self.pendingCloseReply = reply
                self.save(withDelegate: self, didSave: #selector(self.document(_:didSave:contextInfo:)), contextInfo: nil)
            case .alertSecondButtonReturn:
                reply(true)
            default:
                reply(false)
            }
        }
    }

    @objc private func document(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        let reply = pendingCloseReply
        pendingCloseReply = nil
        reply?(didSave)
    }

    /// Calls AppKit's `document:shouldClose:contextInfo:` style callback.
    private static func invoke(_ delegate: Any, _ selector: Selector?, document: NSDocument, flag: Bool,
                               contextInfo: UnsafeMutableRawPointer?) {
        guard let selector, let target = delegate as? NSObject, target.responds(to: selector) else { return }
        typealias Callback = @convention(c) (NSObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        let implementation = target.method(for: selector)
        unsafeBitCast(implementation, to: Callback.self)(target, selector, document, flag, contextInfo)
    }
}

/// "Format: [popup]" row shown below the save panel.
private final class SaveFormatAccessory: NSView {
    private let types: [String]
    private let onChange: (String) -> Void
    private let popup = NSPopUpButton()

    init(types: [String], selected: String, onChange: @escaping (String) -> Void) {
        self.types = types
        self.onChange = onChange
        super.init(frame: .zero)

        for type in types {
            popup.addItem(withTitle: NSDocumentController.shared.displayName(forType: type) ?? type)
        }
        popup.selectItem(at: types.firstIndex(of: selected) ?? 0)
        popup.target = self
        popup.action = #selector(formatChanged(_:))

        let label = NSTextField(labelWithString: L("save.format"))
        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
        ])
        setFrameSize(row.fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func formatChanged(_ sender: NSPopUpButton) {
        onChange(types[sender.indexOfSelectedItem])
    }
}
