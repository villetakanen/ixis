/// A fixed-capacity, append-only history that discards the oldest element
/// once full. Intended for the bounded record history in debug diagnostics.
public struct BoundedHistory<Element: Sendable>: Sendable {
    public let capacity: Int
    private var storage: [Element] = []

    /// - Parameter capacity: maximum number of retained elements; must be positive.
    public init(capacity: Int) {
        precondition(capacity > 0, "BoundedHistory capacity must be positive")
        self.capacity = capacity
    }

    /// Appends `element`, dropping the oldest elements beyond `capacity`.
    public mutating func append(_ element: Element) {
        storage.append(element)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    /// The most recently appended element, if any.
    public var latest: Element? { storage.last }

    /// Retained elements, newest first.
    public var newestFirst: [Element] { storage.reversed() }

    /// Retained elements, oldest first.
    public var oldestFirst: [Element] { storage }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
}
