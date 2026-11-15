import Foundation

/// Editing a block tree (blocks nested in containers). All functions are pure.
public extension Array where Element == Block {
    /// Depth-first list of every block, containers included.
    var flattened: [Block] {
        flatMap { [$0] + $0.children.flattened }
    }

    func block(withID id: UUID) -> Block? {
        for b in self {
            if b.id == id { return b }
            if let found = b.children.block(withID: id) { return found }
        }
        return nil
    }

    /// The id of the container holding the block (nil = top level or not found).
    func parentID(of id: UUID) -> UUID? {
        for b in self {
            if b.children.contains(where: { $0.id == id }) { return b.id }
            if let found = b.children.parentID(of: id) { return found }
        }
        return nil
    }

    /// Changes one block in place, wherever it is.
    func updating(_ id: UUID, _ change: (inout Block) -> Void) -> [Block] {
        map { block in
            var b = block
            if b.id == id { change(&b) } else { b.children = b.children.updating(id, change) }
            return b
        }
    }

    func removing(_ id: UUID) -> [Block] {
        filter { $0.id != id }.map { block in
            var b = block
            b.children = b.children.removing(id)
            return b
        }
    }

    /// Adds a block at the top level (`container == nil`) or inside a container, at an index (end if nil or too big).
    func inserting(_ block: Block, into container: UUID?, at index: Int? = nil) -> [Block] {
        func place(_ list: [Block]) -> [Block] {
            var out = list
            let i = Swift.min(Swift.max(index ?? out.count, 0), out.count)
            out.insert(block, at: i)
            return out
        }
        guard let container else { return place(self) }
        return map { b in
            var b = b
            if b.id == container, b.kind == .container {
                b.children = place(b.children)
            } else {
                b.children = b.children.inserting(block, into: container, at: index)
            }
            return b
        }
    }

    /// Moves a block into a container (or the top level). A container can't go inside itself.
    func moving(_ id: UUID, into container: UUID?, at index: Int? = nil) -> [Block] {
        guard let moved = block(withID: id) else { return self }
        if let container, moved.children.flattened.contains(where: { $0.id == container }) || container == id { return self }
        return removing(id).inserting(moved, into: container, at: index)
    }

    /// Copies a block (and its children) right after the original, with fresh ids.
    func duplicating(_ id: UUID) -> [Block] {
        func fresh(_ block: Block) -> Block {
            var b = block
            b.id = UUID()
            b.children = b.children.map(fresh)
            return b
        }
        var out: [Block] = []
        for b in self {
            var b = b
            b.children = b.children.duplicating(id)
            out.append(b)
            if b.id == id { out.append(fresh(b)) }
        }
        return out
    }

    /// Reorders within the same list (top level or one container's children) like SwiftUI's `onMove`.
    func movingWithin(_ container: UUID?, from source: IndexSet, to destination: Int) -> [Block] {
        func reorder(_ list: [Block]) -> [Block] {
            var out = list
            let moving = source.sorted().compactMap { $0 < out.count ? out[$0] : nil }
            for i in source.sorted(by: >) where i < out.count { out.remove(at: i) }
            let shift = source.filter { $0 < destination }.count
            let at = Swift.min(Swift.max(destination - shift, 0), out.count)
            out.insert(contentsOf: moving, at: at)
            return out
        }
        guard let container else { return reorder(self) }
        return map { b in
            var b = b
            if b.id == container { b.children = reorder(b.children) } else { b.children = b.children.movingWithin(container, from: source, to: destination) }
            return b
        }
    }

    /// Same structure with new ids everywhere, and sources pointing at the copies.
    func clonedWithNewIDs() -> [Block] {
        var idMap: [UUID: UUID] = [:]
        for b in flattened { idMap[b.id] = UUID() }
        func clone(_ block: Block) -> Block {
            var b = block
            b.id = idMap[block.id] ?? UUID()
            b.sourceIDs = block.sourceIDs.map { idMap[$0] ?? $0 }
            b.children = block.children.map(clone)
            return b
        }
        return map(clone)
    }
}
