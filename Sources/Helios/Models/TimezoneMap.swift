import Foundation

enum TimezoneMap {
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
        "cst": "America/Chicago",
        "mst": "America/Denver",
        "pst": "America/Los_Angeles",
        "gmt": "Europe/London",
        "utc": "UTC",
        "cet": "Europe/Paris",
        "eet": "Europe/Athens",
        "jst": "Asia/Tokyo",
        "kst": "Asia/Seoul",
        "ist": "Asia/Kolkata",
        "aest": "Australia/Sydney",
        "nzst": "Pacific/Auckland",
        "hst": "Pacific/Honolulu",
        "akst": "America/Anchorage",
    ]

    /// Look up a timezone for a city name or abbreviation (case-insensitive).
    static func timezone(for input: String) -> TimeZone? {
        let key = input.lowercased().trimmingCharacters(in: .whitespaces)
        if let identifier = cityToTimezone[key] {
            return TimeZone(identifier: identifier)
        }
        // Try as a raw IANA identifier
        return TimeZone(identifier: input)
    }
}
