//
//  AmbiencePlayer.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import AVFoundation

@MainActor
final class AmbiencePlayer {
    static let crossfade: TimeInterval = 90

    private static let nightVolume: Float = 0.45

    private var night: AVAudioPlayer?
    private var dawn: AVAudioPlayer?
    private var fadeOut: Task<Void, Never>?

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

    func crossfadeToDawn() {
        guard let player = load("dawn") else { return }
        player.volume = 0
        player.play()
        player.setVolume(1, fadeDuration: Self.crossfade)
        dawn = player

        night?.setVolume(0, fadeDuration: Self.crossfade)

        fadeOut?.cancel()
        fadeOut = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.crossfade))
            guard !Task.isCancelled else { return }
            self.night?.stop()
            self.night = nil
            self.fadeOut = nil
        }
    }

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
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            SessionLog.write("!! missing audio file \(name).wav")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            return player
        } catch {
            SessionLog.write("!! could not load \(name).wav: \(error.localizedDescription)")
            return nil
        }
    }
}
