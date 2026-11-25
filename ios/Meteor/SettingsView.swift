import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State private var adding = false; @State private var importing = false; @State private var error = ""
    @AppStorage("meteor.videoMode") private var mode = "fit"
    var body: some View { NavigationStack { Form {
        Section(tr("Jazyk","Nyelv","Language")) { Picker(tr("Jazyk","Nyelv","Language"), selection: Binding(get: { store.language }, set: { store.setLanguage($0) })) { Text("Slovenčina").tag("sk"); Text("Magyar").tag("hu"); Text("English").tag("en") } }
        Section(tr("Veľkosť obrazu","Képméret","Picture size")) { Picker(tr("Režim","Mód","Mode"), selection: $mode) { Text(tr("Zachovať pomer","Arányos","Keep aspect ratio")).tag("fit"); Text(tr("Vyplniť","Kitöltés","Fill")).tag("fill"); Text(tr("Roztiahnuť","Nyújtás","Stretch")).tag("stretch") } }
        Section(tr("Zoznamy","Listák","Playlists")) {
            ForEach(store.sources) { source in HStack { VStack(alignment: .leading) { Text(source.name); Text(source.type == "m3u" ? "M3U" : "Xtream Codes").font(.caption).foregroundStyle(.secondary) }; Spacer(); if store.isLocal(source) { Button(role: .destructive) { do { try store.deleteLocalSource(source) } catch { self.error = error.localizedDescription } } label: { Image(systemName: "trash") } } } }
            Button(tr("Pridať Xtream / M3U URL","Xtream / M3U URL hozzáadása","Add Xtream / M3U URL")) { adding = true }
            Button(tr("Otvoriť súbor M3U","M3U fájl megnyitása","Open M3U file")) { importing = true }
        }
        Section(tr("O aplikácii","Az alkalmazásról","About")) { Text("Meteor iOS " + MeteorConfig.version); Text("Licens by B.Gabriel bigiboy5"); Text(tr("Prihlasovacie údaje a identita zariadenia sú uložené v zabezpečenom úložisku iOS. Aplikácia neposkytuje vlastné kanály.","A belépési adatok és a készülékazonosító az iOS biztonságos tárolójában maradnak. Az alkalmazás nem tartalmaz saját csatornákat.","Credentials and device identity are stored in iOS secure storage. This app does not supply channels.")); Text(tr("Prvá skúšobná iOS verzia. projectM a interné YouTube/Twitch prehrávanie zatiaľ nie sú súčasťou tejto verzie.","Első iOS tesztverzió. A projectM és a belső YouTube/Twitch lejátszás még nincs benne.","Initial iOS test version. projectM and internal YouTube/Twitch playback are not included yet.")).font(.footnote).foregroundStyle(.secondary) }
        if !error.isEmpty { Text(error).foregroundStyle(.orange) }
    }.navigationTitle(tr("Nastavenia","Beállítások","Settings")).toolbar { Button(tr("Hotovo","Kész","Done")) { dismiss() } }
        .sheet(isPresented: $adding) { AddSourceView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size <= 32 * 1024 * 1024 else { throw MeteorError.tooLarge }
                let data = try Data(contentsOf: url, options: .mappedIfSafe); guard data.count <= 32 * 1024 * 1024, let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw MeteorError.invalidData }
                let id = UUID().uuidString.lowercased(); _ = try M3UParser.parse(text, sourceID: id)
                let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Playlists", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: folder.appendingPathComponent(id + ".m3u"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                var source = Source(id: id, name: url.deletingPathExtension().lastPathComponent, type: "m3u"); source.localFile = id + ".m3u"; try store.addSource(source)
            } catch { self.error = tr("Súbor M3U sa nepodarilo importovať.","Az M3U fájl importálása sikertelen.","Could not import M3U file.") }
        }
    } }
}
struct AddSourceView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State private var type = "xtream"; @State private var name = ""; @State private var address = ""; @State private var username = ""; @State private var password = ""; @State private var error = ""
    var body: some View { NavigationStack { Form {
        Picker(tr("Typ","Típus","Type"), selection: $type) { Text("Xtream Codes").tag("xtream"); Text("M3U URL").tag("m3u") }
        TextField(tr("Názov zoznamu","Lista neve","Playlist name"), text: $name)
        TextField(type == "xtream" ? tr("Adresa servera","Szerver címe","Server address") : "M3U URL", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
        if type == "xtream" { TextField(tr("Prihlasovacie meno","Felhasználónév","Username"), text: $username).textInputAutocapitalization(.never).autocorrectionDisabled(); SecureField(tr("Heslo","Jelszó","Password"), text: $password) }
        if !error.isEmpty { Text(error).foregroundStyle(.orange) }
    }.navigationTitle(tr("Pridať zoznam","Lista hozzáadása","Add playlist")).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(tr("Zrušiť","Mégse","Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button(tr("Uložiť","Mentés","Save")) {
            do {
                let value = address.trimmingCharacters(in: .whitespacesAndNewlines); let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, httpURL(value) != nil, type == "m3u" || (!username.isEmpty && !password.isEmpty) else { throw MeteorError.invalidData }
                let source = Source(id: UUID().uuidString.lowercased(), name: title, type: type, server: type == "xtream" ? value : "", username: username, password: password, url: type == "m3u" ? value : "")
                if type == "xtream" { _ = try source.base() }; try store.addSource(source); dismiss()
            } catch { self.error = tr("Vyplň názov a platné prihlasovacie údaje.","Add meg a nevet és az érvényes belépési adatokat.","Enter a name and valid login details.") }
        } }
    } } }
}
