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

    static let abbreviationAliases: Set<String> = [
        "aest", "akst", "cet", "eet", "est", "gmt", "hst", "jst", "kst", "mst", "nzst", "pst", "utc",
    ]

    /// Map of common city names and abbreviations to IANA timezone identifiers.
    static let cityToTimezone: [String: String] = [
        // North America
        "new york": "America/New_York",
        "nyc": "America/New_York",
        "boston": "America/New_York",
        "miami": "America/New_York",
        "atlanta": "America/New_York",
        "washington": "America/New_York",
        "dc": "America/New_York",
        "chicago": "America/Chicago",
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
        "lagos": "Africa/Lagos",
        "nairobi": "Africa/Nairobi",
        "johannesburg": "Africa/Johannesburg",
        "cape town": "Africa/Johannesburg",
        "casablanca": "Africa/Casablanca",

        // Timezone abbreviations
        "est": "America/New_York",
        "mst": "America/Denver",
        "pst": "America/Los_Angeles",
        "gmt": "Europe/London",
        "utc": "UTC",
        "cet": "Europe/Paris",
        "eet": "Europe/Athens",
        "jst": "Asia/Tokyo",
        "kst": "Asia/Seoul",
        "aest": "Australia/Sydney",
        "nzst": "Pacific/Auckland",
        "hst": "Pacific/Honolulu",
        "akst": "America/Anchorage",
    ]

    /// Abbreviations that have several common meanings around the world.
    /// Requiring an explicit city or identifier avoids a plausible but wrong conversion.
    static let ambiguousAbbreviations: [String: [Alternative]] = [
        "cst": [
            Alternative(label: "Chicago", identifier: "America/Chicago"),
            Alternative(label: "Shanghai", identifier: "Asia/Shanghai"),
            Alternative(label: "Havana", identifier: "America/Havana"),
        ],
        "ist": [
            Alternative(label: "Kolkata", identifier: "Asia/Kolkata"),
            Alternative(label: "Dublin", identifier: "Europe/Dublin"),
            Alternative(label: "Jerusalem", identifier: "Asia/Jerusalem"),
        ],
    ]

    private static let caseInsensitiveIdentifiers: [String: String] = Dictionary(
        uniqueKeysWithValues: TimeZone.knownTimeZoneIdentifiers.map {
            ($0.lowercased(), $0)
        },
    )

    static func resolve(_ input: String) -> Resolution {
        let key = input.lowercased().trimmingCharacters(in: .whitespaces)
        if let alternatives = ambiguousAbbreviations[key] {
            return .ambiguous(alternatives)
        }
        if let identifier = cityToTimezone[key], let zone = TimeZone(identifier: identifier) {
            return .resolved(zone)
        }
        if let identifier = caseInsensitiveIdentifiers[key], let zone = TimeZone(identifier: identifier) {
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
