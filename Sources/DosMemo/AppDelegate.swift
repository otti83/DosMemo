import AppKit

@main
enum DosMemoMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Start with an untitled document, like Notepad, instead of the
        // document-browser open panel.
        UserDefaults.standard.set(false, forKey: "NSShowAppCentricOpenPanelInsteadOfUntitledFile")
        MainMenu.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Dock menu

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: L("menu.file.new"), action: #selector(dockNewDocument(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("menu.file.open"), action: #selector(dockOpenDocument(_:)), keyEquivalent: "").target = self
        return menu
    }

    @objc private func dockNewDocument(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSDocumentController.shared.newDocument(sender)
    }

    @objc private func dockOpenDocument(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSDocumentController.shared.openDocument(sender)
    }
}

/// Builds the menu bar. Actions travel the responder chain: text view →
/// window → EditorWindowController → document → app.
enum MainMenu {
    static func install() {
        let main = NSMenu()
        main.addItem(submenu: appMenu())
        main.addItem(submenu: fileMenu())
        main.addItem(submenu: editMenu())
        main.addItem(submenu: viewMenu())
        main.addItem(submenu: findMenu(withShortcuts: true))
        let window = windowMenu()
        main.addItem(submenu: window)
        let help = NSMenu(title: L("menu.help"))
        main.addItem(submenu: help)
        NSApp.mainMenu = main
        NSApp.windowsMenu = window
        NSApp.helpMenu = help
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "DosMemo")
        menu.addItem(L("menu.app.about"), #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        menu.addItem(.separator())
        let services = NSMenu(title: L("menu.app.services"))
        menu.addItem(submenu: services)
        NSApp.servicesMenu = services
        menu.addItem(.separator())
        menu.addItem(L("menu.app.hide"), #selector(NSApplication.hide(_:)), "h")
        menu.addItem(L("menu.app.hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        menu.addItem(L("menu.app.showAll"), #selector(NSApplication.unhideAllApplications(_:)))
        menu.addItem(.separator())
        menu.addItem(L("menu.app.quit"), #selector(NSApplication.terminate(_:)), "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.file"))
        menu.addItem(L("menu.file.new"), #selector(NSDocumentController.newDocument(_:)), "n")
        menu.addItem(L("menu.file.open"), #selector(NSDocumentController.openDocument(_:)), "o")
        // AppKit inserts Open Recent after Open, and Close All as the
        // Option-alternate of Close.
        menu.addItem(.separator())
        menu.addItem(L("menu.file.close"), #selector(NSWindow.performClose(_:)), "w")
        menu.addItem(L("menu.file.save"), #selector(NSDocument.save(_:)), "s")
        menu.addItem(L("menu.file.saveAs"), #selector(NSDocument.saveAs(_:)), "s", [.command, .shift])
        menu.addItem(L("menu.file.revert"), #selector(NSDocument.revertToSaved(_:)))
        return menu
    }

    /// File commands for the toolbar menu.
    static func fileToolbarMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(L("menu.file.new"), #selector(NSDocumentController.newDocument(_:)))
        menu.addItem(L("menu.file.open"), #selector(NSDocumentController.openDocument(_:)))
        menu.addItem(.separator())
        menu.addItem(L("menu.file.save"), #selector(NSDocument.save(_:)))
        menu.addItem(L("menu.file.saveAs"), #selector(NSDocument.saveAs(_:)))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.edit"))
        menu.addItem(L("menu.edit.undo"), Selector(("undo:")), "z")
        menu.addItem(L("menu.edit.redo"), Selector(("redo:")), "z", [.command, .shift])
        menu.addItem(.separator())
        menu.addItem(L("menu.edit.cut"), #selector(NSText.cut(_:)), "x")
        menu.addItem(L("menu.edit.copy"), #selector(NSText.copy(_:)), "c")
        menu.addItem(L("menu.edit.paste"), #selector(NSText.paste(_:)), "v")
        menu.addItem(L("menu.edit.delete"), #selector(NSText.delete(_:)))
        menu.addItem(L("menu.edit.selectAll"), #selector(NSText.selectAll(_:)), "a")
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.view"))
        for (index, layout) in EditorLayout.allCases.enumerated() {
            let item = menu.addItem(L(layout.titleKey), #selector(EditorWindowController.setEditorLayout(_:)),
                                    String(index + 1), [.command, .option])
            item.tag = index
        }
        menu.addItem(.separator())
        menu.addItem(L("menu.view.zoomIn"), #selector(EditorWindowController.zoomInText(_:)), "+")
        menu.addItem(L("menu.view.zoomOut"), #selector(EditorWindowController.zoomOutText(_:)), "-")
        menu.addItem(L("menu.view.zoomReset"), #selector(EditorWindowController.resetTextZoom(_:)), "0")
        menu.addItem(.separator())
        menu.addItem(L("menu.view.font"), #selector(EditorWindowController.showFontPanel(_:)), "t")
        menu.addItem(L("menu.view.wrap"), #selector(EditorWindowController.toggleWordWrap(_:)), "l", [.command, .option])
        menu.addItem(.separator())
        menu.addItem(L("menu.view.toolbar"), #selector(NSWindow.toggleToolbarShown(_:)), "t", [.command, .option])
        menu.addItem(L("menu.view.customizeToolbar"), #selector(NSWindow.runToolbarCustomizationPalette(_:)))
        // AppKit appends Enter Full Screen.
        return menu
    }

    static func findMenu(withShortcuts: Bool) -> NSMenu {
        let menu = NSMenu(title: L("menu.find"))
        func add(_ key: String, _ action: NSTextFinder.Action, _ shortcut: String, _ modifiers: NSEvent.ModifierFlags = .command) {
            let item = menu.addItem(L(key), #selector(NSResponder.performTextFinderAction(_:)),
                                    withShortcuts ? shortcut : "", modifiers)
            item.tag = action.rawValue
        }
        add("menu.find.find", .showFindInterface, "f")
        add("menu.find.replace", .showReplaceInterface, "f", [.command, .option])
        menu.addItem(.separator())
        add("menu.find.next", .nextMatch, "g")
        add("menu.find.previous", .previousMatch, "g", [.command, .shift])
        add("menu.find.useSelection", .setSearchString, "e")
        return menu
    }

    static func fontMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.header(L("toolbar.font.section")))
        let fonts: [(String, String?)] = [
            (L("toolbar.font.system"), nil),
            ("Menlo", "Menlo-Regular"),
            ("Monaco", "Monaco"),
            ("Courier", "Courier"),
            ("SF Mono", "SFMono-Regular"),
            ("Hiragino Sans", "HiraginoSans-W3"),
            ("Hiragino Mincho ProN", "HiraMinProN-W3"),
            ("Helvetica", "Helvetica"),
        ]
        for (title, postScriptName) in fonts {
            menu.addItem(title, #selector(EditorWindowController.chooseFont(_:))).representedObject = postScriptName
        }
        menu.addItem(L("toolbar.font.other"), #selector(EditorWindowController.showFontPanel(_:)))
        menu.addItem(.separator())
        menu.addItem(.header(L("toolbar.size.section")))
        for size in [10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 48] {
            menu.addItem("\(size) pt", #selector(EditorWindowController.chooseFontSize(_:))).tag = size
        }
        return menu
    }

    static func encodingMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.header(L("toolbar.encoding.section")))
        let titles: [String.Encoding: String] = [
            .utf16LittleEndian: "UTF-16 LE (BOM)",
            .utf16BigEndian: "UTF-16 BE (BOM)",
        ]
        for encoding in TextEncodingInfo.choices {
            let title = titles[encoding] ?? TextEncodingInfo.label(for: encoding)
            menu.addItem(title, #selector(EditorWindowController.chooseEncoding(_:))).representedObject = encoding.rawValue
        }
        menu.addItem(.separator())
        menu.addItem(.header(L("toolbar.lineEnding.section")))
        let lineEndingKeys: [LineEnding: String] = [.lf: "lineEnding.lf", .crlf: "lineEnding.crlf", .cr: "lineEnding.cr"]
        for (index, ending) in LineEnding.allCases.enumerated() {
            menu.addItem(L(lineEndingKeys[ending]!), #selector(EditorWindowController.chooseLineEnding(_:))).tag = index
        }
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.window"))
        menu.addItem(L("menu.window.minimize"), #selector(NSWindow.performMiniaturize(_:)), "m")
        menu.addItem(L("menu.window.zoom"), #selector(NSWindow.performZoom(_:)))
        menu.addItem(.separator())
        menu.addItem(L("menu.window.bringAllToFront"), #selector(NSApplication.arrangeInFront(_:)))
        return menu
    }
}

private extension NSMenuItem {
    /// A non-selectable section title (`sectionHeader` needs macOS 14).
    static func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return .sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

private extension NSMenu {
    @discardableResult
    func addItem(_ title: String, _ action: Selector?, _ key: String = "",
                 _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        addItem(item)
        return item
    }

    func addItem(submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
