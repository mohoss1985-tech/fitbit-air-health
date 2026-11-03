import Foundation

/// User settings stored in UserDefaults. Bind in views with `@AppStorage(AppSettings.Key.morning)`:
///
///     @AppStorage(AppSettings.Key.morning) private var morning = AppSettings.Default.morning
///
/// Non-view code reads the static accessors below (same keys, same defaults).
enum AppSettings {
    enum Key {
        /// Morning summary notification (Bool, default true).
        static let morning = "mrh1.notif.morning"
        /// "2 signals are outside your usual range" notification (Bool, default true).
        static let drift = "mrh1.notif.drift"
        /// Opt-in Bluetooth live heart rate from the band (Bool, default false).
        static let bleEnabled = "mrh1.ble.enabled"
    }

    enum Default {
        static let morning = true
        static let drift = true
        static let bleEnabled = false
    }

    private static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    static var morningNotification: Bool {
        get { bool(Key.morning, default: Default.morning) }
        set { UserDefaults.standard.set(newValue, forKey: Key.morning) }
    }

    static var driftNotification: Bool {
        get { bool(Key.drift, default: Default.drift) }
        set { UserDefaults.standard.set(newValue, forKey: Key.drift) }
    }

    static var bleEnabled: Bool {
        get { bool(Key.bleEnabled, default: Default.bleEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.bleEnabled) }
    }
}

/// Short name from the contract (DESIGN_SPEC §8: `Settings`). Shadows SwiftUI's macOS-only `Settings` scene.
typealias Settings = AppSettings
