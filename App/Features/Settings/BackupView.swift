import HabitCore
import SwiftData
import SwiftUI

/// "النسخ الاحتياطي": export to a file, import from one, and the weekly copies kept inside the app.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.autoBackupEnabled) private var autoBackup = true
    @AppStorage(SettingsKey.lastBackupAt) private var lastBackupAt = 0.0

    @State private var exportFile: BackupFile?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pending: BackupDocument?
    @State private var internalFiles: [URL] = []
    @State private var message: BackupMessage?

    private struct BackupMessage: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    var body: some View {
        Form {
            Section {
                Button {
                    exportNow()
                } label: {
                    Label("تصدير نسخة احتياطية", systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
                Button {
                    showImporter = true
                } label: {
                    Label("استيراد نسخة", systemImage: "square.and.arrow.down")
                }
                .frame(minHeight: 44)
            } header: {
                Text("ملف النسخة")
            } footer: {
                Text("التصدير يعطيك ملف واحد فيه كل بياناتك: المهمات والتنبيهات والصفحات والإنجازات والجوائز والإعدادات. احفظه في تطبيق «الملفات» أو iCloud Drive. بياناتك على الجوال بس، فلو انحذف التطبيق بدون نسخة تضيع.")
            }

            Section {
                Toggle("نسخة تلقائية كل أسبوع", isOn: $autoBackup)
                LabeledContent("آخر نسخة") {
                    Text(lastBackupText)
                }
                Button {
                    saveInternalNow()
                } label: {
                    Label("احفظ نسخة داخل التطبيق الحين", systemImage: "externaldrive.badge.plus")
                }
                .frame(minHeight: 44)
            } header: {
                Text("النسخ التلقائية")
            } footer: {
                Text("نحتفظ بآخر 4 نسخ داخل التطبيق، وتلقاها في تطبيق «الملفات» تحت اسم التطبيق. انتبه: هذي النسخ تنحذف مع التطبيق، فصدّر نسخة لمكان ثاني من وقت لوقت.")
            }

            if !internalFiles.isEmpty {
                Section("النسخ داخل التطبيق") {
                    ForEach(internalFiles, id: \.self) { url in
                        Button {
                            load(url: url, scoped: false)
                        } label: {
                            HStack {
                                Text(fileTitle(url))
                                Spacer()
                                Text("استرجاع").foregroundStyle(Theme.primaryStrong).font(.subheadline.bold())
                            }
                            .frame(minHeight: 44)
                        }
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .navigationTitle("النسخ الاحتياطي")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { internalFiles = BackupService.internalBackups() }
        .fileExporter(
            isPresented: $showExporter, document: exportFile, contentType: .json,
            defaultFilename: "habits-backup-\(Self.todayName())"
        ) { result in
            if case .failure = result {
                message = BackupMessage(title: String(localized: "ما انحفظت النسخة"), text: String(localized: "جرّب مرة ثانية أو اختر مكان ثاني."))
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): load(url: url, scoped: true)
            case .failure:
                message = BackupMessage(title: String(localized: "ما انفتح الملف"), text: String(localized: "تأكد إنه ملف نسخة من التطبيق."))
            }
        }
        .alert(item: $message) { item in
            Alert(title: Text(item.title), message: Text(item.text), dismissButton: .default(Text("تم")))
        }
        .confirmationDialog(
            "استبدال كل بياناتك؟", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible, presenting: pending
        ) { document in
            Button("استبدال بياناتي بهذي النسخة", role: .destructive) { restore(document) }
            Button("إلغاء", role: .cancel) { pending = nil }
        } message: { document in
            Text(previewText(document))
        }
    }

    // MARK: - Actions

    private func exportNow() {
        do {
            exportFile = BackupFile(data: try BackupService.encodedBackup(context: context))
            showExporter = true
        } catch {
            message = BackupMessage(title: String(localized: "ما انسوت النسخة"), text: String(localized: "صار خطأ وقت تجهيز البيانات."))
        }
    }

    private func saveInternalNow() {
        if BackupService.saveInternalBackup(context: context) {
            internalFiles = BackupService.internalBackups()
            message = BackupMessage(title: String(localized: "انحفظت النسخة"), text: String(localized: "تلقاها في تطبيق «الملفات» داخل مجلد التطبيق."))
        } else {
            message = BackupMessage(title: String(localized: "ما فيه شي ينحفظ"), text: String(localized: "أضف مهمة أو تنبيه أول."))
        }
    }

    private func load(url: URL, scoped: Bool) {
        let accessing = scoped && url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            pending = try BackupCoding.decode(data)
        } catch BackupError.newerVersion {
            message = BackupMessage(title: String(localized: "النسخة من إصدار أحدث"), text: String(localized: "حدّث التطبيق أول ثم استورد."))
        } catch {
            message = BackupMessage(title: String(localized: "الملف مو نسخة صالحة"), text: String(localized: "تأكد إنه ملف نسخة من التطبيق وما انعدّل."))
        }
    }

    private func restore(_ document: BackupDocument) {
        pending = nil
        do {
            try BackupService.restore(document, context: context)
            Task { await AlarmActions.replan(container: AppEnvironment.shared.container) }
            message = BackupMessage(title: String(localized: "تم الاسترجاع"), text: String(localized: "رجعت بياناتك من النسخة."))
        } catch {
            message = BackupMessage(title: String(localized: "ما تم الاسترجاع"), text: String(localized: "صار خطأ. بياناتك الحالية ما تغيرت إلا إذا بدأ الاستبدال."))
        }
    }

    // MARK: - Text

    private func previewText(_ document: BackupDocument) -> String {
        let s = BackupCoding.summary(of: document)
        let date = document.createdAt.formatted(date: .abbreviated, time: .shortened)
        let lines = [
            String(localized: "نسخة بتاريخ \(date)"),
            String(localized: "\(s.tasks) مهمة · \(s.alarms) تنبيه · \(s.pages) صفحة"),
            String(localized: "\(s.completions) إنجاز مهمة · \(s.achievements) إنجاز · \(s.rewards) جائزة"),
            String(localized: "كل بياناتك الحالية بتنحذف وتنستبدل.")
        ]
        return digits.format(lines.joined(separator: "\n"))
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return String(localized: "ما فيه") }
        return digits.format(Date(timeIntervalSince1970: lastBackupAt).formatted(date: .abbreviated, time: .shortened))
    }

    private func fileTitle(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "habits-backup-", with: "")
        return digits.format(name)
    }

    private static func todayName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
