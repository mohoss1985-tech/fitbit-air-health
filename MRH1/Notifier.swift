import Foundation
import HealthKit
import UserNotifications

/// Local notifications only (made on the iPhone, nothing goes through a server).
enum Notifier {

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func sentToday(_ key: String) -> Bool {
        guard let d = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return Calendar.current.isDateInToday(d)
    }

    private static func markSent(_ key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    private static func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Drift alert title, e.g. "2 signals are outside your usual range" (never "danger", no diagnosis).
    static func driftTitle(_ count: Int) -> String {
        count == 1 ? "1 signal is outside your usual range" : "\(count) signals are outside your usual range"
    }

    /// Called after every refresh (in the app or in the background when new data arrives).
    /// Skipped in demo mode; each notification follows its toggle in AppSettings.
    @MainActor
    static func evaluate(_ health: HealthStore) {
        guard !Demo.isOn else { return }

        // 1. Morning summary, once a day, as soon as last night has arrived.
        if AppSettings.morningNotification, health.isSleepFresh, !sentToday("mrh1.morningSent"), let s = health.lastSleep {
            let watch = Panel.allCases.flatMap { $0.metrics }.map { health.state($0) }.filter(\.isConcern)
            let title = health.recovery.map { "Recovery \($0.score)%. \(Scores.verdict($0))" } ?? "Your night is in"
            var body = "Slept \(MetricID.sleepTotal.format(s.asleepMinutes))"
            if let score = health.sleepScore { body += ", sleep score \(score)" }
            body += watch.isEmpty
                ? ". Everything is in your usual range."
                : ". Worth a look: " + watch.map { $0.id.info.name.lowercased() }.joined(separator: ", ") + "."
            post(id: "morning", title: title, body: body)
            markSent("mrh1.morningSent")
        }

        // 2. Two or more vitals outside the usual range at once.
        let vitals: [MetricID] = [.restingHR, .hrv, .breathing, .spo2, .skinTemp]
        let drifting = vitals.map { health.state($0) }.filter(\.isConcern)
        if AppSettings.driftNotification, drifting.count >= 2, !sentToday("mrh1.driftSent") {
            post(id: "drift",
                 title: driftTitle(drifting.count),
                 body: drifting.map { "\($0.id.info.name) \($0.valueText)\($0.id.info.unit.isEmpty ? "" : " " + $0.id.info.unit)" }.joined(separator: ", ")
                    + ". Your body may need more rest. Consider an easy day.")
            markSent("mrh1.driftSent")
        }
    }
}

/// Wakes the app when Google Health writes new sleep, vitals or heart rate into Apple Health,
/// and refreshes the app's SHARED HealthStore (v0.4 refreshed a throwaway instance, so the UI never updated).
final class BackgroundWatcher {
    static let shared = BackgroundWatcher()
    private let store = HKHealthStore()
    private var started = false
    /// The app's HealthStore (HealthStore.init attaches itself). Weak: the app owns it.
    @MainActor private weak var health: HealthStore?
    @MainActor private var pending: Task<Void, Never>?
    @MainActor private var lastHRRefresh = Date.distantPast

    @MainActor func attach(_ health: HealthStore) {
        if self.health == nil { self.health = health }
    }

    func start() {
        guard !Demo.isOn, HKHealthStore.isHealthDataAvailable(), !started else { return }
        started = true
        let types: [HKSampleType] = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.heartRate)
        ]
        for type in types {
            let isHR = type == HKQuantityType(.heartRate)
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard error == nil, let self else { completion(); return }
                Task { @MainActor in
                    await self.wake(heartRateOnly: isHR)
                    completion()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// Debounced (batches arrive in bursts). Heart-rate-only wakes refresh at most every 15 min:
    /// in the foreground LiveStore already streams heart rate without the heavy refresh().
    @MainActor private func wake(heartRateOnly: Bool) async {
        if heartRateOnly {
            guard Date().timeIntervalSince(lastHRRefresh) > 15 * 60 else { return }
            lastHRRefresh = Date()
        }
        pending?.cancel()
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            if let health = self.health {
                await health.refresh()          // refresh() also checks for notifications
            } else {
                let temp = HealthStore()        // app not running a UI yet: still evaluate notifications
                await temp.refresh()
            }
        }
        pending = task
        await task.value
    }
}
