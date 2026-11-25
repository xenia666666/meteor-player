import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scene
    var body: some View {
        Group {
            if store.language.isEmpty { LanguageView() }
            else if store.active { HomeView().id(store.language) }
            else { ActivationView() }
        }
        .preferredColorScheme(.dark).tint(.mint)
        .task(id: store.language) { store.resume() }
        .onChange(of: scene) { _, value in if value == .active { store.resume() } else if value == .background { store.pause() } }
        .fullScreenCover(item: $store.playback) { request in PlaybackScreen(request: request).id(request.id).environmentObject(store) }
    }
}
struct LanguageView: View {
    @EnvironmentObject var store: AppStore
    var body: some View { ScrollView { VStack(spacing: 24) { MeteorArtwork(edge: 220); Text("METEOR IPTV PLAYER").font(.title.bold()); ForEach([("sk","Slovenčina"),("hu","Magyar"),("en","English")], id: \.0) { code, title in Button(title) { store.setLanguage(code) }.buttonStyle(.borderedProminent).controlSize(.large) } }.frame(maxWidth: .infinity).padding(24) } }
}
struct MeteorArtwork: View {
    let edge: CGFloat
    var body: some View { Image("MeteorLogo").resizable().scaledToFit().frame(width: edge, height: edge).clipShape(RoundedRectangle(cornerRadius: edge * 0.16)).accessibilityHidden(true) }
}
struct ActivationView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) { MeteorArtwork(edge: 80); Text("METEOR").font(.largeTitle.bold()).foregroundStyle(.mint) }
            Text(tr("Aktivácia zariadenia","Készülékaktiválás","Device activation")).font(.title2.bold())
            Text(store.activationStatus == "blocked" ? tr("Zariadenie je zablokované.","A készülék le van tiltva.","Device is blocked.") : store.activationStatus == "expired" ? tr("Aktivácia vypršala.","Az aktiválás lejárt.","Activation expired.") : tr("Zariadenie čaká na schválenie v Paneli.","A készülék jóváhagyásra vár a panelen.","Waiting for approval in the Panel."))
            Text("ID: " + (store.identity?.id ?? "—")).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text(store.activationCode.isEmpty ? "…" : store.activationCode).font(.system(size: 30, weight: .bold, design: .monospaced)).textSelection(.enabled)
            if !store.message.isEmpty { Text(store.message).foregroundStyle(.orange) }
            Button { Task { await store.checkPanel() } } label: { if store.busy { ProgressView() } else { Text(tr("Skontrolovať znova","Újra ellenőrzés","Check again")) } }.buttonStyle(.borderedProminent).disabled(store.busy)
            Text("Meteor iOS " + MeteorConfig.version).foregroundStyle(.secondary)
        }.padding(28).frame(maxWidth: 600, alignment: .leading) } }
    }
}
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var settings = false; @State private var info = false
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.18), Color(red: 0.14, green: 0.02, blue: 0.27)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView { VStack(alignment: .leading, spacing: 22) {
                    HStack { VStack(alignment: .leading) { Text("METEOR").font(.largeTitle.bold().italic()); Text(Date(), format: .dateTime.weekday(.wide).day().month().year()).foregroundStyle(.secondary) }; Spacer(); Button { info = true } label: { Image(systemName: "info.circle").font(.title) }; Button { settings = true } label: { Image(systemName: "gearshape.circle").font(.title) } }
                    if store.sources.count > 1 { Picker(tr("Zoznam","Lista","Playlist"), selection: $store.sourceID) { ForEach(store.sources) { source in Text(source.name).tag(source.id) } }.pickerStyle(.menu) }
                    if !store.message.isEmpty { Text(store.message).foregroundStyle(.orange).font(.footnote) }
                    LazyVGrid(columns: columns, spacing: 14) { ForEach(CatalogKind.allCases) { kind in
                        NavigationLink(value: kind) { VStack(spacing: 20) { Image(systemName: kind.symbol).font(.system(size: 35)); Text(kind.title).font(.title3.bold()) }.frame(maxWidth: .infinity, minHeight: 145).background(tileColor(kind).opacity(0.65), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.2))) }.buttonStyle(.plain)
                    } }
                    Text(store.panel?.label ?? "").font(.footnote)
                    Text(tr("APP aktívne do: ","APP aktív eddig: ","APP active until: ") + expiry(store.panel?.expires ?? 0)).font(.footnote).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 1050) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogKind.self) { kind in CatalogScreen(kind: kind) }
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(isPresented: $info) { InfoView() }
        }
    }
    private func tileColor(_ kind: CatalogKind) -> Color { switch kind { case .live: return .blue; case .movie: return .pink; case .series: return .teal; case .archive: return .green; case .radio: return .purple; case .favorites: return .orange } }
}
func expiry(_ seconds: Double) -> String { seconds > 0 ? Date(timeIntervalSince1970: seconds).formatted(date: .numeric, time: .omitted) : tr("Bez obmedzenia","Korlátlan","Unlimited") }
struct InfoView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    var body: some View { NavigationStack { Form { Section("Meteor iOS " + MeteorConfig.version) { LabeledContent(tr("Zariadenie","Készülék","Device"), value: UIDevice.current.model); LabeledContent("iOS", value: UIDevice.current.systemVersion); Text("ID: " + (store.identity?.id ?? "—")).textSelection(.enabled); LabeledContent(tr("Aktivácia","Aktiválás","Activation"), value: expiry(store.panel?.expires ?? 0)); Text("Apple AVPlayer · HLS / MP4 / MP3") } }.navigationTitle(tr("Informácie","Információk","Information")).toolbar { Button(tr("Hotovo","Kész","Done")) { dismiss() } } } }
}
struct CatalogScreen: View {
    @EnvironmentObject private var store: AppStore
    let kind: CatalogKind
    @State private var data = Catalogue(items: [], groups: [:]); @State private var query = ""; @State private var group = ""; @State private var error = ""; @State private var loading = false
    @State private var selected: MediaItem?; @State private var programmes: MediaItem?
    var shown: [MediaItem] { (kind == .favorites ? store.favorites.filter { row in store.sources.contains { $0.id == row.sourceID } } : data.items).filter { (group.isEmpty || $0.category == group) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        VStack(spacing: 0) {
            if kind != .favorites { Picker(tr("Skupina","Csoport","Group"), selection: $group) { Text(tr("Všetky","Összes","All")).tag(""); ForEach(data.groups.keys.sorted { (data.groups[$0] ?? $0).localizedStandardCompare(data.groups[$1] ?? $1) == .orderedAscending }, id: \.self) { id in Text(data.groups[id] ?? id).tag(id) } }.pickerStyle(.menu).padding(.horizontal) }
            if loading { ProgressView().padding() }
            if !error.isEmpty { VStack { Text(error).multilineTextAlignment(.center); Button(tr("Znova","Újra","Retry")) { Task { await load(true) } } }.padding() }
            List(shown) { item in
                Button { if kind == .archive { programmes = item } else if item.kind == .live || item.kind == .radio { store.play(item) } else { selected = item } } label: {
                    HStack(spacing: 12) { ChannelArt(url: item.logo, symbol: item.kind.symbol); VStack(alignment: .leading, spacing: 4) { Text(item.name).foregroundStyle(.primary); if let groupName = data.groups[item.category], !groupName.isEmpty { Text(groupName).font(.caption).foregroundStyle(.secondary) } }; Spacer(); if store.favorites.contains(where: { $0.id == item.id }) { Image(systemName: "star.fill").foregroundStyle(.yellow) } }
                }.contextMenu {
                    Button(tr("Obľúbené ±","Kedvencek ±","Toggle favorite")) { store.toggleFavorite(item) }
                    if item.kind == .live && item.archiveDays > 0 { Button(tr("TV program / Archív","TV műsor / Archív","Guide / Catch-up")) { programmes = item } }
                }
            }.listStyle(.plain).overlay { if !loading && error.isEmpty && shown.isEmpty { ContentUnavailableView.search(text: query) } }
        }
        .navigationTitle(kind.title).searchable(text: $query)
        .toolbar { Button { Task { await load(true) } } label: { Image(systemName: "arrow.clockwise") }.disabled(loading) }
        .task(id: store.currentSource?.id) { group = ""; await load(false) }
        .sheet(item: $selected) { item in MediaDetails(item: item) }
        .sheet(item: $programmes) { item in ProgrammeScreen(channel: item) }
    }
    @MainActor private func load(_ refresh: Bool) async {
        guard kind != .favorites, let source = store.currentSource else { return }; loading = true; error = ""; defer { loading = false }
        do { let result = try await store.catalogue.catalogue(source, kind: kind, refresh: refresh); try Task.checkCancellation(); if source.id == store.currentSource?.id { data = result } }
        catch is CancellationError { } catch { if !Task.isCancelled { self.error = error is MeteorError ? error.localizedDescription : tr("Zoznam sa nepodarilo načítať.","A lista nem tölthető be.","Could not load playlist.") } }
    }
}
struct ChannelArt: View {
    let url: String; let symbol: String
    var body: some View { AsyncImage(url: httpURL(url)) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: symbol).font(.title2).foregroundStyle(.mint) }.frame(width: 58, height: 62).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8)) }
}
struct MediaDetails: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    let item: MediaItem
    @State private var plot = ""; @State private var episodes: [Episode] = []; @State private var error = ""; @State private var loading = false
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        HStack { ChannelArt(url: item.logo, symbol: item.kind.symbol); Text(item.name).font(.title2.bold()) }
        if loading { ProgressView() }; if !plot.isEmpty { Text(plot) }; if !error.isEmpty { Text(error).foregroundStyle(.orange) }
        Button(tr("Obľúbené ±","Kedvencek ±","Toggle favorite")) { store.toggleFavorite(item) }.buttonStyle(.bordered)
        if item.kind == .series {
            ForEach(episodes) { episode in Button { dismiss(); store.play(episode.item, queue: episodes.map(\.item)) } label: { Label("S\(episode.season) · \(episode.number) · " + episode.item.name, systemImage: "play.circle") }.padding(.vertical, 8) }
        } else {
            Button(tr("Pokračovať / Prehrať","Folytatás / Lejátszás","Resume / Play")) { dismiss(); store.play(item) }.buttonStyle(.borderedProminent)
            Button(tr("Od začiatku","Elölről","From beginning")) { UserDefaults.standard.removeObject(forKey: "resume." + item.id); dismiss(); store.play(item, resume: false) }.buttonStyle(.bordered)
        }
    }.padding() }.navigationTitle(item.kind.title).toolbar { Button(tr("Hotovo","Kész","Done")) { dismiss() } }.task {
        guard let source = store.sources.first(where: { $0.id == item.sourceID }) else { return }; loading = true; defer { loading = false }
        do { if item.kind == .series { episodes = try await store.catalogue.episodes(source, series: item) } else { plot = try await store.catalogue.detail(source, item: item) } } catch { self.error = tr("Podrobnosti nie sú dostupné.","A részletek nem elérhetők.","Details unavailable.") }
    } } }
}
struct ProgrammeScreen: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    let channel: MediaItem
    @State private var programmes: [Programme] = []; @State private var zone = TimeZone.current; @State private var error = ""; @State private var loading = true
    var body: some View { NavigationStack { List {
        if loading { ProgressView() }; if !error.isEmpty { Text(error) }
        ForEach(programmes) { p in VStack(alignment: .leading, spacing: 8) { Text(p.title).font(.headline); Text(p.start.formatted(date: .abbreviated, time: .shortened) + " – " + p.end.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary); if !p.description.isEmpty { Text(p.description).font(.footnote) }; if p.playable(days: channel.archiveDays) { Button(tr("Prehrať z archívu","Lejátszás az archívumból","Play catch-up")) { dismiss(); store.playArchive(channel, programme: p, zone: zone) } } }
        }
    }.navigationTitle(channel.name).toolbar { Button(tr("Hotovo","Kész","Done")) { dismiss() } }.task {
        defer { loading = false }; guard let source = store.sources.first(where: { $0.id == channel.sourceID }) else { return }
        do { let result = try await store.catalogue.programmes(source, channel: channel); programmes = result.items; zone = result.zone } catch { self.error = tr("TV program nie je dostupný.","A TV műsor nem elérhető.","Programme guide unavailable.") }
    } } }
}
