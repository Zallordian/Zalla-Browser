import AppIntents
import WidgetKit

// What a person can change in the widget editor (touch and hold the widget, then Edit Widget).
// The raw values of the colors match the keys in WidgetShared.palette.

enum WidgetAccentChoice: String, AppEnum {
    case followApp, red, orange, yellow, green, blue, indigo, violet, pink, graphite

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Color"
    static var caseDisplayRepresentations: [WidgetAccentChoice: DisplayRepresentation] = [
        .followApp: "Follow Zalla",
        .red: "Red",
        .orange: "Orange",
        .yellow: "Yellow",
        .green: "Green",
        .blue: "Blue",
        .indigo: "Indigo",
        .violet: "Violet",
        .pink: "Pink",
        .graphite: "Graphite"
    ]
}

enum WidgetLook: String, AppEnum {
    case gradient, midnight, aurora, glass, paper

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Look"
    static var caseDisplayRepresentations: [WidgetLook: DisplayRepresentation] = [
        .gradient: "Accent gradient",
        .midnight: "Midnight",
        .aurora: "Aurora",
        .glass: "Glass",
        .paper: "Paper"
    ]

    var key: WidgetLookKey { WidgetLookKey(rawValue: rawValue) ?? WidgetLookKey.defaultLook }
}

enum WidgetFavoritesSource: String, AppEnum {
    case shortcuts, bookmarks

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Favorites"
    static var caseDisplayRepresentations: [WidgetFavoritesSource: DisplayRepresentation] = [
        .shortcuts: "Home shortcuts",
        .bookmarks: "Bookmarks"
    ]
}

enum WidgetFavoriteLimit: String, AppEnum {
    case four, six, eight

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "How many"
    static var caseDisplayRepresentations: [WidgetFavoriteLimit: DisplayRepresentation] = [
        .four: "Up to 4",
        .six: "Up to 6",
        .eight: "Up to 8"
    ]

    var value: Int {
        switch self {
        case .four: return 4
        case .six: return 6
        case .eight: return 8
        }
    }
}

/// Search and Privacy Report: color and look. (Burn It All keeps its ember look and has no options.)
struct ZallaStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Zalla widget"
    static var description = IntentDescription("Choose the color and look.")

    @Parameter(title: "Color", default: .followApp)
    var accent: WidgetAccentChoice

    @Parameter(title: "Look", default: .gradient)
    var look: WidgetLook
}

/// Favorites: color, look, which favorites, how many, and whether titles show.
struct ZallaFavoritesIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Zalla favorites"
    static var description = IntentDescription("Choose the color, look, and which favorites to show.")

    @Parameter(title: "Color", default: .followApp)
    var accent: WidgetAccentChoice

    @Parameter(title: "Look", default: .gradient)
    var look: WidgetLook

    @Parameter(title: "Favorites", default: .shortcuts)
    var source: WidgetFavoritesSource

    @Parameter(title: "How many", default: .eight)
    var limit: WidgetFavoriteLimit

    @Parameter(title: "Show titles", default: true)
    var showTitles: Bool
}
