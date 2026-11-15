import ActivityKit
import AVFoundation
import Foundation

/// The alarm sounds the owner imported from the Files app.
/// iOS doesn't let apps read the system ringtone list, so a sound is any audio file the owner picks.
/// Files are converted to a short `.caf` inside `Library/Sounds`, the folder AlarmKit plays named sounds from.
enum AlarmSoundStore {
    struct Sound: Identifiable, Equatable {
        /// File name inside the sounds folder (also what AlarmKit is given).
        let id: String
        var title: String { (id as NSString).deletingPathExtension }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case tooManyChannels

        var errorDescription: String? {
            switch self {
            case .unreadable: return String(localized: "ما قدرنا نقرأ هذا الملف الصوتي.")
            case .tooManyChannels: return String(localized: "هذا الملف الصوتي غير مدعوم.")
            }
        }
    }

    /// Longest clip kept, in seconds (the system's limit for custom alert sounds is 30).
    static let maxSeconds = 29.0

    static var folder: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let url = library.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func list() -> [Sound] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".caf") }.sorted().map(Sound.init(id:))
    }

    /// The chosen sound's file name, or "" for the default one. Falls back to default if the file is gone.
    static var selectedName: String {
        let name = UserDefaults.standard.string(forKey: SettingsKey.alarmSound) ?? ""
        guard !name.isEmpty, FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) else { return "" }
        return name
    }

    static var alertSound: ActivityKit.AlertConfiguration.AlertSound {
        let name = selectedName
        return name.isEmpty ? .default : .named(name)
    }

    static func url(for sound: Sound) -> URL {
        folder.appendingPathComponent(sound.id)
    }

    static func delete(_ sound: Sound) {
        try? FileManager.default.removeItem(at: url(for: sound))
        if UserDefaults.standard.string(forKey: SettingsKey.alarmSound) == sound.id {
            UserDefaults.standard.set("", forKey: SettingsKey.alarmSound)
        }
    }

    /// Converts the picked audio file (mp3, m4a, wav, …) to a `.caf` clip and returns it.
    static func importSound(from source: URL) throws -> Sound {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let input: AVAudioFile
        do { input = try AVAudioFile(forReading: source) } catch { throw ImportError.unreadable }
        let format = input.processingFormat
        guard format.channelCount <= 2 else { throw ImportError.tooManyChannels }

        var base = source.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        if base.isEmpty { base = "sound" }
        var name = base + ".caf"
        var counter = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) {
            name = "\(base) \(counter).caf"
            counter += 1
        }
        let destination = folder.appendingPathComponent(name)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        do {
            let output = try AVAudioFile(
                forWriting: destination, settings: settings,
                commonFormat: format.commonFormat, interleaved: format.isInterleaved
            )
            let maxFrames = AVAudioFramePosition(format.sampleRate * maxSeconds)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32768) else { throw ImportError.unreadable }
            var written: AVAudioFramePosition = 0
            while written < maxFrames, input.framePosition < input.length {
                let count = AVAudioFrameCount(Swift.min(AVAudioFramePosition(buffer.frameCapacity), maxFrames - written))
                try input.read(into: buffer, frameCount: count)
                if buffer.frameLength == 0 { break }
                try output.write(from: buffer)
                written += AVAudioFramePosition(buffer.frameLength)
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw ImportError.unreadable
        }
        return Sound(id: name)
    }
}
