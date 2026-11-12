@preconcurrency import ActivityKit
import Foundation
import Observation
import RadirKit

/// Elindítja, frissíti és lezárja az óra Live Activityjét. Előtérben az app frissít,
/// háttérben a szerver pusholja ugyanazt (a push tokent és a mai órákat ezért feltöltjük).
@Observable
final class LiveActivityController {
    static let color = "#2F6FEB"

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
            defaults.removeObject(forKey: "liveActivityDismissedDay")
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
        defaults.removeObject(forKey: "liveActivityEnabled")
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

        switch LiveCard.phase(lessons, now: now, color: Self.color) {
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
            guard !dismissed(on: now) else { return }
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
        let activity = (try? Activity.request(attributes: RadirLiveAttributes(), content: content, pushType: .token))
            ?? (try? Activity.request(attributes: RadirLiveAttributes(), content: content, pushType: nil))
        if let activity { observe(activity) }
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
                // a felhasználó lehúzta: ma már ne jöjjön vissza, és a szerver se pusholjon
                defaults.set(Calendar.school.startOfDay(for: .now), forKey: "liveActivityDismissedDay")
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

    private func dismissed(on now: Date) -> Bool {
        (defaults.object(forKey: "liveActivityDismissedDay") as? Date) == Calendar.school.startOfDay(for: now)
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
