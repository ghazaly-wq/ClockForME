import HabitCore
import SwiftUI

/// Page settings: name, emoji, accent, tabs, rotation, schedule (same editor as alarms),
/// "main task" toggle, pinning, duplicate / save as template / delete.
struct PageSettingsView: View {
    @Binding var page: PageDefinition
    let onDuplicate: () -> Void
    let onSaveTemplate: () -> Void
    /// `true` = also delete the page's alarm and stop its task; `false` = keep them as ordinary items.
    let onDelete: (_ everything: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteDialog = false
    @State private var templateSaved = false

    private var scheduleEnabled: Binding<Bool> {
        Binding(
            get: { page.schedule != nil },
            set: { on in
                if on {
                    page.schedule = PageSchedule(repetition: .weekly(Set(Weekday.allCases)), time: .clock(hour: 18, minute: 0))
                } else {
                    page.schedule = nil
                    page.isMainTask = false
                    page.rotatesTabs = false
                }
            }
        )
    }

    private var scheduleBinding: Binding<PageSchedule> {
        Binding(
            get: { page.schedule ?? PageSchedule(repetition: .daily, time: .clock(hour: 18, minute: 0)) },
            set: { page.schedule = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("الصفحة") {
                    TextField("اسم الصفحة", text: $page.name)
                    HStack {
                        Text("الإيموجي")
                        Spacer()
                        TextField("📄", text: $page.emoji)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                            .onChange(of: page.emoji) { _, newValue in
                                if newValue.count > 1 { page.emoji = String(newValue.suffix(1)) }
                            }
                    }
                    .frame(minHeight: 44)
                    accentPicker
                }

                Section {
                    ForEach($page.tabs) { $tab in
                        TextField("اسم التبويب", text: $tab.name)
                    }
                    .onDelete { offsets in
                        guard page.tabs.count - offsets.count >= 1 else { return }
                        page.tabs.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        page.tabs.move(fromOffsets: source, toOffset: destination)
                    }
                    Button {
                        page.tabs.append(PageTab(name: "تبويب \(page.tabs.count + 1)"))
                    } label: {
                        Label("إضافة تبويب", systemImage: "plus")
                            .frame(minHeight: 44)
                    }
                } header: {
                    Text("التبويبات")
                } footer: {
                    Text("اضغط تعديل فوق لإعادة ترتيب التبويبات أو حذفها.")
                }

                Section {
                    Toggle("للصفحة موعد", isOn: scheduleEnabled)
                } footer: {
                    Text("الموعد يسوي تنبيه تلقائي يفتح الصفحة، وتقدر تخليها مهمة رئيسية.")
                }

                if page.schedule != nil {
                    ScheduleFields(schedule: scheduleBinding)
                    Section {
                        Toggle("مهمة رئيسية", isOn: $page.isMainTask)
                        if page.tabs.count > 1 {
                            Toggle("تدوير التبويبات مع كل جلسة", isOn: $page.rotatesTabs)
                        }
                    } footer: {
                        Text(page.isMainTask
                             ? "تظهر في المهمات والرئيسية والويدجت في أيام الموعد، وزر \"إنهاء الجلسة\" يكمّلها."
                             : "")
                        + Text(page.rotatesTabs ? " كل جلسة تفتح التبويب اللي بعد السابق بالترتيب (أ ← ب ← ج ← أ...)." : "")
                    }
                }

                Section {
                    Toggle("تثبيت في الرئيسية", isOn: $page.pinnedToHome)
                }

                Section {
                    Button { onDuplicate(); dismiss() } label: {
                        Label("نسخ الصفحة", systemImage: "plus.square.on.square").frame(minHeight: 44)
                    }
                    Button {
                        onSaveTemplate()
                        templateSaved = true
                    } label: {
                        Label(templateSaved ? "انحفظت في قوالبي" : "حفظ كقالب", systemImage: templateSaved ? "checkmark" : "square.and.arrow.down")
                            .frame(minHeight: 44)
                    }
                    .disabled(templateSaved)
                    Button(role: .destructive) { showDeleteDialog = true } label: {
                        Label("حذف الصفحة", systemImage: "trash").frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("إعدادات الصفحة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                }
            }
            .confirmationDialog("حذف \"\(page.name)\"", isPresented: $showDeleteDialog, titleVisibility: .visible) {
                Button("حذف كل شي (الصفحة والتنبيه والمهمة والسجل)", role: .destructive) {
                    onDelete(true)
                }
                Button("حذف الصفحة وسجلها فقط", role: .destructive) {
                    onDelete(false)
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("\"حذف كل شي\" يوقف مهمتها من اليوم (الأيام اللي مضت وستريكك ما تتغير). \"حذف الصفحة وسجلها فقط\" يخلي التنبيه والمهمة عناصر عادية.")
            }
        }
        .presentationDetents([.large])
    }

    private var accentPicker: some View {
        HStack(spacing: 10) {
            Text("اللون")
            Spacer()
            ForEach(PageAccent.allCases) { accent in
                let selected = page.accent == accent.rawValue
                Button {
                    page.accent = accent.rawValue
                } label: {
                    ZStack {
                        Circle().fill(accent.color).frame(width: 28, height: 28)
                        if selected {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accent.arabicName))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
