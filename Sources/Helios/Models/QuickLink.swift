struct QuickLink: Codable, Equatable {
    let keyword: String
    let name: String
    let url: String // template containing {query}
}

struct QuickLinksConfig: Codable {
    var quicklinks: [QuickLink]
}
