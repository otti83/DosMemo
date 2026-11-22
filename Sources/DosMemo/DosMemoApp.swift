import SwiftUI
import AppKit

@main
struct DosMemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { config in
            ContentView(document: config.$document)
                .frame(minWidth: 420, minHeight: 260)
        }
        .windowToolbarStyle(.expanded)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L("about")) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            // Notepad-style Close / Save / Save As instead of Duplicate / Rename / Move.
            CommandGroup(replacing: .saveItem) {
                Button(L("menu.file.close"), action: DocumentActions.closeWindow)
                    .keyboardShortcut("w", modifiers: .command)
                Button(L("menu.file.save"), action: DocumentActions.save)
                    .keyboardShortcut("s", modifiers: .command)
                Button(L("menu.file.saveAs"), action: DocumentActions.saveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu(L("menu.find")) {
                FindMenuItems(withShortcuts: true)
            }
            // Adds to the system View menu rather than creating a second one.
            CommandGroup(before: .toolbar) {
                Button(L("menu.view.zoomIn")) { EditorCommand.zoomIn.post() }
                    .keyboardShortcut("+", modifiers: .command)
                Button(L("menu.view.zoomOut")) { EditorCommand.zoomOut.post() }
                    .keyboardShortcut("-", modifiers: .command)
                Button(L("menu.view.zoomReset")) { EditorCommand.zoomReset.post() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(L("menu.view.font")) { EditorCommand.showFontPanel.post() }
                Button(L("menu.view.wrap")) { EditorCommand.toggleWrap.post() }
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }
            // The editor has no sidebar.
            CommandGroup(replacing: .sidebar) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Start with an untitled document, like Notepad, instead of the
        // document-browser open panel.
        UserDefaults.standard.set(false, forKey: "NSShowAppCentricOpenPanelInsteadOfUntitledFile")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Dock menu

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let newItem = NSMenuItem(title: L("menu.file.new"), action: #selector(dockNewDocument(_:)), keyEquivalent: "")
        newItem.target = self
        menu.addItem(newItem)
        let openItem = NSMenuItem(title: L("menu.file.open"), action: #selector(dockOpenDocument(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        return menu
    }

    @objc private func dockNewDocument(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        DocumentActions.newDocument()
    }

    @objc private func dockOpenDocument(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        DocumentActions.openDocument()
    }
}
