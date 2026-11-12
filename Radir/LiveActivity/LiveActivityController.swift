@preconcurrency import ActivityKit
import Foundation
import OSLog
import Observation
import RadirKit

/// Elindítja, frissíti és lezárja az óra Live Activityjét. Előtérben az app frissít,
/// háttérben a szerver pusholja ugyanazt (a push tokent és a mai órákat ezért feltöltjük).
@Observable
final class LiveActivityController {
    static let color = "#2F6FEB"
    private let log = Logger(subsystem: "hu.radirapp.ios", category: "LiveActivity")
    /// fiók id → a nap, amikor a felhasználó lehúzta (csak a valódi lehúzás kerül ide)
    private static let dismissedKey = "liveActivityUserDismissed"

    private let defaults = UserDefaults.standard
    private let server = LiveServer()
    let deviceID: String

    /// Fiókonként: az egyik fiókban adott beleegyezés soha nem vonatkozik a másikra.
    private(set) var enabledAccounts: Set<String> {
        didSet { defaults.set(Array(enabledAccounts), forKey: "liveActivityEnabledAccounts") }
    }

    func isEnabled(for accountID: String?) -> Bool {
        accountID.map(enabledAccounts.contains) ?? false
    }

    func setEnabled(_ on: Bool, for accountID: String) {
        if on {
            enabledAccounts.insert(accountID)
            // kifejezett bekapcsolás: a mai „lehúztam” jelzés ne tartsa vissza
            var map = defaults.dictionary(forKey: Self.dismissedKey) as? [String: Date] ?? [:]
            map[accountID] = nil
            defaults.set(map, forKey: Self.dismissedKey)
        } else {
            enabledAccounts.remove(accountID)
            Task { await stop(unregister: true) }
        }
    }

    private var observedID: String?
    private var pushToken: String?
    private var uploadedSignature: String?
    private var accountIsDemo = true
    /// Az általunk lezárt aktivitások: ezek „dismissed” állapota nem a felhasználó lehúzása.
    private var endedByApp: Set<String> = []
    private var accountID: String?

    init() {
        enabledAccounts = Set(defaults.stringArray(forKey: "liveActivityEnabledAccounts") ?? [])
        // korábbi verziók hibásan beállított kulcsai
        defaults.removeObject(forKey: "liveActivityEnabled")
        defaults.removeObject(forKey: "liveActivityDismissedDay")
        if let id = defaults.string(forKey: "liveActivityDeviceID") {
            deviceID = id
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: "liveActivityDeviceID")
        }
    }

    var isAllowedBySystem: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func sync(app: AppModel, now: Date = .now) async {
        guard let account = app.current, isEnabled(for: account.id), isAllowedBySystem, !account.needsRelogin else {
            log.debug("sync: kikapcsolva (enabled: \(self.isEnabled(for: app.current?.id)), system: \(self.isAllowedBySystem))")
            await stop(unregister: false)
            return
        }
        if accountID != account.id {
            // fiókváltás: a másik fiók tokenje és órái nem keveredhetnek ide
            pushToken = nil
            uploadedSignature = nil
            observedID = nil
        }
        accountID = account.id
        accountIsDemo = account.isDemo
        let lessons = app.timetable.day(now)?.lessons ?? []
        let activity = Activity<RadirLiveAttributes>.activities.first
        if let activity, observedID != activity.id { observe(activity) }

        let phase = LiveCard.phase(lessons, now: now, color: Self.color)
        log.debug("sync: \(lessons.count) óra ma, fázis: \(String(describing: phase).prefix(20)), aktivitás: \(activity != nil)")
        switch phase {
        case .tooEarly:
            // tegnapról itt maradt aktivitás
            if let activity, activity.content.state.endDate < Calendar.school.startOfDay(for: now) {
                endedByApp.insert(activity.id)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        case .finished(let content):
            if let activity {
                endedByApp.insert(activity.id)
                await activity.end(ActivityContent(state: content, staleDate: nil), dismissalPolicy: .default)
            }
        case .active(let content):
            guard !dismissed(account.id, on: now) else {
                log.debug("sync: ma lehúzva, nem indul újra")
                return
            }
            let activityContent = ActivityContent(state: content, staleDate: content.endDate)
            if let activity {
                await activity.update(activityContent)
            } else {
                start(activityContent)
            }
            await uploadIfNeeded(lessons: LiveCard.relevant(lessons))
        }
    }

    private func start(_ content: ActivityContent<LiveCardContent>) {
        // push token kell a háttérfrissítéshez; ha nincs (pl. aláíratlan build), helyben akkor is fut
        let activity: Activity<RadirLiveAttributes>?
        do {
            activity = try Activity.request(attributes: RadirLiveAttributes(), content: content, pushType: .token)
        } catch {
            log.error("request push tokennel nem sikerült: \(error.localizedDescription, privacy: .public)")
            do {
                activity = try Activity.request(attributes: RadirLiveAttributes(), content: content, pushType: nil)
            } catch {
                log.error("request push nélkül sem sikerült: \(error.localizedDescription, privacy: .public)")
                activity = nil
            }
        }
        if let activity {
            log.info("aktivitás elindult")
            observe(activity)
        }
    }

    private func observe(_ activity: Activity<RadirLiveAttributes>) {
        observedID = activity.id
        Task { [weak self] in
            for await data in activity.pushTokenUpdates {
                guard let self else { return }
                pushToken = data.map { String(format: "%02x", $0) }.joined()
                uploadedSignature = nil
                await register()
            }
        }
        Task { [weak self] in
            for await state in activity.activityStateUpdates where state == .dismissed {
                guard let self, !endedByApp.contains(activity.id) else { return }
                // a felhasználó lehúzta: ma már ne jöjjön vissza ennél a fióknál, és a szerver se pusholjon
                if let id = accountID {
                    var map = defaults.dictionary(forKey: Self.dismissedKey) as? [String: Date] ?? [:]
                    map[id] = Calendar.school.startOfDay(for: .now)
                    defaults.set(map, forKey: Self.dismissedKey)
                }
                if !accountIsDemo { try? await server.unregister(deviceID: deviceID) }
            }
        }
    }

    private func register() async {
        guard let pushToken, !accountIsDemo else { return }
        try? await server.register(deviceID: deviceID, pushToken: pushToken,
                                   bundleID: Bundle.main.bundleIdentifier ?? "hu.radirapp.ios", color: Self.color)
    }

    /// A mai órák feltöltése, ha változtak (vagy új token jött).
    private func uploadIfNeeded(lessons: [Lesson]) async {
        guard pushToken != nil, !accountIsDemo, !lessons.isEmpty else { return }
        let signature = lessons.map { "\($0.id)|\($0.start.timeIntervalSince1970)|\($0.room)" }.joined(separator: ",")
        guard signature != uploadedSignature else { return }
        do {
            try await server.uploadSchedule(.init(deviceID: deviceID, lessons: lessons))
            uploadedSignature = signature
        } catch {}
    }

    private func dismissed(_ accountID: String, on now: Date) -> Bool {
        let map = defaults.dictionary(forKey: Self.dismissedKey) as? [String: Date] ?? [:]
        return map[accountID] == Calendar.school.startOfDay(for: now)
    }

    private func stop(unregister: Bool) async {
        for activity in Activity<RadirLiveAttributes>.activities {
            endedByApp.insert(activity.id)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        observedID = nil
        if unregister, !accountIsDemo { try? await server.unregister(deviceID: deviceID) }
    }
}
