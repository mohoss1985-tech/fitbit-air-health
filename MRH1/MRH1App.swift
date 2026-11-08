import SwiftUI

@main
struct MRH1App: App {
    @State private var health = HealthStore()
    @State private var live = LiveStore()
    @State private var journal = JournalStore()
    @State private var nav = AppNav()
    /// v1.1: one on-device coach for the whole app (configured with the stores in ContentView).
    @State private var coach = CoachEngine()

    init() {
        // Wake up when Google Health writes new nights/vitals, to send the morning summary.
        BackgroundWatcher.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(health)
                .environment(live)
                .environment(journal)
                .environment(nav)
                .environment(coach)
                // Follows the system appearance; `-uiLight` / `-uiDark` pin it for screenshots.
                .preferredColorScheme(Self.forcedScheme)
        }
    }

    static var forcedScheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiDark") { return .dark }
        if args.contains("-uiLight") { return .light }
        return nil
    }
}
