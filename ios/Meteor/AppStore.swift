import Foundation
import SwiftUI
import UIKit

@MainActor final class AppStore: ObservableObject {
    @Published var language: String = UserDefaults.standard.string(forKey: "meteor.language") ?? ""
    @Published var identity: DeviceIdentity?; @Published var panel: PanelState?
    @Published var activationCode = ""; @Published var activationStatus = "pending"; @Published var message = ""
    @Published var sources: [Source] = []; @Published var sourceID = "main"
    @Published var favorites: [MediaItem] = []; @Published var playback: PlaybackRequest?
    @Published var busy = false
    let catalogue = CatalogService()
    private var localSources: [Source] = []; private var registered = false
    private var polling: Task<Void, Never>?; private var lastHeartbeat = Date.distantPast
    var active: Bool { panel?.active == true }
    var currentSource: Source? { sources.first { $0.id == sourceID } ?? sources.first }
    init() {
        do {
            identity = try SecureStore.identity()
            registered = (try SecureStore.read("registered", as: Bool.self)) ?? false
            localSources = (try SecureStore.read("sources", as: [Source].self)) ?? []
            favorites = (try SecureStore.read("favorites", as: [MediaItem].self)) ?? []
        } catch { message = MeteorError.secureStorage.localizedDescription }
    }
    func setLanguage(_ value: String) { language = ["sk","hu","en"].contains(value) ? value : "sk"; UserDefaults.standard.set(language, forKey: "meteor.language") }
    func resume() {
        guard polling == nil, !language.isEmpty, identity != nil else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }; await self.checkPanel()
                do { try await Task.sleep(nanoseconds: self.active ? 30_000_000_000 : 10_000_000_000) } catch { break }
            }
        }
    }
    func pause() { polling?.cancel(); polling = nil }
    func panelRequest(_ path: String, body: Object? = nil) async throws -> Object {
        guard let identity else { throw MeteorError.secureStorage }
        let headers = ["X-Device-Id": identity.id, "Authorization": "Bearer " + identity.secret, "X-Meteor-Runtime": "1"]
        guard let o = try await HTTPClient.json(MeteorConfig.panel.appendingPathComponent(path), body: body, headers: headers, limit: 1024 * 1024, redirects: false) as? Object else { throw MeteorError.invalidData }; return o
    }
    func checkPanel() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            if !registered {
                guard let identity else { throw MeteorError.secureStorage }
                let o = try await panelRequest("/api/device/register", body: ["id": identity.id, "secret": identity.secret, "model": UIDevice.current.model, "system": "iOS " + UIDevice.current.systemVersion, "version": MeteorConfig.version])
                guard string(o["id"]).lowercased() == identity.id, !string(o["code"]).isEmpty else { throw MeteorError.invalidData }
                activationCode = string(o["code"]); try SecureStore.write("registered", true); registered = true
            }
            let next = try PanelState(await panelRequest("/api/device/status")); try Task.checkCancellation()
            if !next.code.isEmpty { activationCode = next.code }; activationStatus = next.status
            if !next.active { panel = nil; playback = nil; sources = []; try SecureStore.write("last-panel", Optional<PanelState>.none); message = ""; return }
            let changed = panel?.sources != next.sources
            panel = next; sources = next.sources + localSources
            if !sources.contains(where: { $0.id == sourceID }), let first = sources.first { sourceID = first.id }
            if changed { await catalogue.clear() }
            try SecureStore.write("last-panel", next); message = ""
            if Date().timeIntervalSince(lastHeartbeat) >= 60 {
                _ = try? await panelRequest("/api/device/heartbeat", body: ["version": MeteorConfig.version, "system": "iOS " + UIDevice.current.systemVersion, "model": UIDevice.current.model, "configured_player": "Apple AVPlayer", "last_player": playback == nil ? "" : "Apple AVPlayer", "runtime_capable": false])
                lastHeartbeat = Date()
            }
        } catch is CancellationError { }
        catch {
            if case MeteorError.http(401) = error { registered = false; try? SecureStore.write("registered", false); try? SecureStore.write("last-panel", Optional<PanelState>.none); panel = nil; playback = nil; sources = []; message = "HTTP 401"; return }
            if !active, let cached = try? SecureStore.read("last-panel", as: PanelState.self), cached.active, Date().timeIntervalSince(cached.checked) < 86400 { panel = cached; sources = cached.sources + localSources }
            message = active ? tr("Panel je nedostupný. Používam posledné platné nastavenia.","A panel nem elérhető. Az utolsó beállításokat használom.","Panel unavailable. Using last valid settings.") : tr("Spojenie s Panelom zlyhalo. Skús znova.","A panel nem érhető el. Próbáld újra.","Could not reach the panel. Try again.")
        }
    }
    func addSource(_ source: Source) throws {
        guard active, (!source.localFile.isEmpty || httpURL(source.type == "m3u" ? source.url : source.server) != nil) else { throw MeteorError.invalidURL }
        var next = localSources; next.append(source); try SecureStore.write("sources", next); localSources = next
        sources = (panel?.sources ?? []) + localSources; sourceID = source.id
    }
    func deleteLocalSource(_ source: Source) throws {
        guard localSources.contains(where: { $0.id == source.id }) else { return }
        let next = localSources.filter { $0.id != source.id }; try SecureStore.write("sources", next); localSources = next; sources = (panel?.sources ?? []) + next
        if sourceID == source.id { sourceID = sources.first?.id ?? "main" }
    }
    func isLocal(_ source: Source) -> Bool { localSources.contains { $0.id == source.id } }
    func toggleFavorite(_ item: MediaItem) {
        var next = favorites; if let index = next.firstIndex(where: { $0.id == item.id }) { next.remove(at: index) } else { next.append(item) }
        do { try SecureStore.write("favorites", next); favorites = next } catch { message = error.localizedDescription }
    }
    func play(_ item: MediaItem, queue: [MediaItem] = [], resume: Bool = true) {
        guard active, let source = sources.first(where: { $0.id == item.sourceID }) else { return }
        do {
            let url: URL
            if !item.address.isEmpty { guard let address = httpURL(item.address) else { throw MeteorError.invalidURL }; url = address }
            else { url = try source.stream(item.kind == .movie ? "movie" : "live", item.streamID, item.kind == .movie ? item.ext : "m3u8") }
            if let host = url.host?.lowercased(), ["youtube.com","www.youtube.com","youtu.be","twitch.tv","www.twitch.tv"].contains(host) { UIApplication.shared.open(url); return }
            playback = PlaybackRequest(item: item, url: url, queue: queue, resumeAllowed: resume)
        } catch { message = error.localizedDescription }
    }
    func playArchive(_ item: MediaItem, programme: Programme, zone: TimeZone) {
        guard active, let source = sources.first(where: { $0.id == item.sourceID }), programme.playable(days: item.archiveDays) else { return }
        do {
            var clip = item; clip.id += ":" + programme.id; clip.name = programme.title; clip.kind = .movie
            clip.address = try source.archive(item.streamID, start: programme.start, end: min(Date(), programme.end), zone: zone).absoluteString
            play(clip, resume: false)
        } catch { message = error.localizedDescription }
    }
}
