import Foundation

actor CatalogService {
    private var cache: [String: Catalogue] = [:]
    func clear() { cache.removeAll() }
    func provider(_ source: Source, action: String = "", params: [String: String] = [:]) async throws -> Any {
        try await HTTPClient.json(source.api(action, params))
    }
    func catalogue(_ source: Source, kind: CatalogKind, refresh: Bool = false) async throws -> Catalogue {
        let key = source.id + ":" + kind.rawValue
        if !refresh, let result = cache[key] { return result }
        let result: Catalogue
        if source.type == "m3u" {
            
            let all: [MediaItem]
            if !refresh, let stored = cache[source.id + ":m3u"] { all = stored.items }
            else {
                let data: Data
                if !source.localFile.isEmpty {
                    guard source.localFile.range(of: "^[a-f0-9-]+\\.m3u$", options: .regularExpression) != nil else { throw MeteorError.invalidURL }
                    let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Playlists", isDirectory: true)
                    let file = folder.appendingPathComponent(source.localFile)
                    guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 32 * 1024 * 1024 else { throw MeteorError.tooLarge }
                    data = try Data(contentsOf: file)
                } else {
                    guard let url = httpURL(source.url) else { throw MeteorError.invalidURL }
                    data = try await HTTPClient.fetch(URLRequest(url: url), limit: 32 * 1024 * 1024)
                }
                guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw MeteorError.invalidData }
                all = try M3UParser.parse(text, sourceID: source.id); cache[source.id + ":m3u"] = Catalogue(items: all, groups: [:])
            }
            guard kind != .archive && kind != .series else { throw MeteorError.unavailable }
            let rows = all.filter { $0.kind == kind }
            result = Catalogue(items: rows, groups: Dictionary(rows.map { ($0.category, $0.category) }, uniquingKeysWith: { a, _ in a }))
        } else {
            let family = kind == .movie ? "vod" : kind == .series ? "series" : "live"
            let action = kind == .series ? "get_series" : "get_\(family)_streams"
            async let raw = provider(source, action: action)
            async let categories = try? provider(source, action: "get_\(family)_categories")
            guard let records = try await raw as? [Object] else { throw MeteorError.invalidData }
            var rows: [MediaItem] = []; var seen = Set<String>()
            for o in records {
                let sid = string(o[kind == .series ? "series_id" : "stream_id"])
                guard !sid.isEmpty, sid.allSatisfy(\.isNumber) else { continue }
                let name = string(o["name"]); let isRadio = family == "live" && (string(o["stream_type"]) == "radio_streams" || flag(o["is_radio"]))
                if kind == .radio && !isRadio { continue }; if kind == .live && isRadio { continue }
                let days = max(0, Int(number(o["tv_archive_duration"]))); if kind == .archive && (!flag(o["tv_archive"]) || days <= 0) { continue }
                let rowKind: CatalogKind = kind == .archive ? .live : kind
                let id = source.id + ":" + rowKind.rawValue + ":" + sid
                guard seen.insert(id).inserted else { continue }
                rows.append(MediaItem(id: id, sourceID: source.id, streamID: sid, name: name.isEmpty ? sid : name, kind: rowKind, category: string(o["category_id"]), logo: string(o[kind == .series ? "cover" : "stream_icon"]), ext: string(o["container_extension"]).isEmpty ? "mp4" : string(o["container_extension"]), archiveDays: days))
            }
            var groups: [String: String] = [:]
            for group in await categories as? [Object] ?? [] { groups[string(group["category_id"])] = string(group["category_name"]) }
            result = Catalogue(items: rows, groups: groups)
        }
        cache[key] = result; return result
    }
    func detail(_ source: Source, item: MediaItem) async throws -> String {
        guard source.type != "m3u", item.kind == .movie else { return item.description }
        guard let o = try await provider(source, action: "get_vod_info", params: ["vod_id": item.streamID]) as? Object else { return item.description }
        let info = o["info"] as? Object ?? [:]
        return string(info["plot"]).isEmpty ? string(info["description"]) : string(info["plot"])
    }
    func episodes(_ source: Source, series: MediaItem) async throws -> [Episode] {
        guard let o = try await provider(source, action: "get_series_info", params: ["series_id": series.streamID]) as? Object, let seasons = o["episodes"] as? Object else { throw MeteorError.invalidData }
        var result: [Episode] = []
        for season in seasons.keys.sorted(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) {
            for episode in seasons[season] as? [Object] ?? [] {
                let sid = string(episode["id"]); guard !sid.isEmpty, sid.allSatisfy(\.isNumber) else { continue }
                let n = Int(number(episode["episode_num"])); let ext = string(episode["container_extension"])
                let name = decodedTitle(string(episode["title"]))
                let item = MediaItem(id: source.id + ":episode:" + sid, sourceID: source.id, streamID: sid, name: name.isEmpty ? series.name + " · \(n)" : name, kind: .movie, category: series.category, logo: series.logo, address: try source.stream("series", sid, ext.isEmpty ? "mp4" : ext).absoluteString, ext: ext)
                result.append(Episode(id: item.id, season: season, number: n, item: item))
            }
        }
        return result.sorted { $0.season == $1.season ? $0.number < $1.number : (Int($0.season) ?? 0) < (Int($1.season) ?? 0) }
    }
    func programmes(_ source: Source, channel: MediaItem) async throws -> (items: [Programme], zone: TimeZone) {
        guard source.type == "xtream" else { throw MeteorError.unavailable }
        async let epg = provider(source, action: "get_simple_data_table", params: ["stream_id": channel.streamID])
        let account = try? await provider(source) as? Object
        let zoneName = string((account?["server_info"] as? Object)?["timezone"])
        let zone = TimeZone(identifier: zoneName) ?? .current
        guard let o = try await epg as? Object else { throw MeteorError.invalidData }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = zone; formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        func date(_ o: Object, _ stamp: String, _ text: String) -> Date? {
            let n = number(o[stamp]); if n > 0 { return Date(timeIntervalSince1970: n > 1e12 ? n / 1000 : n) }
            return formatter.date(from: string(o[text]))
        }
        var items: [Programme] = []
        for p in o["epg_listings"] as? [Object] ?? [] {
            guard let start = date(p, "start_timestamp", "start"), let end = date(p, "stop_timestamp", "end"), end > start else { continue }
            items.append(Programme(id: channel.id + ":\(start.timeIntervalSince1970)", title: decodedTitle(string(p["title"])), description: decodedTitle(string(p["description"])), start: start, end: end))
        }
        return (items.sorted { $0.start < $1.start }, zone)
    }
}
