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

/// Runs one night: night sounds from bedtime, morning sounds for the final hour, then stop.
///
/// iOS won't wake a suspended app to start audio at a chosen time, so the session has to be
/// playing continuously from the moment it starts. That unbroken playback is the only reason
/// the app is still alive to reach the crossfade an hour before the alarm.
///
/// This type is the scheduler. `AmbiencePlayer` does the actual playing, `LightController`
/// talks to the LED strip, and `SessionLog` records what happened.
@MainActor
@Observable
final class SleepSession {
    enum Phase: String {
        case idle = "Idle"
        case night = "Night sounds"
        case dawn = "Morning sounds"
    }

    /// One session per process — a second would fight over the audio route.
    static let shared = SleepSession()

    /// How long before the alarm the morning sounds and the wake light begin.
    static let dawnLead: TimeInterval = 60 * 60

    private(set) var phase: Phase = .idle
    private(set) var dawnDate: Date?
    private(set) var endDate: Date?

    @ObservationIgnored private let player = AmbiencePlayer()
    @ObservationIgnored private var ticker: Timer?

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

    /// Starts playing now, ending at the next occurrence of `alarmTime`.
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
        endDate = alarm
        dawnDate = max(dawnStart, .now)

        if dawnStart <= .now {
            beginDawn()          // started inside the final hour, so skip the night bed
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
    }

    /// `turningOffLight` is false when the alarm itself ends the session — the strip has just
    /// reached full brightness, which is the moment it's actually doing its job.
    func stop(turningOffLight: Bool = true) {
        if turningOffLight {
            Task { @MainActor in
                let result = await LightController.shared.turnOff()
                SessionLog.write("wake light — off → \(result)")
            }
        }

        ticker?.invalidate()
        ticker = nil
        player.stop()

        phase = .idle
        dawnDate = nil
        endDate = nil
        SessionLog.write("session ended")
    }

    // MARK: - The clock

    /// Runs every minute. Doubles as a heartbeat: if these lines stop appearing in the log,
    /// the app didn't survive the night.
    private func tick() {
        let level = UIDevice.current.batteryLevel
        let battery = level < 0 ? "n/a" : "\(Int((level * 100).rounded()))%"
        SessionLog.write("alive — \(phase.rawValue), battery \(battery)")

        if let end = endDate, Date.now >= end {
            SessionLog.write("reached alarm time")
            stop(turningOffLight: false)
            return
        }
        if phase == .night, let due = dawnDate, Date.now >= due {
            beginDawn()
        }
    }

    /// The final hour: morning sounds fade in and the wake light starts climbing.
    private func beginDawn() {
        player.crossfadeToDawn()
        phase = .dawn
        SessionLog.write("▶︎ morning sounds fading in over \(Int(AmbiencePlayer.crossfade))s")

        // Hand the light the time remaining, so it reaches full exactly as the alarm fires.
        // One request, not sixty: the ESP32 runs the ramp itself, so it still finishes even
        // if the phone drops off Wi-Fi during the hour.
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
            // Past the alarm there's nothing left to resume — the alarm owns the room now.
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

    /// Delivery is on `.main`, so the handler is already main-isolated.
    private func observe(
        _ name: Notification.Name,
        handler: @escaping @MainActor (Notification) -> Void
    ) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
            MainActor.assumeIsolated { handler(note) }
        }
    }
}
