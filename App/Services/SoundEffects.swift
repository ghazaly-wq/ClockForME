import AVFoundation
import Foundation
import HabitCore

/// The moments that have a sound.
enum SoundEvent: String, CaseIterable {
    case taskDone = "task_done"
    case achievement
    case dayComplete = "day_complete"
    case purchase
}

/// Short celebration sounds. Each moment has 4 sounds (`sfx_<event>_0...3` in Resources/Sounds). They play in random
/// order, but a sound only comes back after the other three have played (`ShuffleBag`); the state is kept between
/// launches. Uses the "playback" audio category: the sounds play even when the ringer is on silent and follow the
/// media volume (the volume buttons), and `mixWithOthers` keeps the user's music or podcast playing underneath.
@MainActor
final class SoundEffects {
    static let shared = SoundEffects()
    static let variantsPerEvent = 4

    private var players: [String: AVAudioPlayer] = [:]
    private var sessionReady = false

    func play(_ event: SoundEvent) {
        let enabled = UserDefaults.standard.object(forKey: SettingsKey.soundEffectsEnabled) as? Bool ?? true
        guard enabled else { return }
        play(file: "sfx_\(event.rawValue)_\(nextVariant(for: event))")
    }

    private func nextVariant(for event: SoundEvent) -> Int {
        let defaults = UserDefaults.standard
        let key = "soundBag.\(event.rawValue)"
        var bag = ShuffleBag(count: Self.variantsPerEvent)
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(ShuffleBag.self, from: data) {
            bag = ShuffleBag(count: Self.variantsPerEvent, remaining: saved.remaining, last: saved.last)
        }
        var generator = SystemRandomNumberGenerator()
        let variant = bag.next(using: &generator)
        if let data = try? JSONEncoder().encode(bag) { defaults.set(data, forKey: key) }
        return variant
    }

    private func play(file name: String) {
        prepareSession()
        let player: AVAudioPlayer
        if let cached = players[name] {
            player = cached
        } else {
            guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
                  let created = try? AVAudioPlayer(contentsOf: url) else { return }
            created.prepareToPlay()
            players[name] = created
            player = created
        }
        player.currentTime = 0
        player.play()
    }

    private func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
