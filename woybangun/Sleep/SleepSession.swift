//
//  SleepSession.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class SleepSession {
    enum Phase: String {
        case idle = "Idle"
        case night = "Night sounds"
        case dawn = "Morning sounds"
    }

    static let shared = SleepSession()

    static let dawnLead: TimeInterval = 60 * 60

    private(set) var phase: Phase = .idle
    private(set) var startedAt: Date?
    private(set) var dawnDate: Date?
    private(set) var endDate: Date?

    var progress: Double? {
        guard let startedAt, let endDate else { return nil }
        let total = endDate.timeIntervalSince(startedAt)
        guard total > 0 else { return nil }
        return min(max(Date.now.timeIntervalSince(startedAt) / total, 0), 1)
    }

    @ObservationIgnored private let player = AmbiencePlayer()
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var endTimer: Timer?

    private static let handoverLead: TimeInterval = 3

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        SessionLog.write("──────── app launched")

        observe(AVAudioSession.interruptionNotification, handler: handleInterruption)
        observe(AVAudioSession.mediaServicesWereResetNotification) { _ in
            SessionLog.write("!! media services reset — audio stack died")
        }
        observe(UIApplication.didEnterBackgroundNotification) { _ in
            SessionLog.write("entered background")
        }
    }

    // MARK: - Starting and stopping

    func start(alarmTime: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
        guard let alarm = Calendar.current.nextDate(
            after: .now, matching: components, matchingPolicy: .nextTime
        ) else {
            SessionLog.write("!! could not resolve the next alarm occurrence")
            return
        }

        do {
            try player.activate()
        } catch {
            SessionLog.write("!! session activation failed: \(error.localizedDescription)")
            return
        }

        let dawnStart = alarm.addingTimeInterval(-Self.dawnLead)
        startedAt = .now
        endDate = alarm
        dawnDate = max(dawnStart, .now)

        if dawnStart <= .now {
            beginDawn()
        } else {
            player.startNight()
            phase = .night
        }

        SessionLog.write("""
            started — \(phase.rawValue), morning at \(SessionLog.time(dawnDate!)), \
            alarm at \(SessionLog.time(alarm))
            """)

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.tick() }
        }

        endTimer?.invalidate()
        let handover = max(alarm.timeIntervalSinceNow - Self.handoverLead, 0)
        endTimer = Timer.scheduledTimer(withTimeInterval: handover, repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                SessionLog.write("handing audio over to the alarm")
                self.stop()
            }
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        endTimer?.invalidate()
        endTimer = nil
        player.stop()

        phase = .idle
        startedAt = nil
        dawnDate = nil
        endDate = nil
        SessionLog.write("session ended")
    }

    // MARK: - The clock

    private func tick() {
        let level = UIDevice.current.batteryLevel
        let battery = level < 0 ? "n/a" : "\(Int((level * 100).rounded()))%"
        SessionLog.write("alive — \(phase.rawValue), battery \(battery)")

        if let end = endDate, Date.now >= end {
            SessionLog.write("reached alarm time")
            stop()
            return
        }
        if phase == .night, let due = dawnDate, Date.now >= due {
            beginDawn()
        }
    }

    private func beginDawn() {
        player.crossfadeToDawn()
        phase = .dawn
        SessionLog.write("▶︎ morning sounds fading in over \(Int(AmbiencePlayer.crossfade))s")

        guard let end = endDate else { return }
        let seconds = Int(end.timeIntervalSinceNow)
        Task { @MainActor in
            let result = await LightController.shared.startRamp(seconds: seconds)
            SessionLog.write("wake light — ramp \(seconds)s → \(result)")
        }
    }

    // MARK: - Interruptions

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            SessionLog.write("!! interrupted (call, another app, or an alarm)")
        case .ended:
            guard phase != .idle else { return }
            if let end = endDate, Date.now >= end {
                stop()
                return
            }
            do {
                try player.resume()
                SessionLog.write("resumed after interruption")
            } catch {
                SessionLog.write("!! resume failed: \(error.localizedDescription)")
            }
        @unknown default:
            break
        }
    }

    private func observe(
        _ name: Notification.Name,
        handler: @escaping @MainActor (Notification) -> Void
    ) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
            MainActor.assumeIsolated { handler(note) }
        }
    }
}
