import Foundation

/// Generic Union-Find (Disjoint Set Union) with path compression and union by rank.
/// All mutating operations are value-semantic; copy the struct to take a snapshot.
public struct UnionFind<Element: Hashable> {
    // Map each element to its parent. Roots map to themselves.
    private var parent: [Element: Element] = [:]
    // Rank is an upper bound on tree height, used to keep trees balanced.
    private var rank: [Element: Int] = [:]

    public init() {}

    // MARK: - Public API

    /// Ensures `element` is tracked. No-op if already present.
    public mutating func insert(_ element: Element) {
        guard parent[element] == nil else { return }
        parent[element] = element
        rank[element] = 0
    }

    /// Merges the sets containing `a` and `b`.
    /// Inserts either element automatically if not yet tracked.
    public mutating func union(_ a: Element, _ b: Element) {
        insert(a)
        insert(b)
        let rootA = find(a)
        let rootB = find(b)
        guard rootA != rootB else { return }

        // Union by rank: attach the shorter tree under the taller one.
        let rankA = rank[rootA, default: 0]
        let rankB = rank[rootB, default: 0]
        if rankA < rankB {
            parent[rootA] = rootB
        } else if rankA > rankB {
            parent[rootB] = rootA
        } else {
            parent[rootB] = rootA
            rank[rootA, default: 0] += 1
        }
    }

    /// Returns the representative element (root) of `element`'s set.
    /// Inserts the element automatically if not yet tracked.
    @discardableResult
    public mutating func find(_ element: Element) -> Element {
        insert(element)
        // Path compression: collapse the path to the root.
        if parent[element] != element {
            parent[element] = find(parent[element]!)
        }
        return parent[element]!
    }

    /// Returns all disjoint components as arrays of elements.
    /// The order of components and elements within each component is unspecified.
    public func components() -> [[Element]] {
        // We need a mutable copy for path compression during find.
        var copy = self
        var groups: [Element: [Element]] = [:]
        for element in parent.keys {
            let root = copy.find(element)
            groups[root, default: []].append(element)
        }
        return Array(groups.values)
    }
}
