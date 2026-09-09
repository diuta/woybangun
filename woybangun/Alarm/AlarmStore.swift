//
//  AlarmStore.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import AlarmKit
import Observation
import SwiftUI

/// AlarmKit requires a concrete metadata type, but this app attaches no extra data to its alarm.
struct AlarmData: AlarmMetadata {}

enum AlarmStoreError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        String(localized: "Allow alarms for this app in Settings to set an alarm.")
    }
}

/// Manages the app's single alarm.
@MainActor
@Observable
final class AlarmStore {
    private(set) var alarm: Alarm?

    private let manager = AlarmManager.shared

    /// Keeps `alarm` in sync, including changes made while the app wasn't running.
    func observeAlarm() async {
        for await alarms in manager.alarmUpdates {
            alarm = alarms.first
        }
    }

    func setAlarm(at date: Date) async throws {
        guard await isAuthorized() else { throw AlarmStoreError.notAuthorized }

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let schedule = Alarm.Schedule.relative(
            .init(time: .init(hour: components.hour ?? 0, minute: components.minute ?? 0))
        )
        let attributes = AlarmAttributes<AlarmData>(
            presentation: AlarmPresentation(alert: .init(title: "Alarm")),
            tintColor: .accentColor
        )

        // `sound` is left at its default: AlarmKit's own alarm tone.
        _ = try await manager.schedule(
            id: UUID(),
            configuration: .alarm(schedule: schedule, attributes: attributes)
        )
    }

    func cancelAlarm() throws {
        guard let alarm else { return }
        try manager.cancel(id: alarm.id)
    }

    private func isAuthorized() async -> Bool {
        switch manager.authorizationState {
        case .authorized: true
        case .denied: false
        case .notDetermined: (try? await manager.requestAuthorization()) == .authorized
        @unknown default: false
        }
    }
}

extension Alarm {
    /// The time of day this alarm is scheduled for.
    var time: Date? {
        guard case .relative(let relative)? = schedule else { return nil }
        return Calendar.current.date(
            from: DateComponents(hour: relative.time.hour, minute: relative.time.minute)
        )
    }
}
