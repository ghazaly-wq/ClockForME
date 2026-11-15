import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Picks the sound alarms ring with: the system default, or any audio file imported from Files.
struct AlarmSoundView: View {
    @AppStorage(SettingsKey.alarmSound) private var selected = ""
    @State private var sounds = AlarmSoundStore.list()
    @State private var showImporter = false
    @State private var errorText: String?
    @State private var player: AVAudioPlayer?
    @State private var playingID: String?

    var body: some View {
        Form {
            Section {
                row(title: String(localized: "الافتراضي (صوت النظام)"), id: "", sound: nil)
                ForEach(sounds) { sound in
                    row(title: sound.title, id: sound.id, sound: sound)
                }
                .onDelete { offsets in
                    for index in offsets { AlarmSoundStore.delete(sounds[index]) }
                    sounds = AlarmSoundStore.list()
                    if AlarmSoundStore.selectedName.isEmpty { selected = "" }
                }
            } header: {
                Text("الأصوات")
            } footer: {
                Text("آيفون ما يسمح للتطبيقات تقرأ نغمات المنبه حقت النظام، فتقدر تستورد أي ملف صوتي من تطبيق الملفات (mp3 أو m4a أو wav). نقص الصوت إلى 29 ثانية إذا كان أطول. التغيير يشمل كل المنبهات.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("استيراد صوت من الملفات", systemImage: "square.and.arrow.down")
                        .frame(minHeight: 44, alignment: .leading)
                }
                if let errorText {
                    Text(errorText).font(.callout).foregroundStyle(Theme.danger)
                }
            }
        }
        .navigationTitle("صوت المنبه")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let sound = try AlarmSoundStore.importSound(from: url)
                    sounds = AlarmSoundStore.list()
                    selected = sound.id
                    errorText = nil
                } catch {
                    errorText = error.localizedDescription
                }
            case .failure:
                errorText = String(localized: "ما قدرنا نفتح الملف.")
            }
        }
        .onDisappear { stopPreview() }
    }

    private func row(title: String, id: String, sound: AlarmSoundStore.Sound?) -> some View {
        HStack(spacing: 12) {
            Button {
                selected = id
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if selected == id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.primaryStrong)
                            .accessibilityLabel("محدد")
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let sound {
                Button {
                    togglePreview(sound)
                } label: {
                    Image(systemName: playingID == sound.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primaryStrong)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playingID == sound.id ? "إيقاف التجربة" : "تجربة الصوت")
            }
        }
    }

    private func togglePreview(_ sound: AlarmSoundStore.Sound) {
        if playingID == sound.id { stopPreview(); return }
        stopPreview()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let newPlayer = try? AVAudioPlayer(contentsOf: AlarmSoundStore.url(for: sound)) else { return }
        player = newPlayer
        playingID = sound.id
        newPlayer.play()
        let id = sound.id
        DispatchQueue.main.asyncAfter(deadline: .now() + newPlayer.duration + 0.2) {
            if playingID == id { stopPreview() }
        }
    }

    private func stopPreview() {
        player?.stop()
        player = nil
        playingID = nil
    }
}
