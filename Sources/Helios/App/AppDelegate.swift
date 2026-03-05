import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SearchFieldDelegate {
    private var statusItem: NSStatusItem!
    private var panel: SearchPanel!
    private var router: SearchRouter!
    private var hotkey: GlobalHotkey?
    private var settingsManager: SettingsManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPanel()
        setupRouter()
        setupHotkey()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Helios")
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Helios", action: #selector(togglePanel), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.option]
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Helios", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Panel

    private func setupPanel() {
        settingsManager = SettingsManager()
        panel = SearchPanel(settingsManager: settingsManager)
        panel.searchField.searchDelegate = self
        panel.setSettingsHandler { [weak self] in
            self?.panel.showSettings()
        }
    }

    // MARK: - Router

    private func setupRouter() {
        router = SearchRouter(providers: [
            CalculatorProvider(),
            DateTimeProvider(),
            AppLauncherProvider(),
            FirefoxBookmarkProvider(),
        ])
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        // Option+Space: keyCode 49 = Space, optionKey modifier
        hotkey = GlobalHotkey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            callback: { [weak self] in
                self?.panel.toggle()
            }
        )
    }

    // MARK: - SearchFieldDelegate

    func searchFieldDidChange(text: String) {
        if text.isEmpty {
            panel.showEmptyState()
        } else {
            let results = router.search(query: text)
            panel.resultsTableView.results = results
            panel.updateResultsHeight(count: results.count)
        }
    }

    func searchFieldDidPressArrowDown() {
        panel.resultsTableView.moveSelectionDown()
    }

    func searchFieldDidPressArrowUp() {
        panel.resultsTableView.moveSelectionUp()
    }

    func searchFieldDidPressEnter() {
        if panel.resultsTableView.executeSelectedResult() {
            panel.hidePanel()
        }
    }

    func searchFieldDidPressEscape() {
        panel.hidePanel()
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        panel.toggle()
    }

    @objc private func openSettings() {
        if !panel.isVisible {
            panel.showPanel()
        }
        panel.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
