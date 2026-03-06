struct QuickLink: Codable, Sendable, Equatable {
    let keyword: String
    let name: String
    let url: String // template containing {query}
}

struct QuickLinksConfig: Codable, Sendable {
    var quicklinks: [QuickLink]
}
