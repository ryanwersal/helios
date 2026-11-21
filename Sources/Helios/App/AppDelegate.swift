import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: SearchPanel!
    private var router: SearchRouter!
    private var hotkey: GlobalHotkey?
    private var settingsManager: SettingsManager!
    private var quickLinkStore: QuickLinkStore!
    private var pluginManager: PluginManager!
    private var toggleMenuItem: NSMenuItem!
    private var pluginReloadTask: Task<Void, Never>?
    private var searchController: SearchController!

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.applicationIconImage = BrandImages.appIcon
        setupMenuBar()
        setupPanel()
        setupRouter()
        setupHotkey()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = BrandImages.menuBarIcon
            button.setAccessibilityLabel("Helios")
        }

        let menu = NSMenu()
        toggleMenuItem = NSMenuItem(title: "Toggle Helios", action: #selector(togglePanel), keyEquivalent: " ")
        toggleMenuItem.keyEquivalentModifierMask = [.option]
        menu.addItem(toggleMenuItem)
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
        settingsManager.onHotkeyChanged = { [weak self] config in
            self?.applyHotkeyConfiguration(config)
        }
        quickLinkStore = QuickLinkStore()
        quickLinkStore.reload()

        pluginManager = PluginManager(isPluginDisabled: { [weak self] name in
            self?.settingsManager.isPluginDisabled(name) ?? false
        })

        settingsManager.onPluginSettingsChanged = { [weak self] in
            guard let self else { return }
            pluginReloadTask?.cancel()
            pluginReloadTask = Task {
                await self.pluginManager.reloadPlugins()
                guard !Task.isCancelled else { return }
                self.router.removePluginProviders()
                self.router.addProviders(self.pluginManager.providers)
            }
        }

        panel = SearchPanel(
            settingsManager: settingsManager,
            quickLinkStore: quickLinkStore,
            pluginManager: pluginManager,
        )
        panel.setSettingsHandler { [weak self] in
            self?.openSettings()
        }
    }

    // MARK: - Router

    private func setupRouter() {
        router = SearchRouter(providers: [
            QuickLinkProvider(store: quickLinkStore),
            CalculatorProvider(),
            UnitConversionProvider(),
            DateTimeProvider(),
            AppLauncherProvider(),
        ])
        searchController = SearchController(panel: panel, router: router)

        Task {
            await pluginManager.loadPlugins()
            router.addProviders(pluginManager.providers)
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        applyHotkeyConfiguration(settingsManager.hotkey)
    }

    private func applyHotkeyConfiguration(_ config: HotkeyConfiguration) {
        hotkey = nil
        hotkey = GlobalHotkey(
            keyCode: config.keyCode,
            modifiers: config.modifiers,
            callback: { [weak self] in
                self?.togglePanel()
            },
        )
        updateMenuKeyEquivalent(config)
    }

    private func updateMenuKeyEquivalent(_ config: HotkeyConfiguration) {
        toggleMenuItem.keyEquivalentModifierMask = ModifierSymbols.cocoaModifiers(from: config.modifiers)
        toggleMenuItem.keyEquivalent = ModifierSymbols.keyEquivalentCharacter(for: config.keyCode) ?? ""
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        if panel.isVisible {
            searchController.cancelSearch()
        } else {
            quickLinkStore.reload()
        }
        panel.toggle()
    }

    @objc private func openSettings() {
        searchController.cancelSearch()
        if !panel.isVisible {
            panel.showPanel()
        }
        panel.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
