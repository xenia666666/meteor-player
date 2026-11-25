import SwiftUI

@main struct MeteorApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store) } }
}
