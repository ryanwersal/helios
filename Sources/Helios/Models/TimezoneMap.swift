import Foundation

enum TimezoneMap {
    struct Alternative: Equatable, Sendable {
        let label: String
        let identifier: String
    }

    enum Resolution: Equatable, Sendable {
        case resolved(TimeZone)
        case ambiguous([Alternative])
        case unknown
    }

    static let abbreviationAliases = Set(unambiguousAbbreviations.keys).union(ambiguousAbbreviations.keys)

    private static let cityToTimezone: [String: String] = [
        // North America
        "new york": "America/New_York",
        "nyc": "America/New_York",
        "boston": "America/New_York",
        "miami": "America/New_York",
        "atlanta": "America/New_York",
        "washington": "America/New_York",
        "dc": "America/New_York",
        "chicago": "America/Chicago",
        "adak": "America/Adak",
        "havana": "America/Havana",
        "dallas": "America/Chicago",
        "houston": "America/Chicago",
        "denver": "America/Denver",
        "phoenix": "America/Phoenix",
        "az": "America/Phoenix",
        "arizona": "America/Phoenix",
        "hawaii": "Pacific/Honolulu",
        "hi": "Pacific/Honolulu",
        "alaska": "America/Anchorage",
        "ak": "America/Anchorage",
        "los angeles": "America/Los_Angeles",
        "la": "America/Los_Angeles",
        "san francisco": "America/Los_Angeles",
        "sf": "America/Los_Angeles",
        "seattle": "America/Los_Angeles",
        "portland": "America/Los_Angeles",
        "anchorage": "America/Anchorage",
        "honolulu": "Pacific/Honolulu",
        "toronto": "America/Toronto",
        "vancouver": "America/Vancouver",
        "mexico city": "America/Mexico_City",

        // Europe
        "london": "Europe/London",
        "dublin": "Europe/Dublin",
        "paris": "Europe/Paris",
        "berlin": "Europe/Berlin",
        "amsterdam": "Europe/Amsterdam",
        "brussels": "Europe/Brussels",
        "madrid": "Europe/Madrid",
        "rome": "Europe/Rome",
        "milan": "Europe/Rome",
        "zurich": "Europe/Zurich",
        "vienna": "Europe/Vienna",
        "stockholm": "Europe/Stockholm",
        "oslo": "Europe/Oslo",
        "copenhagen": "Europe/Copenhagen",
        "helsinki": "Europe/Helsinki",
        "warsaw": "Europe/Warsaw",
        "prague": "Europe/Prague",
        "athens": "Europe/Athens",
        "istanbul": "Europe/Istanbul",
        "moscow": "Europe/Moscow",
        "lisbon": "Europe/Lisbon",

        // Asia
        "dubai": "Asia/Dubai",
        "jerusalem": "Asia/Jerusalem",
        "manila": "Asia/Manila",
        "mumbai": "Asia/Kolkata",
        "delhi": "Asia/Kolkata",
        "bangalore": "Asia/Kolkata",
        "kolkata": "Asia/Kolkata",
        "singapore": "Asia/Singapore",
        "bangkok": "Asia/Bangkok",
        "hong kong": "Asia/Hong_Kong",
        "shanghai": "Asia/Shanghai",
        "beijing": "Asia/Shanghai",
        "tokyo": "Asia/Tokyo",
        "seoul": "Asia/Seoul",
        "taipei": "Asia/Taipei",
        "jakarta": "Asia/Jakarta",

        // Oceania
        "sydney": "Australia/Sydney",
        "melbourne": "Australia/Melbourne",
        "brisbane": "Australia/Brisbane",
        "perth": "Australia/Perth",
        "auckland": "Pacific/Auckland",

        // South America
        "sao paulo": "America/Sao_Paulo",
        "buenos aires": "America/Argentina/Buenos_Aires",
        "santiago": "America/Santiago",
        "bogota": "America/Bogota",
        "lima": "America/Lima",

        // Africa
        "cairo": "Africa/Cairo",
        "algiers": "Africa/Algiers",
        "tripoli": "Africa/Tripoli",
        "lagos": "Africa/Lagos",
        "nairobi": "Africa/Nairobi",
        "johannesburg": "Africa/Johannesburg",
        "cape town": "Africa/Johannesburg",
        "casablanca": "Africa/Casablanca",
    ]

