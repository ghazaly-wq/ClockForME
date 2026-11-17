import HabitCore
import SwiftUI

/// Settings > AI keys. The user picks a provider, pastes a key, and saved keys form a fallback list.
struct AIKeysView: View {
    @State private var book = AIKeyStore.load()
    @State private var provider: AIProvider = .google
    @State private var keyText = ""
    @State private var message: String?
    @State private var saveFailed = false
    @State private var testing: UUID?
    @State private var results: [UUID: String] = [:]

    var body: some View {
        List {
            Section {
                Picker("المزوّد", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)

                SecureField("الصق المفتاح هنا", text: $keyText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)

                Button("حفظ المفتاح", action: addKey)
                    .disabled(keyText.isEmpty)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(saveFailed ? Theme.danger : .secondary)
                }
            } header: {
                Text("إضافة مفتاح")
            } footer: {
                Text("تجيب المفتاح من حسابك عند المزوّد (الشرح تحت) وتلصقه هنا. المفاتيح تنحفظ على جوالك بس، ما تدخل النسخ الاحتياطي ولا تنرسل لأي جهة غير المزوّد اللي تستخدمه.")
            }

            Section {
                AIProviderGuideView(provider: provider)
            } header: {
                Text("شرح جلب المفتاح")
            }

            Section {
                if book.entries.isEmpty {
                    Text("ما أضفت أي مفتاح للحين.").foregroundStyle(.secondary)
                }
                ForEach(book.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.provider.displayName).font(.subheadline.weight(.semibold))
                        Text(AIKeyBook.masked(entry.key))
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .environment(\.layoutDirection, .leftToRight)
                        HStack {
                            Button(testing == entry.id ? "جاري الاختبار…" : "اختبر المفتاح") { runTest(entry) }
                                .font(.footnote)
                                .buttonStyle(.borderless)
                                .disabled(testing != nil)
                            if let result = results[entry.id] {
                                Text(result)
                                    .font(.footnote)
                                    .foregroundStyle(result == "المفتاح شغّال ✓" ? Theme.primary : Theme.danger)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) { book.remove(id: book.entries[index].id) }
                    persist()
                }
                .onMove { source, destination in
                    book.move(from: source, to: destination)
                    persist()
                }
            } header: {
                HStack {
                    Text("مفاتيحي (ترتيب الاحتياط)")
                    Spacer()
                    if book.entries.count > 1 { EditButton().font(.footnote) }
                }
            } footer: {
                Text("يجرّب التطبيق المفتاح الأول، وإذا فشل (خلص الرصيد أو المفتاح غلط) ينتقل للي بعده. اسحب لتغيير الترتيب، واسحب جانباً للحذف.")
            }
        }
        .navigationTitle("مفاتيح الذكاء الاصطناعي")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addKey() {
        if let problem = book.problem(with: keyText) {
            saveFailed = true
            message = switch problem {
            case .empty: "الخانة فاضية."
            case .hasSpaces: "المفتاح فيه مسافات. تأكد إنك لصقت المفتاح كامل بدون كلام زيادة."
            case .tooShort: "المفتاح قصير. تأكد إنك نسخته كامل."
            case .duplicate: "هذا المفتاح مضاف من قبل."
            }
            return
        }
        book.add(provider: provider, key: keyText)
        keyText = ""
        persist()
        if !saveFailed { message = "انحفظ المفتاح ✓" }
    }

    private func runTest(_ entry: AIKeyEntry) {
        testing = entry.id
        results[entry.id] = nil
        Task {
            let problem = await AIClient.test(entry)
            results[entry.id] = problem ?? "المفتاح شغّال ✓"
            testing = nil
        }
    }

    private func persist() {
        saveFailed = !AIKeyStore.save(book)
        if saveFailed { message = "ما قدرت أحفظ المفتاح في جوالك. جرّب مرة ثانية." }
    }
}
