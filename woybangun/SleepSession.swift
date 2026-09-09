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

/// Plays a soundscape from bedtime until the alarm, crossfading into morning sounds an hour before.
///
/// iOS won't wake a suspended app to start audio at a chosen time, so the session has to be playing
/// continuously from the moment it starts — that unbroken playback is what keeps the app alive to
/// reach the crossfade at all.
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

    private(set) var phase: Phase = .idle
    private(set) var dawnDate: Date?
    private(set) var endDate: Date?

    private var night: AVAudioPlayer?
    private var dawn: AVAudioPlayer?
    private var ticker: Timer?
    private var fadeOut: Task<Void, Never>?

    /// How long before the alarm the morning sounds begin.
    static let dawnLead: TimeInterval = 60 * 60
    private static let crossfade: TimeInterval = 90
    private static let nightVolume: Float = 0.45

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        log("──────── app launched")
        observe(AVAudioSession.interruptionNotification, handler: handleInterruption)
        observe(AVAudioSession.mediaServicesWereResetNotification) { [weak self] _ in
            self?.log("!! media services reset — audio stack died")
        }
        observe(UIApplication.didEnterBackgroundNotification) { [weak self] _ in
            self?.log("entered background")
        }
    }

    /// Starts playing now, ending at the next occurrence of `alarmTime`.
    func start(alarmTime: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
        guard let alarm = Calendar.current.nextDate(
            after: .now, matching: components, matchingPolicy: .nextTime
        ) else {
            log("!! could not resolve the next alarm occurrence")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            log("!! session activation failed: \(error.localizedDescription)")
            return
        }

        endDate = alarm
        // Starting inside the last hour means going straight to morning sounds.
        dawnDate = max(alarm.addingTimeInterval(-Self.dawnLead), .now)

        if dawnDate == .now {
            startDawn()
        } else {
            guard let player = loopingPlayer(named: "night") else { return }
            player.volume = Self.nightVolume
            player.play()
            night = player
            phase = .night
        }

        log("started — \(phase.rawValue), morning at \(Self.stamp.string(from: dawnDate!)), alarm at \(Self.stamp.string(from: alarm))")

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.tick() }
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        fadeOut?.cancel()
        fadeOut = nil
        night?.stop(); night = nil
        dawn?.stop(); dawn = nil
        phase = .idle
        dawnDate = nil
        endDate = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        log("session ended")
    }

    /// Also a heartbeat: if these stop appearing, the app didn't survive the night.
    private func tick() {
        let level = UIDevice.current.batteryLevel
        let battery = level < 0 ? "n/a" : "\(Int((level * 100).rounded()))%"
        log("alive — \(phase.rawValue), battery \(battery)")

        if let end = endDate, Date.now >= end {
            log("reached alarm time")
            stop()
            return
        }
        if phase == .night, let due = dawnDate, Date.now >= due {
            startDawn()
        }
    }

    private func startDawn() {
        guard let player = loopingPlayer(named: "dawn") else { return }
        player.volume = 0
        player.play()
        player.setVolume(1, fadeDuration: Self.crossfade)
        dawn = player

        // Fade the night bed out underneath rather than cutting it. It stays in `night` for
        // the whole fade so stop() can still reach it, and the task stays cancellable for the
        // same reason — dropping either is how the bed used to outlive "End Sleep".
        night?.setVolume(0, fadeDuration: Self.crossfade)
        fadeOut?.cancel()
        fadeOut = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.crossfade))
            guard !Task.isCancelled else { return }
            self.night?.stop()
            self.night = nil
            self.fadeOut = nil
        }

        phase = .dawn
        log("▶︎ morning sounds fading in over \(Int(Self.crossfade))s")
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            log("!! interrupted (call, another app, or an alarm)")
        case .ended:
            guard phase != .idle else { return }
            // Past the alarm there's nothing left to resume — the alarm owns the room now.
            if let end = endDate, Date.now >= end {
                stop()
                return
            }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                night?.play()
                dawn?.play()
                log("resumed after interruption")
            } catch {
                log("!! resume failed: \(error.localizedDescription)")
            }
        @unknown default:
            break
        }
    }

    private func loopingPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            log("!! missing audio file \(name).wav")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            return player
        } catch {
            log("!! could not load \(name).wav: \(error.localizedDescription)")
            return nil
        }
    }

    /// Delivery is on `.main`, so the handler is already main-isolated.
    private func observe(_ name: Notification.Name, handler: @escaping @MainActor (Notification) -> Void) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
            MainActor.assumeIsolated { handler(note) }
        }
    }

    // MARK: - Diagnostics
    // TEMPORARY — here to verify the session survives a real night. Remove once it has.

    static let logURL = URL.documentsDirectory.appending(path: "session.log")

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// Written to disk so the record outlives the app being killed.
    private func log(_ message: String) {
        let line = "\(Self.stamp.string(from: .now))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: Self.logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: Self.logURL)
        }
    }

    func readLog(limit: Int = 40) -> (text: String, total: Int) {
        guard let contents = try? String(contentsOf: Self.logURL, encoding: .utf8) else {
            return ("No entries yet.", 0)
        }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        return (lines.suffix(limit).reversed().joined(separator: "\n"), lines.count)
    }

    func clearLog() {
        try? FileManager.default.removeItem(at: Self.logURL)
        log("──────── log cleared")
    }
}
