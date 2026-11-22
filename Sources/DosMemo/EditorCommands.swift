import AppKit
import SwiftUI

/// Commands sent from menus and the toolbar to the editor in the key window.
enum EditorCommand: Equatable {
    case zoomIn, zoomOut, zoomReset
    case showFontPanel, toggleWrap
    case find(NSTextFinder.Action)

    static let notification = Notification.Name("DosMemo.editorCommand")
    private static let userInfoKey = "command"

    func post() {
        NotificationCenter.default.post(name: Self.notification, object: nil, userInfo: [Self.userInfoKey: self])
    }

    init?(_ notification: Notification) {
        guard let command = notification.userInfo?[Self.userInfoKey] as? EditorCommand else { return nil }
        self = command
    }
}

/// Find menu items, shared by the menu bar and the toolbar. Keyboard shortcuts
/// are registered only once (in the menu bar) to avoid duplicate key
/// equivalents.
struct FindMenuItems: View {
    var withShortcuts: Bool

    var body: some View {
        item("menu.find.find", .showFindInterface, "f", .command)
        item("menu.find.replace", .showReplaceInterface, "f", [.command, .option])
        Divider()
        item("menu.find.next", .nextMatch, "g", .command)
        item("menu.find.previous", .previousMatch, "g", [.command, .shift])
        item("menu.find.useSelection", .setSearchString, "e", .command)
    }

    @ViewBuilder
    private func item(_ key: String, _ action: NSTextFinder.Action,
                      _ shortcut: KeyEquivalent, _ modifiers: EventModifiers) -> some View {
        let button = Button(L(key)) { EditorCommand.find(action).post() }
        if withShortcuts {
            button.keyboardShortcut(shortcut, modifiers: modifiers)
        } else {
            button
        }
    }
}

enum DocumentActions {
    static func save()   { NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil) }
    static func saveAs() { NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil) }
    static func closeWindow() { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }
    static func newDocument() { NSDocumentController.shared.newDocument(nil) }
    static func openDocument() { NSDocumentController.shared.openDocument(nil) }
}
