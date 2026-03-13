import Foundation

public struct PluginRequest: Codable, Sendable {
    public let type: RequestType
    public let query: String?
    public let id: String?

    public enum RequestType: String, Codable, Sendable {
        case initialize
        case search
        case shutdown
    }

    public init(type: RequestType, query: String?, id: String?) {
        self.type = type
        self.query = query
        self.id = id
    }

    public static func initialize() -> PluginRequest {
        PluginRequest(type: .initialize, query: nil, id: nil)
    }

    public static func search(query: String, id: String) -> PluginRequest {
        PluginRequest(type: .search, query: query, id: id)
    }

    public static func shutdown() -> PluginRequest {
        PluginRequest(type: .shutdown, query: nil, id: nil)
    }
}

public struct PluginResponse: Codable, Sendable {
    public let type: ResponseType
    public let id: String?
    public let results: [PluginResultItem]?

    public enum ResponseType: String, Codable, Sendable {
        case ready
        case results
    }

    public init(type: ResponseType, id: String?, results: [PluginResultItem]?) {
        self.type = type
        self.id = id
        self.results = results
    }
}

public struct PluginResultItem: Codable, Sendable {
    public let title: String
    public let subtitle: String
    public let relevance: Double
    public let action: PluginAction
    public let iconSystemName: String?
    public let iconPath: String?
    public let iconBase64: String?
    public let iconTintable: Bool?

    public init(
        title: String,
        subtitle: String,
        relevance: Double,
        action: PluginAction,
        iconSystemName: String?,
        iconPath: String?,
        iconBase64: String?,
        iconTintable: Bool?,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.relevance = relevance
        self.action = action
        self.iconSystemName = iconSystemName
        self.iconPath = iconPath
        self.iconBase64 = iconBase64
        self.iconTintable = iconTintable
    }
}

public struct PluginAction: Codable, Sendable {
    public let type: ActionType
    public let url: String?
    public let text: String?

    public enum ActionType: String, Codable, Sendable {
        case openURL
        case copyToClipboard
    }

    public init(type: ActionType, url: String?, text: String?) {
        self.type = type
        self.url = url
        self.text = text
    }
}
