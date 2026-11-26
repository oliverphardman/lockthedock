import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let locker = DockLocker()
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem!
    private var retryTimer: Timer?

    private var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    private var chosenUUID: String? {
        get { defaults.string(forKey: "display") }
        set { defaults.set(newValue, forKey: "display") }
    }

    private var optionOverride: Bool {
        get { defaults.object(forKey: "optionOverride") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "optionOverride") }
    }

    private var hiddenFromMenuBar: Bool {
        get { defaults.bool(forKey: "hidden") }
        set { defaults.set(newValue, forKey: "hidden") }
    }

    private var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !launchedAtLogin { hiddenFromMenuBar = false }
        NSApp.disableRelaunchOnLogin()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = !hiddenFromMenuBar

        if chosenUUID == nil { chosenUUID = Displays.uuid(CGMainDisplayID()) }

        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        apply()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.apply()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        hiddenFromMenuBar = false
        statusItem.isVisible = true
        return true
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        apply()
    }

    private func apply() {
        let chosen = Displays.active().first { Displays.uuid($0) == chosenUUID }
        locker.update(allowedDisplay: chosen)
        locker.optionOverride = optionOverride
        if enabled && AXIsProcessTrusted() {
            locker.start()
        } else {
            locker.stop()
        }
        showStatus(displayConnected: chosen != nil)
    }

    private func showStatus(displayConnected: Bool) {
        let locked = locker.isRunning && displayConnected
        let description = statusDescription(displayConnected: displayConnected)
        let button = statusItem.button
        button?.image = NSImage(
            systemSymbolName: locked ? "lock.fill" : "lock.open.fill", accessibilityDescription: description)
        button?.setAccessibilityLabel(description)
        button?.toolTip = description
    }

    private func statusDescription(displayConnected: Bool) -> String {
        if !enabled {
            return String(
                localized: "Lock The Dock: lock turned off", comment: "Menu bar icon tooltip and VoiceOver label.")
        }
        if !AXIsProcessTrusted() {
            return String(
                localized: "Lock The Dock: not locked, Accessibility access needed",
                comment: "Menu bar icon tooltip and VoiceOver label.")
        }
        if !displayConnected {
            return String(
                localized: "Lock The Dock: not locked, chosen display not connected",
                comment: "Menu bar icon tooltip and VoiceOver label.")
        }
        if !locker.isRunning {
            return String(
                localized: "Lock The Dock: not locked, the lock could not start",
                comment: "Menu bar icon tooltip and VoiceOver label.")
        }
        return String(localized: "Lock The Dock: locked", comment: "Menu bar icon tooltip and VoiceOver label.")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AXIsProcessTrusted() {
            menu.addItem(
                item(
                    String(
                        localized: "Grant Accessibility Access…",
                        comment: "Menu item that opens the Accessibility privacy settings."),
                    #selector(openAccessibilitySettings)))
            menu.addItem(.separator())
        } else if enabled && !locker.isRunning {
            menu.addItem(
                withTitle: String(
                    localized: "Could not start the lock",
                    comment: "Disabled menu item shown when the lock fails to start."), action: nil, keyEquivalent: "")
            menu.addItem(.separator())
        }

        let toggle = item(
            String(localized: "Lock the Dock", comment: "Checkable menu item that turns the lock on and off."),
            #selector(toggleEnabled))
        toggle.state = enabled ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: String(localized: "Keep Dock on:", comment: "Menu heading above the list of displays."),
            action: nil, keyEquivalent: "")
        let ids = Displays.active()
        for id in ids {
            let entry = item(Displays.name(id), #selector(chooseDisplay(_:)))
            entry.representedObject = Displays.uuid(id)
            entry.state = Displays.uuid(id) == chosenUUID ? .on : .off
            entry.indentationLevel = 1
            menu.addItem(entry)
        }
        if !ids.contains(where: { Displays.uuid($0) == chosenUUID }) {
            menu.addItem(
                withTitle: String(
                    localized: "Chosen display not connected",
                    comment: "Disabled menu item shown when the saved display is unplugged."), action: nil,
                keyEquivalent: "")
        }
        menu.addItem(.separator())
        let option = item(
            String(localized: "Hold ⌥ to move the Dock", comment: "Checkable menu item. ⌥ is the Option key."),
            #selector(toggleOptionOverride))
        option.state = optionOverride ? .on : .off
        menu.addItem(option)

        let login = item(
            String(localized: "Launch on startup", comment: "Checkable menu item that starts the app at login."),
            #selector(toggleLaunchAtLogin))
        switch SMAppService.mainApp.status {
        case .enabled: login.state = .on
        case .requiresApproval:
            login.state = .mixed
            login.title = String(
                localized: "Launch on startup (needs approval…)",
                comment: "Menu item shown when the login item awaits approval in System Settings.")
        default: login.state = .off
        }
        menu.addItem(login)
        menu.addItem(
            item(
                String(
                    localized: "Hide from menu bar", comment: "Menu item, and the title of its confirmation dialog."),
                #selector(hideFromMenuBar)))

        menu.addItem(.separator())
        menu.addItem(
            item(
                String(localized: "About Lock The Dock", comment: "Menu item. Lock The Dock is the app's name."),
                #selector(showAbout)))
        menu.addItem(
            withTitle: String(localized: "Quit Lock The Dock", comment: "Menu item. Lock The Dock is the app's name."),
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        apply()
    }

    @objc private func chooseDisplay(_ sender: NSMenuItem) {
        chosenUUID = sender.representedObject as? String
        apply()
    }

    @objc private func toggleOptionOverride() {
        optionOverride.toggle()
        apply()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled: try service.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    @objc private func hideFromMenuBar() {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Hide from menu bar", comment: "Menu item, and the title of its confirmation dialog.")
        alert.informativeText = String(
            localized: "To restore the icon to your menu bar, relaunch Lock The Dock.",
            comment: "Message in the dialog confirming that the menu bar icon will be hidden.")
        alert.addButton(withTitle: String(localized: "Hide", comment: "Button that confirms hiding the menu bar icon."))
        alert.addButton(
            withTitle: String(localized: "Cancel", comment: "Button that dismisses a dialog without changes."))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        hiddenFromMenuBar = true
        statusItem.isVisible = false
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centered,
        ]
        let credits = NSMutableAttributedString(
            string: String(
                localized: "Keeps the Dock on the display you choose.", comment: "Description in the About panel.")
                + "\n\n",
            attributes: attributes)
        let address = "https://github.com/oliveprhardman/lockthedock"
        credits.append(
            NSAttributedString(
                string: "github.com/oliveprhardman/lockthedock",
                attributes: attributes.merging([.link: URL(string: address)!]) { _, new in new }))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func openAccessibilitySettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        NSWorkspace.shared.open(URL(string: url)!)
    }
}
