import Foundation
import CryptoKit

enum MeteorConfig {
    static let version = "0.1.0"
    static let panel = URL(string: "https://bipeor-control.bigiboy1990413.chatgpt.site")!
}
func tr(_ sk: String, _ hu: String, _ en: String) -> String {
    switch UserDefaults.standard.string(forKey: "meteor.language") ?? "sk" { case "hu": return hu; case "en": return en; default: return sk }
}
typealias Object = [String: Any]
func string(_ value: Any?) -> String { if let v = value as? String { return v }; if let v = value as? NSNumber { return v.stringValue }; return "" }
func number(_ value: Any?) -> Double { Double(string(value)) ?? 0 }
func flag(_ value: Any?) -> Bool { let v = string(value).lowercased(); return v == "1" || v == "true" }
func httpURL(_ text: String) -> URL? {
    guard let c = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          ["http", "https"].contains(c.scheme?.lowercased() ?? ""), c.host != nil, c.user == nil, c.password == nil else { return nil }
    return c.url
}
func component(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? "" }
func decodedTitle(_ text: String) -> String {
    guard !text.isEmpty, text.count % 4 == 0, let data = Data(base64Encoded: text), let value = String(data: data, encoding: .utf8),
          !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return text }
    return value
}
enum MeteorError: LocalizedError {
    case http(Int), tooLarge, invalidData, invalidURL, unavailable, secureStorage
    var errorDescription: String? {
        switch self {
        case .http(let code): return tr("Server odpovedal HTTP \(code).", "HTTP \(code) szerverválasz.", "Server returned HTTP \(code).")
        case .tooLarge: return tr("Odpoveď prekročila povolenú veľkosť.", "A válasz túl nagy.", "Response exceeded the size limit.")
        case .invalidURL: return tr("Zadaj platnú HTTP alebo HTTPS adresu.", "Érvényes HTTP vagy HTTPS cím szükséges.", "Enter a valid HTTP or HTTPS address.")
        case .secureStorage: return tr("Zabezpečené úložisko nie je dostupné.", "A biztonságos tároló nem elérhető.", "Secure storage unavailable.")
        case .invalidData: return tr("Server vrátil neplatné údaje.", "Érvénytelen szerveradatok.", "Server returned invalid data.")
        case .unavailable: return tr("Obsah nie je dostupný pre tento zdroj.", "A tartalom ehhez a forráshoz nem elérhető.", "Content is unavailable for this source.")
        }
    }
}
struct Source: Codable, Identifiable, Equatable {
    var id: String; var name: String; var type: String
    var localFile: String = ""
    var server: String = ""; var username: String = ""; var password: String = ""; var url: String = ""
    init(id: String, name: String, type: String, server: String = "", username: String = "", password: String = "", url: String = "") {
        self.id = id; self.name = name; self.type = type; self.server = server; self.username = username; self.password = password; self.url = url
    }
    init?(_ o: Object) {
        let type = string(o["type"]); let server = string(o["server"]); let url = string(o["url"])
        guard type == "m3u" ? httpURL(url) != nil : httpURL(server) != nil else { return nil }
        self.init(id: string(o["id"]), name: string(o["name"]), type: type == "m3u" ? "m3u" : "xtream", server: server, username: string(o["username"]), password: string(o["password"]), url: url)
    }
    func base() throws -> String {
        guard var u = URLComponents(string: server), httpURL(server) != nil, u.query == nil, u.fragment == nil else { throw MeteorError.invalidURL }
        u.path = u.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")); if !u.path.isEmpty { u.path = "/" + u.path }
        guard let value = u.string else { throw MeteorError.invalidURL }; return value
    }
    func api(_ action: String = "", _ params: [String: String] = [:]) throws -> URL {
        var c = URLComponents(string: try base() + "/player_api.php")!
        var query = [URLQueryItem(name: "username", value: username), URLQueryItem(name: "password", value: password)]
        if !action.isEmpty { query.append(URLQueryItem(name: "action", value: action)) }
        for key in params.keys.sorted() { query.append(URLQueryItem(name: key, value: params[key])) }
        c.queryItems = query; c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B"); guard let result = c.url else { throw MeteorError.invalidURL }; return result
    }
    func stream(_ kind: String, _ id: String, _ ext: String) throws -> URL {
        guard !id.isEmpty, id.allSatisfy(\.isNumber), ext.range(of: "^[A-Za-z0-9]{1,8}$", options: .regularExpression) != nil else { throw MeteorError.invalidData }
        guard let result = URL(string: try base() + "/\(kind)/\(component(username))/\(component(password))/\(id).\(ext)") else { throw MeteorError.invalidURL }; return result
    }
    func archive(_ id: String, start: Date, end: Date, zone: TimeZone) throws -> URL {
        guard end > start, !id.isEmpty, id.allSatisfy(\.isNumber) else { throw MeteorError.invalidData }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd:HH-mm"
        let minutes = max(1, Int(ceil(end.timeIntervalSince(start) / 60)))
        guard let result = URL(string: try base() + "/timeshift/\(component(username))/\(component(password))/\(minutes)/\(f.string(from: start))/\(id).m3u8") else { throw MeteorError.invalidURL }; return result
    }
}
enum CatalogKind: String, CaseIterable, Identifiable, Codable {
    case live, movie, series, archive, radio, favorites
    var id: String { rawValue }
    var title: String {
        switch self { case .live: return tr("Živá TV","Élő TV","Live TV"); case .movie: return tr("Filmy","Filmek","Movies"); case .series: return tr("Seriály","Sorozatok","Series"); case .archive: return tr("Archív","Archív","Catch-up"); case .radio: return tr("Rádio","Rádió","Radio"); case .favorites: return tr("Obľúbené","Kedvencek","Favorites") }
    }
    var symbol: String {
        switch self { case .live: return "tv"; case .movie: return "film"; case .series: return "play.rectangle.on.rectangle"; case .archive: return "clock.arrow.circlepath"; case .radio: return "radio"; case .favorites: return "star" }
    }
}
struct MediaItem: Codable, Identifiable, Hashable {
    var id: String; var sourceID: String; var streamID: String; var name: String
    var kind: CatalogKind; var category: String = ""; var logo: String = ""; var address: String = ""; var ext: String = "mp4"
    var archiveDays: Int = 0; var description: String = ""
}
struct Programme: Identifiable {
    var id: String; var title: String; var description: String; var start: Date; var end: Date
    func playable(days: Int, now: Date = Date()) -> Bool { days > 0 && start < now && end > start && start >= now.addingTimeInterval(-Double(days) * 86400) }
}
struct Episode: Identifiable { var id: String; var season: String; var number: Int; var item: MediaItem }
struct PlaybackRequest: Identifiable {
    let id = UUID(); let item: MediaItem; let url: URL; var queue: [MediaItem] = []; var resumeAllowed: Bool = true
}
struct Catalogue { var items: [MediaItem]; var groups: [String: String] }
struct PanelState: Codable {
    var status: String; var code: String; var label: String; var expires: Double
    var sources: [Source]; var userAgent: String; var checked: Date
    init(_ o: Object) throws {
        status = string(o["status"]); guard !status.isEmpty else { throw MeteorError.invalidData }
        code = string(o["code"]); label = string(o["label"]); expires = number(o["expires_at"]); checked = Date()
        sources = []; userAgent = "Mozilla/5.0"
        if let c = o["connection"] as? Object, let source = Source(c.merging(["id": "main", "name": "Meteor", "type": "xtream"]) { _, new in new }) { sources.append(source) }
        for s in o["additional_sources"] as? [Object] ?? [] where flag(s["enabled"]) { if let parsed = Source(s) { sources.append(parsed) } }
        if let p = o["playback"] as? Object { let agent = string(p["user_agent"]); if !agent.isEmpty && !agent.contains("\n") && !agent.contains("\r") { userAgent = String(agent.prefix(512)) } }
    }
    var active: Bool { status == "active" && (expires <= 0 || expires > Date().timeIntervalSince1970) }
}
struct M3UParser {
    static func parse(_ text: String, sourceID: String) throws -> [MediaItem] {
        guard text.utf8.count <= 32 * 1024 * 1024 else { throw MeteorError.tooLarge }
        let lines = text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines)
        guard lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#EXTM3U") }) else { throw MeteorError.invalidData }
        var items: [MediaItem] = []; var name = ""; var group = ""; var logo = ""; var pending = false; var occurrences: [String: Int] = [:]
        let regex = try NSRegularExpression(pattern: #"([\w-]+)="([^"]*)""#)
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {
                var inQuote = false; var comma: String.Index?
                for index in line.indices { if line[index] == "\"" { inQuote.toggle() }; if line[index] == "," && !inQuote { comma = index; break } }
                name = comma.map { String(line[line.index(after: $0)...]) } ?? ""; group = ""; logo = ""; pending = true
                let ns = line as NSString
                for m in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                    let key = ns.substring(with: m.range(at: 1)); let value = ns.substring(with: m.range(at: 2))
                    if key == "group-title" { group = value }; if key == "tvg-logo" { logo = value }; if name.isEmpty && key == "tvg-name" { name = value }
                }
            } else if !line.isEmpty && !line.hasPrefix("#"), pending, let url = httpURL(line) {
                // Include the occurrence number: identical URLs may intentionally appear more than once.
                let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
                let duplicate = occurrences[url.absoluteString, default: 0]; occurrences[url.absoluteString] = duplicate + 1
                let id = "\(sourceID):m3u:\(digest):\(duplicate)"
                let ext = url.pathExtension.lowercased()
                let kind: CatalogKind = ["mp3","aac","m4a","flac","ogg"].contains(ext) || group.lowercased().contains("radio") || group.lowercased().contains("rádio") ? .radio : ["mp4","m4v","mov","mkv","avi"].contains(ext) ? .movie : .live
                items.append(MediaItem(id: id, sourceID: sourceID, streamID: "", name: name.isEmpty ? "TV \(items.count + 1)" : name, kind: kind, category: group, logo: logo, address: url.absoluteString, ext: url.pathExtension))
                pending = false
                if items.count > 100_000 { throw MeteorError.tooLarge }
            }
        }
        return items
    }
}
