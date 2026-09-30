import Foundation
import MapKit

/// An optional city or town, kept only on this device. Zalla never asks iOS for your location.
enum LocationSettings {
    static let cityKey = "locationCity"
    static let latitudeKey = "locationCityLatitude"
    static let longitudeKey = "locationCityLongitude"
    static let searchKey = "locationUseInSearch"
    static let sitesKey = "locationSites"

    static func city(_ defaults: UserDefaults = .standard) -> String {
        (defaults.string(forKey: cityKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func usesCityInSearch(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: searchKey) && !city(defaults).isEmpty
    }

    /// The saved city center, when the city has been looked up.
    static func coordinate(_ defaults: UserDefaults = .standard) -> (latitude: Double, longitude: Double)? {
        guard defaults.object(forKey: latitudeKey) != nil, defaults.object(forKey: longitudeKey) != nil else { return nil }
        let latitude = defaults.double(forKey: latitudeKey)
        let longitude = defaults.double(forKey: longitudeKey)
        guard abs(latitude) <= 90, abs(longitude) <= 180 else { return nil }
        return (latitude, longitude)
    }

    static func sites(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: sitesKey) ?? []
    }

    static func isShared(withHost host: String, _ defaults: UserDefaults = .standard) -> Bool {
        sites(defaults).contains(host)
    }

    static func setShared(_ shared: Bool, withHost host: String, _ defaults: UserDefaults = .standard) {
        var list = sites(defaults).filter { $0 != host }
        if shared { list.append(host) }
        list.sort()
        if list.isEmpty {
            defaults.removeObject(forKey: sitesKey)
        } else {
            defaults.set(list, forKey: sitesKey)
        }
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    /// The city center to hand a site, or nil when the site was not given permission or no city is saved.
    static func coordinate(forHost host: String, _ defaults: UserDefaults = .standard) -> (latitude: Double, longitude: Double)? {
        guard isShared(withHost: host, defaults) else { return nil }
        return coordinate(defaults)
    }

    static func save(city: String, latitude: Double?, longitude: Double?, _ defaults: UserDefaults = .standard) {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: cityKey)
        if let latitude, let longitude {
            defaults.set(latitude, forKey: latitudeKey)
            defaults.set(longitude, forKey: longitudeKey)
        } else {
            defaults.removeObject(forKey: latitudeKey)
            defaults.removeObject(forKey: longitudeKey)
        }
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        for key in [cityKey, latitudeKey, longitudeKey, searchKey, sitesKey] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Finds the city center once, using Apple Maps place search. Only the city name is sent.
    /// This does not use GPS, and iOS does not ask for location permission.
    static func lookUpCenter(of city: String) async -> (latitude: Double, longitude: Double)? {
        for types in [MKLocalSearch.ResultType.address, MKLocalSearch.ResultType.pointOfInterest] {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = city
            request.resultTypes = types
            guard let response = try? await MKLocalSearch(request: request).start(),
                  let item = response.mapItems.first else { continue }
            let coordinate = item.placemark.coordinate
            if CLLocationCoordinate2DIsValid(coordinate) {
                return (coordinate.latitude, coordinate.longitude)
            }
        }
        return nil
    }
}

/// Adds the saved city to searches that are clearly about somewhere nearby.
enum LocalSearch {
    private static let nearPhrases = ["near me", "nearby", "around me", "close to me", "closest", "nearest"]

    private static let localWords: Set<String> = [
        "restaurant", "restaurants", "pizza", "coffee", "cafe", "cafes", "bar", "bars", "brunch", "lunch", "dinner",
        "takeout", "bakery", "grocery", "pharmacy", "hospital", "urgent", "dentist", "doctor", "vet", "gym",
        "hotel", "hotels", "mechanic", "plumber", "electrician", "barber", "salon", "gas", "parking", "library",
        "weather", "forecast", "traffic", "movies", "showtimes", "events", "things"
    ]

    /// The query with the city added, or unchanged when it is not a local search.
    static func augmented(_ query: String, city rawCity: String?) -> String {
        let city = (rawCity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty, !text.isEmpty else { return query }
        let lower = text.lowercased()
        if lower.contains(city.lowercased()) { return query }
        for phrase in nearPhrases {
            if let range = lower.range(of: phrase) {
                var result = text
                let start = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
                let end = text.index(start, offsetBy: phrase.count)
                result.replaceSubrange(start..<end, with: "in " + city)
                return result
            }
        }
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        if !words.isDisjoint(with: localWords) {
            return text + " " + city
        }
        return query
    }

    /// Uses the saved city only when the setting is on.
    static func augmentedForCurrentSettings(_ query: String, defaults: UserDefaults = .standard) -> String {
        guard LocationSettings.usesCityInSearch(defaults) else { return query }
        return augmented(query, city: LocationSettings.city(defaults))
    }
}
