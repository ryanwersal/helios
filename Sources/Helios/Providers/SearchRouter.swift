@MainActor
final class SearchRouter {
    private(set) var providers: [SearchProvider]

    init(providers: [SearchProvider]) {
        self.providers = providers
    }

    func addProviders(_ newProviders: [SearchProvider]) {
        providers.append(contentsOf: newProviders)
    }

    func removePluginProviders() {
        providers.removeAll { $0 is PluginProvider }
    }
}
