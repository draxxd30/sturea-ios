import SwiftUI
import AppIntents

@main
struct SturApp: App {
    init() {
        // Refresca la lista de ramos para Siri / Spotlight al abrir la app (best-effort).
        Task.detached {
            await CourseCatalog.refreshAndIndex()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
