import AppKit
import Combine
import SwiftUI

/// One editor window: hosts the SwiftUI content, owns the toolbar and
/// handles the per-window menu commands (it sits in the responder chain
/// between the window and the document).
final class EditorWindowController: NSWindowController, NSToolbarDelegate, NSMenuItemValidation {
    private let model: DocumentModel
    let state = EditorState()
    private var subscriptions: Set<AnyCancellable> = []
    private weak var layoutControl: NSSegmentedControl?
    private weak var wrapControl: NSSegmentedControl?

    private var textDocument: TextFileDocument? { document as? TextFileDocument }

    init(document: TextFileDocument) {
        model = document.model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.minSize = NSSize(width: 420, height: 260)
        window.toolbarStyle = .expanded
        super.init(window: window)
        shouldCascadeWindows = true

        window.contentViewController = NSHostingController(rootView: ContentView(model: model, state: state))
        window.setContentSize(NSSize(width: 900, height: 620))
        window.center()

        // Bump the identifier when the default item order changes: the saved
        // configuration of the old identifier would otherwise win.
        let toolbar = NSToolbar(identifier: "DosMemo.editor.2")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window.toolbar = toolbar

        observeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func observeState() {
        model.$fileURL.combineLatest(model.$content.map(\.isBinaryPropertyList).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayoutControl() }
            .store(in: &subscriptions)
        state.$layout
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLayoutControl() }
            .store(in: &subscriptions)
        state.$wordWrap
            .receive(on: RunLoop.main)
            .sink { [weak self] wrap in self?.wrapControl?.setSelected(wrap, forSegment: 0) }
            .store(in: &subscriptions)
    }

    private func updateLayoutControl() {
        guard let control = layoutControl else { return }
        let available = model.previewKind != nil
        control.isEnabled = available
        let selected = available ? state.layout : .source
        control.selectedSegment = EditorLayout.allCases.firstIndex(of: selected) ?? 0
    }

    // MARK: - Commands

    @objc func setEditorLayout(_ sender: Any?) {
        let index: Int
        if let control = sender as? NSSegmentedControl {
            index = control.selectedSegment
        } else if let item = sender as? NSMenuItem {
            index = item.tag
        } else {
            return
        }
        guard model.previewKind != nil, EditorLayout.allCases.indices.contains(index) else { return }
        state.layout = EditorLayout.allCases[index]
    }

    @objc func zoomInText(_ sender: Any?) { state.setFontSize(state.fontSize + 1) }
    @objc func zoomOutText(_ sender: Any?) { state.setFontSize(state.fontSize - 1) }
    @objc func resetTextZoom(_ sender: Any?) { state.setFontSize(AppSettings.baseFontSize) }

    @objc func toggleWordWrap(_ sender: Any?) { state.wordWrap.toggle() }

    @objc func chooseFont(_ sender: NSMenuItem) {
        state.fontName = sender.representedObject as? String
    }

    @objc func chooseFontSize(_ sender: NSMenuItem) {
        state.setFontSize(CGFloat(sender.tag))
    }

    @objc func showFontPanel(_ sender: Any?) {
        let manager = NSFontManager.shared
        manager.setSelectedFont(state.font, isMultiple: false)
        manager.target = self
        manager.action = #selector(changeEditorFont(_:))
        NSFontPanel.shared.makeKeyAndOrderFront(nil)
    }

    @objc func changeEditorFont(_ sender: Any?) {
        let manager = (sender as? NSFontManager) ?? NSFontManager.shared
        let font = manager.convert(state.font)
        state.fontName = font.fontName
        state.setFontSize(font.pointSize)
    }

