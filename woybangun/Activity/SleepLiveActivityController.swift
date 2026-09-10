//
//  SleepLiveActivityController.swift
//  woybangun
//
//  Created by Dimas Putra on 10/09/26.
//

import ActivityKit
import Foundation

@MainActor
enum SleepLiveActivityController {
    private static var activity: Activity<SleepActivityAttributes>?

    static func start(startedAt: Date, dawnDate: Date, endDate: Date, isDawn: Bool, phaseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            SessionLog.write("live activity — not enabled in Settings")
            return
        }
        guard activity == nil else { return }

        let attributes = SleepActivityAttributes(
            startedAt: startedAt,
            dawnDate: dawnDate,
            endDate: endDate
        )
        let content = ActivityContent(
            state: SleepActivityAttributes.ContentState(phaseName: phaseName, isDawn: isDawn),
            staleDate: endDate
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            SessionLog.write("live activity — started")
        } catch {
            SessionLog.write("!! live activity failed: \(error.localizedDescription)")
        }
    }

    static func update(isDawn: Bool, phaseName: String, endDate: Date) {
        guard let activity else { return }
        let content = ActivityContent(
            state: SleepActivityAttributes.ContentState(phaseName: phaseName, isDawn: isDawn),
            staleDate: endDate
        )
        Task {
            await activity.update(content)
            SessionLog.write("live activity — updated to \(phaseName)")
        }
    }

    static func end() {
        activity = nil
        clearStale()   // `activities` already includes the one we started
    }

    static func clearStale() {
        Task {
            for stale in Activity<SleepActivityAttributes>.activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
