import Foundation

/// A well-known site offered in the Add Shortcut list.
struct PopularSite: Identifiable, Equatable {
    let name: String
    let domain: String
    let symbolName: String

    var id: String { domain }
    var urlString: String { "https://" + domain }
}

/// A bundled list of popular sites. Nothing is fetched and nothing is sent anywhere: it is just a list.
enum PopularSites {
    static let all: [PopularSite] = [
        PopularSite(name: "Google", domain: "google.com", symbolName: "magnifyingglass"),
        PopularSite(name: "YouTube", domain: "youtube.com", symbolName: "play.rectangle"),
        PopularSite(name: "Facebook", domain: "facebook.com", symbolName: "person.2"),
        PopularSite(name: "Instagram", domain: "instagram.com", symbolName: "camera"),
        PopularSite(name: "X", domain: "x.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Reddit", domain: "reddit.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Wikipedia", domain: "wikipedia.org", symbolName: "book"),
        PopularSite(name: "Amazon", domain: "amazon.com", symbolName: "cart"),
        PopularSite(name: "Netflix", domain: "netflix.com", symbolName: "play.rectangle"),
        PopularSite(name: "LinkedIn", domain: "linkedin.com", symbolName: "person.crop.circle"),
        PopularSite(name: "TikTok", domain: "tiktok.com", symbolName: "music.note"),
        PopularSite(name: "WhatsApp", domain: "web.whatsapp.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Pinterest", domain: "pinterest.com", symbolName: "star"),
        PopularSite(name: "Twitch", domain: "twitch.tv", symbolName: "gamecontroller"),
        PopularSite(name: "Discord", domain: "discord.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Spotify", domain: "open.spotify.com", symbolName: "music.note"),
        PopularSite(name: "Apple", domain: "apple.com", symbolName: "apple.logo"),
        PopularSite(name: "iCloud", domain: "icloud.com", symbolName: "cloud"),
        PopularSite(name: "Microsoft", domain: "microsoft.com", symbolName: "square.grid.2x2"),
        PopularSite(name: "Outlook", domain: "outlook.com", symbolName: "envelope"),
        PopularSite(name: "Gmail", domain: "mail.google.com", symbolName: "envelope"),
        PopularSite(name: "Proton Mail", domain: "mail.proton.me", symbolName: "envelope"),
        PopularSite(name: "Yahoo", domain: "yahoo.com", symbolName: "globe"),
        PopularSite(name: "Bing", domain: "bing.com", symbolName: "magnifyingglass"),
        PopularSite(name: "DuckDuckGo", domain: "duckduckgo.com", symbolName: "magnifyingglass"),
        PopularSite(name: "Brave Search", domain: "search.brave.com", symbolName: "magnifyingglass"),
        PopularSite(name: "Startpage", domain: "startpage.com", symbolName: "magnifyingglass"),
        PopularSite(name: "Ecosia", domain: "ecosia.org", symbolName: "leaf"),
        PopularSite(name: "Kagi", domain: "kagi.com", symbolName: "magnifyingglass"),
        PopularSite(name: "GitHub", domain: "github.com", symbolName: "chevron.left.forwardslash.chevron.right"),
        PopularSite(name: "Stack Overflow", domain: "stackoverflow.com", symbolName: "chevron.left.forwardslash.chevron.right"),
        PopularSite(name: "Google Maps", domain: "maps.google.com", symbolName: "map"),
        PopularSite(name: "Apple Maps", domain: "maps.apple.com", symbolName: "map"),
        PopularSite(name: "Google Drive", domain: "drive.google.com", symbolName: "folder"),
        PopularSite(name: "Google Docs", domain: "docs.google.com", symbolName: "doc.text"),
        PopularSite(name: "Google Translate", domain: "translate.google.com", symbolName: "globe"),
        PopularSite(name: "Google News", domain: "news.google.com", symbolName: "newspaper"),
        PopularSite(name: "Dropbox", domain: "dropbox.com", symbolName: "folder"),
        PopularSite(name: "Notion", domain: "notion.so", symbolName: "doc.text"),
        PopularSite(name: "Slack", domain: "slack.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Zoom", domain: "zoom.us", symbolName: "camera"),
        PopularSite(name: "Canva", domain: "canva.com", symbolName: "paintbrush"),
        PopularSite(name: "Figma", domain: "figma.com", symbolName: "paintbrush"),
        PopularSite(name: "OpenAI", domain: "openai.com", symbolName: "bolt"),
        PopularSite(name: "ChatGPT", domain: "chatgpt.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Grok", domain: "grok.com", symbolName: "bolt"),
        PopularSite(name: "BBC News", domain: "bbc.com", symbolName: "newspaper"),
        PopularSite(name: "CNN", domain: "cnn.com", symbolName: "newspaper"),
        PopularSite(name: "The New York Times", domain: "nytimes.com", symbolName: "newspaper"),
        PopularSite(name: "The Guardian", domain: "theguardian.com", symbolName: "newspaper"),
        PopularSite(name: "Reuters", domain: "reuters.com", symbolName: "newspaper"),
        PopularSite(name: "Associated Press", domain: "apnews.com", symbolName: "newspaper"),
        PopularSite(name: "NPR", domain: "npr.org", symbolName: "newspaper"),
        PopularSite(name: "Washington Post", domain: "washingtonpost.com", symbolName: "newspaper"),
        PopularSite(name: "Weather", domain: "weather.com", symbolName: "cloud"),
        PopularSite(name: "ESPN", domain: "espn.com", symbolName: "gamecontroller"),
        PopularSite(name: "IMDb", domain: "imdb.com", symbolName: "play.rectangle"),
        PopularSite(name: "Disney+", domain: "disneyplus.com", symbolName: "play.rectangle"),
        PopularSite(name: "Hulu", domain: "hulu.com", symbolName: "play.rectangle"),
        PopularSite(name: "Max", domain: "max.com", symbolName: "play.rectangle"),
        PopularSite(name: "Prime Video", domain: "primevideo.com", symbolName: "play.rectangle"),
        PopularSite(name: "SoundCloud", domain: "soundcloud.com", symbolName: "music.note"),
        PopularSite(name: "Bandcamp", domain: "bandcamp.com", symbolName: "music.note"),
        PopularSite(name: "Steam", domain: "store.steampowered.com", symbolName: "gamecontroller"),
        PopularSite(name: "Epic Games", domain: "epicgames.com", symbolName: "gamecontroller"),
        PopularSite(name: "eBay", domain: "ebay.com", symbolName: "cart"),
        PopularSite(name: "Etsy", domain: "etsy.com", symbolName: "cart"),
        PopularSite(name: "Walmart", domain: "walmart.com", symbolName: "cart"),
        PopularSite(name: "Target", domain: "target.com", symbolName: "cart"),
        PopularSite(name: "Best Buy", domain: "bestbuy.com", symbolName: "cart"),
        PopularSite(name: "AliExpress", domain: "aliexpress.com", symbolName: "cart"),
        PopularSite(name: "PayPal", domain: "paypal.com", symbolName: "creditcard"),
        PopularSite(name: "Airbnb", domain: "airbnb.com", symbolName: "house"),
        PopularSite(name: "Booking.com", domain: "booking.com", symbolName: "house"),
        PopularSite(name: "Tripadvisor", domain: "tripadvisor.com", symbolName: "map"),
        PopularSite(name: "Uber", domain: "uber.com", symbolName: "map"),
        PopularSite(name: "Yelp", domain: "yelp.com", symbolName: "star"),
        PopularSite(name: "Craigslist", domain: "craigslist.org", symbolName: "doc.text"),
        PopularSite(name: "Quora", domain: "quora.com", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Medium", domain: "medium.com", symbolName: "newspaper"),
        PopularSite(name: "Substack", domain: "substack.com", symbolName: "newspaper"),
        PopularSite(name: "Hacker News", domain: "news.ycombinator.com", symbolName: "newspaper"),
        PopularSite(name: "Mastodon", domain: "joinmastodon.org", symbolName: "person.2"),
        PopularSite(name: "Bluesky", domain: "bsky.app", symbolName: "cloud"),
        PopularSite(name: "Threads", domain: "threads.net", symbolName: "bubble.left.and.bubble.right"),
        PopularSite(name: "Snapchat", domain: "snapchat.com", symbolName: "camera"),
        PopularSite(name: "Telegram", domain: "web.telegram.org", symbolName: "paperplane"),
        PopularSite(name: "Signal", domain: "signal.org", symbolName: "lock.shield"),
        PopularSite(name: "Proton", domain: "proton.me", symbolName: "lock.shield"),
        PopularSite(name: "Cloudflare", domain: "cloudflare.com", symbolName: "cloud"),
        PopularSite(name: "Speedtest", domain: "speedtest.net", symbolName: "bolt"),
        PopularSite(name: "Archive.org", domain: "archive.org", symbolName: "book"),
        PopularSite(name: "Khan Academy", domain: "khanacademy.org", symbolName: "book"),
        PopularSite(name: "Coursera", domain: "coursera.org", symbolName: "book"),
        PopularSite(name: "Duolingo", domain: "duolingo.com", symbolName: "book"),
        PopularSite(name: "Goodreads", domain: "goodreads.com", symbolName: "book"),
        PopularSite(name: "Wolfram Alpha", domain: "wolframalpha.com", symbolName: "bolt"),
        PopularSite(name: "Merriam-Webster", domain: "merriam-webster.com", symbolName: "book"),
        PopularSite(name: "Indeed", domain: "indeed.com", symbolName: "person.crop.circle"),
        PopularSite(name: "Glassdoor", domain: "glassdoor.com", symbolName: "person.crop.circle"),
        PopularSite(name: "Zillow", domain: "zillow.com", symbolName: "house"),
        PopularSite(name: "Fandom", domain: "fandom.com", symbolName: "star"),
        PopularSite(name: "Imgur", domain: "imgur.com", symbolName: "camera"),
        PopularSite(name: "Vimeo", domain: "vimeo.com", symbolName: "play.rectangle"),
        PopularSite(name: "Adobe", domain: "adobe.com", symbolName: "paintbrush")
    ]

    /// Sites whose name or address contains the search text. An empty search returns everything.
    static func matching(_ query: String) -> [PopularSite] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.domain.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// The listed site for a host, if there is one. Used to give "Add to Dashboard" a proper name and icon.
    static func site(forHost host: String?) -> PopularSite? {
        guard var key = HTTPSOnly.normalizedHost(host) else { return nil }
        if key.hasPrefix("www.") { key.removeFirst(4) }
        return all.first { $0.domain == key }
    }
}
