import SwiftUI
import AVKit

@MainActor final class PlayerEngine: NSObject, ObservableObject, AVPlayerItemMetadataOutputPushDelegate {
    let player = AVPlayer()
    @Published var error = ""; @Published var ended = false; @Published var metadata = ""
    @Published var audioOptions: [AVMediaSelectionOption] = []; @Published var textOptions: [AVMediaSelectionOption] = []
    private var audible: AVMediaSelectionGroup?; private var legible: AVMediaSelectionGroup?
    private var statusObservation: NSKeyValueObservation?; private var timeObserver: Any?; private var endObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?; private var startup: Task<Void, Never>?; private var metadataTask: Task<Void, Never>?
    private var current: PlaybackRequest?; private var ready = false; private var stopped = false
    func start(_ request: PlaybackRequest, agent: String) {
        stop(); guard request.url.scheme?.lowercased() == "https" else { error = MeteorError.httpsRequired.localizedDescription; return }; stopped = false; current = request; error = ""; metadata = ""; ended = false; ready = false
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: request.item.kind == .radio ? .default : .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) } catch { }
        UIApplication.shared.isIdleTimerDisabled = true
        let asset = AVURLAsset(url: request.url, options: [AVURLAssetHTTPUserAgentKey: agent])
        let item = AVPlayerItem(asset: asset); player.replaceCurrentItem(with: item)
        let output = AVPlayerItemMetadataOutput(identifiers: nil); output.setDelegate(self, queue: .main); item.add(output)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, !self.stopped, self.current?.id == request.id else { return }
                if item.status == .failed { self.fail() }
                if item.status == .readyToPlay && !self.ready {
                    self.ready = true; self.startup?.cancel()
                    let duration = item.duration.seconds
                    let saved = request.resumeAllowed ? UserDefaults.standard.double(forKey: "resume." + request.item.id) : 0
                    if saved > 5 && duration.isFinite && saved < duration - 10 { self.player.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
                    self.player.play()
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, !self.stopped, self.current?.id == request.id else { return }; self.ended = true; UserDefaults.standard.removeObject(forKey: "resume." + request.item.id) }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 10, preferredTimescale: 1), queue: .main) { [weak self] _ in Task { @MainActor in self?.savePosition() } }
        loadTask = Task { [weak self] in
            let a = try? await asset.loadMediaSelectionGroup(for: .audible); let t = try? await asset.loadMediaSelectionGroup(for: .legible)
            guard !Task.isCancelled, let self, !self.stopped, self.current?.id == request.id else { return }; self.audible = a; self.legible = t; self.audioOptions = a?.options ?? []; self.textOptions = t?.options ?? []
        }
        startup = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 25_000_000_000) } catch { return }
            guard let self, !self.ready, !self.stopped, self.current?.id == request.id else { return }; self.fail()
        }
        player.play()
    }
    private func fail() {
        error = tr("Prehrávanie zlyhalo. Over pripojenie a podporu formátu v iOS. Skús znova alebo iný kanál.","Sikertelen lejátszás. Ellenőrizd a kapcsolatot és az iOS formátumtámogatását.","Playback failed. Check your connection and iOS format support. Retry or choose another channel.")
        player.pause()
    }
    func selectAudio(_ option: AVMediaSelectionOption) { if let group = audible { player.currentItem?.select(option, in: group) } }
    func selectText(_ option: AVMediaSelectionOption?) { if let group = legible { player.currentItem?.select(option, in: group) } }
    func seek(_ seconds: Double) {
        let duration = player.currentItem?.duration.seconds ?? 0
        guard duration.isFinite, duration > 0 else { return }
        player.seek(to: CMTime(seconds: min(duration - 0.5, max(0, player.currentTime().seconds + seconds)), preferredTimescale: 600))
    }
    private func savePosition() {
        guard let current, current.item.kind == .movie, !ended else { return }
        let position = player.currentTime().seconds; let duration = player.currentItem?.duration.seconds ?? 0
        if position.isFinite && position > 5 && duration.isFinite && duration > position + 10 { UserDefaults.standard.set(position, forKey: "resume." + current.item.id) }
    }
    func stop() {
        savePosition(); stopped = true; loadTask?.cancel(); startup?.cancel(); metadataTask?.cancel(); loadTask = nil; startup = nil; metadataTask = nil; statusObservation = nil
        if let timeObserver { player.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        player.pause(); player.replaceCurrentItem(with: nil); current = nil; audioOptions = []; textOptions = []; audible = nil; legible = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
    nonisolated func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        // start() explicitly delivers this delegate on DispatchQueue.main.
        MainActor.assumeIsolated {
            guard !stopped, let requestID = current?.id,
                  player.currentItem?.outputs.contains(where: { $0 === output }) == true else { return }
            metadataTask?.cancel()
            metadataTask = Task { [weak self] in
                for item in groups.flatMap(\.items) {
                    guard let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
                    guard !Task.isCancelled, let self, !self.stopped, self.current?.id == requestID,
                          self.player.currentItem?.outputs.contains(where: { $0 === output }) == true else { return }
                    self.metadata = value; return
                }
            }
        }
    }
}
struct NativePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer; let mode: String
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController(); controller.player = player; controller.allowsPictureInPicturePlayback = true; controller.canStartPictureInPictureAutomaticallyFromInline = true; return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player; controller.videoGravity = mode == "fill" ? .resizeAspectFill : mode == "stretch" ? .resize : .resizeAspect
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) { controller.player = nil }
}
struct PlaybackScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = PlayerEngine()
    @AppStorage("meteor.videoMode") private var mode = "fit"
    let request: PlaybackRequest
    var nextEpisode: MediaItem? { guard let i = request.queue.firstIndex(where: { $0.id == request.item.id }), request.item.kind == .movie, i + 1 < request.queue.count else { return nil }; return request.queue[i+1] }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NativePlayerView(player: engine.player, mode: mode).ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white) }.accessibilityLabel(tr("Zavrieť","Bezárás","Close"))
                    Text(request.item.name).font(.headline).lineLimit(1); Spacer()
                    Menu {
                        Picker(tr("Veľkosť obrazu","Képméret","Picture size"), selection: $mode) {
                            Text(tr("Zachovať pomer","Arányos","Keep aspect ratio")).tag("fit")
                            Text(tr("Vyplniť","Kitöltés","Fill")).tag("fill")
                            Text(tr("Roztiahnuť","Nyújtás","Stretch")).tag("stretch")
                        }
                        if !engine.audioOptions.isEmpty { Section(tr("Zvuk","Hang","Audio")) { ForEach(engine.audioOptions.indices, id: \.self) { i in Button(engine.audioOptions[i].displayName) { engine.selectAudio(engine.audioOptions[i]) } } } }
                        Section(tr("Titulky","Felirat","Subtitles")) {
                            Button(tr("Vypnuté","Kikapcsolva","Off")) { engine.selectText(nil) }
                            ForEach(engine.textOptions.indices, id: \.self) { i in Button(engine.textOptions[i].displayName) { engine.selectText(engine.textOptions[i]) } }
                        }
                    } label: { Image(systemName: "gearshape.fill").font(.title2) }.accessibilityLabel(tr("Nastavenia prehrávania","Lejátszás beállításai","Playback settings"))
                }.padding().background(.black.opacity(0.65))
                if request.item.kind == .radio {
                    Spacer(); Image(systemName: "radio").font(.system(size: 65)).foregroundStyle(.mint)
                    Text(engine.metadata.isEmpty ? request.item.name : engine.metadata).font(.title2).multilineTextAlignment(.center).padding()
                }
                Spacer()
                if !engine.error.isEmpty { VStack(spacing: 12) { Text(engine.error).multilineTextAlignment(.center); Button(tr("Skúsiť znova","Újra","Retry")) { engine.start(request, agent: store.panel?.userAgent ?? "Mozilla/5.0") }.buttonStyle(.borderedProminent) }.padding().background(.black.opacity(0.85)) }
                HStack(spacing: 28) {
                    if request.item.kind == .movie { Button { engine.seek(-60) } label: { Label("−1 min", systemImage: "gobackward.60") }; Button { engine.seek(60) } label: { Label("+1 min", systemImage: "goforward.60") } }
                    Button { store.toggleFavorite(request.item) } label: { Image(systemName: store.favorites.contains(where: { $0.id == request.item.id }) ? "star.fill" : "star") }.accessibilityLabel(tr("Obľúbené","Kedvencek","Favorites"))
                }.padding().background(.black.opacity(0.65))
            }.foregroundStyle(.white)
        }
        .task { engine.start(request, agent: store.panel?.userAgent ?? "Mozilla/5.0") }
        .onDisappear { engine.stop() }
        .alert(tr("Pokračovať ďalšou epizódou?","Folytatod a következő résszel?","Continue with the next episode?"), isPresented: Binding(get: { engine.ended && nextEpisode != nil }, set: { engine.ended = $0 })) {
            Button(tr("Áno","Igen","Yes")) { if let nextEpisode { engine.stop(); store.play(nextEpisode, queue: request.queue) } }
            Button(tr("Nie","Nem","No"), role: .cancel) { dismiss() }
        }
    }
}
