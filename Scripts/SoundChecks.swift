import AppKit
import Foundation

@main
struct SoundChecks {
    static func main() {
        let suite = "ChessApp.SoundChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        assert(MoveSound.selected(enabled: true, defaults: defaults) == .pop)
        assert(MoveSound.selected(enabled: false, defaults: defaults) == nil)
        for sound in MoveSound.allCases {
            defaults.set(sound.rawValue, forKey: "moveSound")
            assert(MoveSound.selected(enabled: true, defaults: defaults) == sound)
            assert(MoveSound.selected(enabled: false, defaults: defaults) == nil)
            assert(NSSound(named: NSSound.Name(sound.rawValue)) != nil, "System sound unavailable: \(sound.rawValue)")
            assert(!sound.title.isEmpty)
        }
        defaults.set("removed-sound", forKey: "moveSound")
        assert(MoveSound.selected(enabled: true, defaults: defaults) == .pop, "Unknown preference must use a valid fallback")
        print("Sound checks passed: four installed sounds, persisted routing, mute and unknown-value fallback")
    }
}
