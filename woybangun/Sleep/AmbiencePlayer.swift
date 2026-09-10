//
//  AmbiencePlayer.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import AVFoundation

/// Owns the two looping soundscapes and the crossfade between them.
///
/// This type knows nothing about alarms or schedules — it plays what it's told to play.
/// `SleepSession` decides *when*.
@MainActor
final class AmbiencePlayer {
    /// How long the night bed takes to hand over to the morning sounds.
    static let crossfade: TimeInterval = 90

    /// The night bed sits under the morning sounds so the handover isn't a jump in volume.
    /// Levelled by ear against the recordings in `Audio/`.
    private static let nightVolume: Float = 0.45

    private var night: AVAudioPlayer?
    private var dawn: AVAudioPlayer?
    private var fadeOut: Task<Void, Never>?

    /// Claims the audio session for background playback.
    ///
    /// Playback must not stop after this. Unbroken audio is the only thing keeping the app
    /// alive in the background, and a suspended app never reaches the crossfade.
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    func startNight() {
        guard let player = load("night") else { return }
        player.volume = Self.nightVolume
        player.play()
        night = player
    }

    /// Fades the morning sounds in while the night bed fades out underneath.
    func crossfadeToDawn() {
        guard let player = load("dawn") else { return }
        player.volume = 0
        player.play()
        player.setVolume(1, fadeDuration: Self.crossfade)
        dawn = player

        night?.setVolume(0, fadeDuration: Self.crossfade)

        // The night player deliberately stays in `night` for the whole fade so `stop()` can
        // still reach it, and the task stays cancellable for the same reason. Dropping either
        // is how the night bed used to keep playing after "End Sleep".
        fadeOut?.cancel()
        fadeOut = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.crossfade))
            guard !Task.isCancelled else { return }
            self.night?.stop()
            self.night = nil
            self.fadeOut = nil
        }
    }

    /// Restarts whichever players are loaded, after an interruption like a phone call.
    /// Both are live during a crossfade, so both get told to play.
    func resume() throws {
        try AVAudioSession.sharedInstance().setActive(true)
        night?.play()
        dawn?.play()
    }

    func stop() {
        fadeOut?.cancel()
        fadeOut = nil
        night?.stop(); night = nil
        dawn?.stop(); dawn = nil
        // `.notifyOthersOnDeactivation` is what actually hands the route back. Without it the
        // alarm can fire into a session we're still holding, and you hear nothing.
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Loads a file from `Audio/` as an endlessly looping player.
    private func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            SessionLog.write("!! missing audio file \(name).wav")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1        // -1 means loop forever
            player.prepareToPlay()
            return player
        } catch {
            SessionLog.write("!! could not load \(name).wav: \(error.localizedDescription)")
            return nil
        }
    }
}
