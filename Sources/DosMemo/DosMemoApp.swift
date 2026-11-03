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
            CommandMenu(LocalizedStringKey(L("menu.find"))) {
                Button(L("menu.find.find")) { NotificationCenter.default.post(name: .dmFind, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
                Button(L("menu.find.replace")) { NotificationCenter.default.post(name: .dmReplace, object: nil) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Divider()
                Button(L("menu.find.next")) { NotificationCenter.default.post(name: .dmFindNext, object: nil) }
                    .keyboardShortcut("g", modifiers: .command)
                Button(L("menu.find.previous")) { NotificationCenter.default.post(name: .dmFindPrev, object: nil) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button(L("menu.find.useSelection")) { NotificationCenter.default.post(name: .dmFindSetSelection, object: nil) }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandMenu(LocalizedStringKey(L("menu.view"))) {
                Button(L("menu.view.zoomIn")) { NotificationCenter.default.post(name: .dmZoomIn, object: nil) }
                    .keyboardShortcut("+", modifiers: .command)
                Button(L("menu.view.zoomOut")) { NotificationCenter.default.post(name: .dmZoomOut, object: nil) }
                    .keyboardShortcut("-", modifiers: .command)
                Button(L("menu.view.zoomReset")) { NotificationCenter.default.post(name: .dmZoomReset, object: nil) }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(L("menu.view.font")) { NotificationCenter.default.post(name: .dmShowFont, object: nil) }
                Button(L("menu.view.wrap")) { NotificationCenter.default.post(name: .dmToggleWrap, object: nil) }
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var rebuildAttempts = 0

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSShowAppCentricOpenPanelInsteadOfUntitledFile")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI installs the File menu asynchronously and re-touches it. We
        // give it a few cycles to settle, then replace the menu wholesale.
        scheduleFileMenuRebuild()
    }

    private func scheduleFileMenuRebuild() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.rebuildFileMenu()
            self.rebuildAttempts += 1
            if self.rebuildAttempts < 8 {
                self.scheduleFileMenuRebuild()
            }
        }
    }

    private func rebuildFileMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let fileTitle = L("menu.file")
        guard let fileItem = mainMenu.items.first(where: {
            $0.title == "File" || $0.title == "ファイル" || $0.title == fileTitle
        }) else { return }

        let menu = NSMenu(title: fileTitle)

        let newItem = NSMenuItem(
            title: L("menu.file.new"),
            action: #selector(NSDocumentController.newDocument(_:)),
            keyEquivalent: "n"
        )
        menu.addItem(newItem)

        let openItem = NSMenuItem(
            title: L("menu.file.open"),
            action: #selector(NSDocumentController.openDocument(_:)),
            keyEquivalent: "o"
        )
        menu.addItem(openItem)

        let openRecentItem = NSMenuItem(title: L("menu.file.openRecent"), action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(
            title: L("menu.file.clearRecent"),
            action: #selector(NSDocumentController.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        openRecentMenu.addItem(clearItem)
        openRecentItem.submenu = openRecentMenu
        menu.addItem(openRecentItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(
            title: L("menu.file.close"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        menu.addItem(closeItem)

        let saveItem = NSMenuItem(
            title: L("menu.file.save"),
            action: NSSelectorFromString("saveDocument:"),
            keyEquivalent: "s"
        )
        menu.addItem(saveItem)

        let saveAsItem = NSMenuItem(
            title: L("menu.file.saveAs"),
            action: NSSelectorFromString("saveDocumentAs:"),
            keyEquivalent: "s"
        )
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(saveAsItem)

        fileItem.title = fileTitle
        fileItem.submenu = menu
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        do {
            try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
            return true
        } catch {
            return false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
