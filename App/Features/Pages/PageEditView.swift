import HabitCore
import SwiftUI

private struct AddTarget: Identifiable {
    let id = UUID()
    let container: UUID?
}

private struct ConfigItem: Identifiable {
    let id: UUID
}

/// "تعديل" mode: build the page's structure. Blocks can be added (also inside a container),
/// configured, reordered with the arrows, duplicated, moved into/out of containers and deleted (with undo).
struct PageEditView: View {
    @Binding var page: PageDefinition
    let tabID: UUID

    @State private var addTarget: AddTarget?
    @State private var configItem: ConfigItem?
    @State private var undoSnapshot: [Block]?
    @State private var undoDismiss: Task<Void, Never>?

    private var blocks: [Block] { page.tabs.first { $0.id == tabID }?.blocks ?? [] }

    private func mutate(_ change: ([Block]) -> [Block]) {
        guard let index = page.tabs.firstIndex(where: { $0.id == tabID }) else { return }
        page.tabs[index].blocks = change(page.tabs[index].blocks)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if blocks.isEmpty {
                    Text("الصفحة فاضية. أضف أول قطعة: عنوان، رقم، جدول، مؤقت...")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 24)
                }
                ForEach(blocks) { block in
                    AnyView(row(block))
                }
                Button { addTarget = AddTarget(container: nil) } label: {
                    Label("إضافة قطعة", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, Metrics.homeRingDiameter / 2 + 24)
        }
        .overlay(alignment: .bottom) {
            if undoSnapshot != nil { undoToast }
        }
        .animation(.spring(duration: 0.3), value: undoSnapshot != nil)
        .sheet(item: $addTarget) { target in
            AddBlockSheet { kind in
                let new = Block.make(kind)
                mutate { $0.inserting(new, into: target.container) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if kind != .divider { configItem = ConfigItem(id: new.id) }
                }
            }
            .appRoot()
        }
        .sheet(item: $configItem) { item in
            BlockConfigView(page: $page, blockID: item.id)
                .appRoot()
        }
    }

    // MARK: - Rows

    private func summary(_ block: Block) -> String {
        switch block.kind {
        case .text: return String(block.text.prefix(40))
        case .divider: return "—"
        default: return block.title.isEmpty ? block.kind.arabicName : block.title
        }
    }

    private func row(_ block: Block) -> some View {
        let parent = blocks.parentID(of: block.id)
        let siblings = parent == nil ? blocks : (blocks.block(withID: parent ?? UUID())?.children ?? [])
        let index = siblings.firstIndex { $0.id == block.id } ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: block.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Button { configItem = ConfigItem(id: block.id) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.kind.arabicName)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(summary(block))
                            .font(.body.bold())
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("اضغط لتعديل إعدادات القطعة"))
                actionsMenu(block, parent: parent, index: index, count: siblings.count)
            }
            if block.kind == .container {
                VStack(spacing: 8) {
                    ForEach(block.children) { child in
                        AnyView(row(child))
                    }
                    Button { addTarget = AddTarget(container: block.id) } label: {
                        Label("إضافة داخل المربع", systemImage: "plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.primaryStrong)
                }
                .padding(.leading, 12)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func actionsMenu(_ block: Block, parent: UUID?, index: Int, count: Int) -> some View {
        let descendantIDs = Set(block.children.flattened.map(\.id))
        let containers = blocks.flattened.filter { candidate in
            candidate.kind == .container && candidate.id != block.id && !descendantIDs.contains(candidate.id)
        }
        return Menu {
            Button { move(block.id, parent: parent, from: index, delta: -1) } label: {
                Label("تحريك لفوق", systemImage: "arrow.up")
            }
            .disabled(index == 0)
            Button { move(block.id, parent: parent, from: index, delta: 1) } label: {
                Label("تحريك لتحت", systemImage: "arrow.down")
            }
            .disabled(index >= count - 1)
            Button { mutate { $0.duplicating(block.id) } } label: {
                Label("نسخ", systemImage: "plus.square.on.square")
            }
            if !containers.isEmpty || parent != nil {
                Menu {
                    if parent != nil {
                        Button("إخراج من المربع") { mutate { $0.moving(block.id, into: nil) } }
                    }
                    ForEach(containers) { container in
                        Button(container.title.isEmpty ? "مربع" : container.title) {
                            mutate { $0.moving(block.id, into: container.id) }
                        }
                    }
                } label: {
                    Label("نقل إلى", systemImage: "arrow.right.circle")
                }
            }
            Button(role: .destructive) { delete(block.id) } label: {
                Label("حذف", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("خيارات القطعة"))
    }

    private func move(_ id: UUID, parent: UUID?, from index: Int, delta: Int) {
        let destination = delta < 0 ? index - 1 : index + 2
        mutate { $0.movingWithin(parent, from: IndexSet(integer: index), to: destination) }
    }

    private func delete(_ id: UUID) {
        undoSnapshot = blocks
        mutate { $0.removing(id) }
        undoDismiss?.cancel()
        undoDismiss = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { undoSnapshot = nil }
        }
    }

    private var undoToast: some View {
        HStack {
            Text("انحذفت القطعة")
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button("تراجع") {
                if let snapshot = undoSnapshot { mutate { _ in snapshot } }
                undoDismiss?.cancel()
                undoSnapshot = nil
            }
            .font(.subheadline.bold())
            .foregroundStyle(Theme.primaryStrong)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, Metrics.homeRingDiameter / 2 + 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// "إضافة قطعة": block types grouped by category.
struct AddBlockSheet: View {
    let onPick: (BlockKind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(BlockKind.categories.enumerated()), id: \.offset) { _, category in
                    Section(category.name) {
                        ForEach(category.kinds, id: \.self) { kind in
                            Button {
                                dismiss()
                                onPick(kind)
                            } label: {
                                Label(kind.arabicName, systemImage: kind.symbol)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .navigationTitle("إضافة قطعة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