    @objc func chooseEncoding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? UInt else { return }
        let encoding = String.Encoding(rawValue: raw)
        guard model.content.encoding != encoding else { return }
        model.content.encoding = encoding
        textDocument?.noteSettingsChanged()
    }

    @objc func chooseLineEnding(_ sender: NSMenuItem) {
        let ending = LineEnding.allCases[sender.tag]
        guard model.content.lineEnding != ending else { return }
        model.content.lineEnding = ending
        textDocument?.noteSettingsChanged()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(setEditorLayout(_:)):
            let available = model.previewKind != nil
            item.state = available && EditorLayout.allCases.firstIndex(of: state.layout) == item.tag ? .on : .off
            return available
        case #selector(toggleWordWrap(_:)):
            item.state = state.wordWrap ? .on : .off
        case #selector(chooseFont(_:)):
            item.state = (item.representedObject as? String) == state.fontName ? .on : .off
        case #selector(chooseFontSize(_:)):
            item.state = CGFloat(item.tag) == state.fontSize ? .on : .off
        case #selector(chooseEncoding(_:)):
            item.state = (item.representedObject as? UInt) == model.content.encoding.rawValue ? .on : .off
            return !model.content.isBinaryPropertyList
        case #selector(chooseLineEnding(_:)):
            item.state = LineEnding.allCases[item.tag] == model.content.lineEnding ? .on : .off
            return !model.content.isBinaryPropertyList
        default:
            break
        }
        return true
    }

    // MARK: - Toolbar

    private enum Item {
        static let layout = NSToolbarItem.Identifier("layout")
        static let file = NSToolbarItem.Identifier("file")
        static let font = NSToolbarItem.Identifier("font")
        static let find = NSToolbarItem.Identifier("find")
        static let encoding = NSToolbarItem.Identifier("encoding")
        static let zoomOut = NSToolbarItem.Identifier("zoomOut")
        static let zoomIn = NSToolbarItem.Identifier("zoomIn")
        static let wrap = NSToolbarItem.Identifier("wrap")
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // File commands first; preview-related controls at the far right.
        [Item.file, Item.font, Item.find, Item.encoding, .space,
         Item.zoomOut, Item.zoomIn, Item.wrap, .flexibleSpace, Item.layout]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch identifier {
        case Item.layout:
            let control = NSSegmentedControl(
                images: EditorLayout.allCases.map { Self.symbol($0.systemImage, L($0.titleKey)) },
                trackingMode: .selectOne, target: self, action: #selector(setEditorLayout(_:)))
            control.controlSize = .large
            for (index, layout) in EditorLayout.allCases.enumerated() {
                control.setToolTip("\(L(layout.titleKey)) (⌥⌘\(index + 1))", forSegment: index)
            }
            layoutControl = control
            updateLayoutControl()
            return viewItem(identifier, "toolbar.layout", control)
        case Item.file:
            return menuItem(identifier, "toolbar.file", "folder", MainMenu.fileToolbarMenu())
        case Item.font:
            return menuItem(identifier, "toolbar.font", "textformat", MainMenu.fontMenu())
        case Item.find:
            return menuItem(identifier, "toolbar.find", "magnifyingglass", MainMenu.findMenu(withShortcuts: false))
        case Item.encoding:
            return menuItem(identifier, "toolbar.encoding", "doc.text", MainMenu.encodingMenu())
        case Item.zoomOut:
            return buttonItem(identifier, "toolbar.zoomOut", "minus.magnifyingglass", #selector(zoomOutText(_:)))
        case Item.zoomIn:
            return buttonItem(identifier, "toolbar.zoomIn", "plus.magnifyingglass", #selector(zoomInText(_:)))
        case Item.wrap:
            let control = NSSegmentedControl(
                images: [Self.symbol("arrow.turn.down.left", L("toolbar.wrap"))],
                trackingMode: .selectAny, target: self, action: #selector(toggleWordWrap(_:)))
            control.controlSize = .large
            control.setSelected(state.wordWrap, forSegment: 0)
            control.setToolTip(L("toolbar.wrap"), forSegment: 0)
            wrapControl = control
            return viewItem(identifier, "toolbar.wrap", control)
        default:
            return nil
        }
    }

    /// Toolbar symbols at the large symbol scale (about 1.3× the default),
    /// which also makes the toolbar taller.
    private static let symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)

    private static func symbol(_ name: String, _ description: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(symbolConfiguration) ?? NSImage()
    }

    private func viewItem(_ identifier: NSToolbarItem.Identifier, _ labelKey: String, _ view: NSView) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = L(labelKey)
        item.paletteLabel = L(labelKey)
        item.view = view
        return item
    }

    // Toolbar items are views sized by `controlSize = .large` with large
    // symbols: image-only toolbar items are always drawn at the standard
    // size, whatever the image's symbol configuration.

    private func menuItem(_ identifier: NSToolbarItem.Identifier, _ labelKey: String, _ image: String,
                          _ menu: NSMenu) -> NSToolbarItem {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        // A pull-down shows its first item as the button face.
        let face = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        face.image = Self.symbol(image, L(labelKey))
        menu.insertItem(face, at: 0)
        popup.menu = menu
        popup.imagePosition = .imageOnly
        popup.bezelStyle = .texturedRounded
        popup.controlSize = .large
        popup.toolTip = L(labelKey)
        return viewItem(identifier, labelKey, popup)
    }

    private func buttonItem(_ identifier: NSToolbarItem.Identifier, _ labelKey: String, _ image: String,
                            _ action: Selector) -> NSToolbarItem {
        let button = NSButton(image: Self.symbol(image, L(labelKey)), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.controlSize = .large
        button.toolTip = L(labelKey)
        return viewItem(identifier, labelKey, button)
    }
}