    private static let unambiguousAbbreviations: [String: String] = [
        "utc": "UTC",
        "jst": "Asia/Tokyo",
        "kst": "Asia/Seoul",
    ]

    /// Require explicit zones when an abbreviation can denote places or a standard offset
    /// with different rules, even when those choices agree on the date in the query.
    private static let ambiguousAbbreviations: [String: [Alternative]] = [
        "aest": [
            Alternative(label: "Sydney", identifier: "Australia/Sydney"),
            Alternative(label: "Brisbane", identifier: "Australia/Brisbane"),
        ],
        "akst": [
            Alternative(label: "Anchorage", identifier: "America/Anchorage"),
            Alternative(label: "Fixed UTC−09:00", identifier: "Etc/GMT+9"),
        ],
        "cet": [
            Alternative(label: "Paris", identifier: "Europe/Paris"),
            Alternative(label: "Algiers", identifier: "Africa/Algiers"),
        ],
        "cst": [
            Alternative(label: "Chicago", identifier: "America/Chicago"),
            Alternative(label: "Shanghai", identifier: "Asia/Shanghai"),
            Alternative(label: "Havana", identifier: "America/Havana"),
        ],
        "eet": [
            Alternative(label: "Athens", identifier: "Europe/Athens"),
            Alternative(label: "Tripoli", identifier: "Africa/Tripoli"),
        ],
        "est": [
            Alternative(label: "New York", identifier: "America/New_York"),
            Alternative(label: "Fixed UTC−05:00", identifier: "Etc/GMT+5"),
        ],
        "gmt": [
            Alternative(label: "London", identifier: "Europe/London"),
            Alternative(label: "Fixed UTC+00:00", identifier: "UTC"),
        ],
        "hst": [
            Alternative(label: "Honolulu", identifier: "Pacific/Honolulu"),
            Alternative(label: "Adak", identifier: "America/Adak"),
        ],
        "ist": [
            Alternative(label: "Kolkata", identifier: "Asia/Kolkata"),
            Alternative(label: "Dublin", identifier: "Europe/Dublin"),
            Alternative(label: "Jerusalem", identifier: "Asia/Jerusalem"),
        ],
        "mst": [
            Alternative(label: "Denver", identifier: "America/Denver"),
            Alternative(label: "Phoenix", identifier: "America/Phoenix"),
        ],
        "nzst": [
            Alternative(label: "Auckland", identifier: "Pacific/Auckland"),
            Alternative(label: "Fixed UTC+12:00", identifier: "Etc/GMT-12"),
        ],
        "pst": [
            Alternative(label: "Los Angeles", identifier: "America/Los_Angeles"),
            Alternative(label: "Manila", identifier: "Asia/Manila"),
            Alternative(label: "Fixed UTC−08:00", identifier: "Etc/GMT+8"),
        ],
    ]

    private static let caseInsensitiveIdentifiers: [String: String] = {
        // Foundation omits the fixed-offset Etc identifiers from its list of known zones.
        let alternatives = ambiguousAbbreviations.values.flatMap { $0.map(\.identifier) }
        let identifiers = Set(TimeZone.knownTimeZoneIdentifiers).union(alternatives)
        return Dictionary(uniqueKeysWithValues: identifiers.map { ($0.lowercased(), $0) })
    }()

    static func resolve(_ input: String) -> Resolution {
        let key = input.lowercased().trimmingCharacters(in: .whitespaces)
        if let alternatives = ambiguousAbbreviations[key] {
            return .ambiguous(alternatives)
        }
        if let identifier = unambiguousAbbreviations[key] ?? cityToTimezone[key] ?? caseInsensitiveIdentifiers[key],
           let zone = TimeZone(identifier: identifier)
        {
            return .resolved(zone)
        }
        return .unknown
    }

    /// Look up a timezone for a city name or abbreviation (case-insensitive).
    static func timezone(for input: String) -> TimeZone? {
        if case let .resolved(zone) = resolve(input) {
            return zone
        }
        return nil
    }
}
