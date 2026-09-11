import Testing
@testable import PraxisCore

@Suite("BoundedHistory")
struct BoundedHistoryTests {
    @Test("empty history has no latest element")
    func emptyHistory() {
        let history = BoundedHistory<Int>(capacity: 3)
        #expect(history.isEmpty)
        #expect(history.count == 0)
        #expect(history.latest == nil)
        #expect(history.newestFirst.isEmpty)
    }

    @Test("appends below capacity keep every element in order")
    func belowCapacity() {
        var history = BoundedHistory<Int>(capacity: 5)
        for value in 1...3 { history.append(value) }
        #expect(history.count == 3)
        #expect(history.latest == 3)
        #expect(history.oldestFirst == [1, 2, 3])
        #expect(history.newestFirst == [3, 2, 1])
    }

    @Test("the 51st record evicts only the oldest, leaving the newest 50")
    func evictsOldestAtSpecCapacity() {
        var history = BoundedHistory<Int>(capacity: 50)
        for value in 1...51 { history.append(value) }
        #expect(history.count == 50)
        #expect(history.oldestFirst.first == 2)
        #expect(history.latest == 51)
        #expect(history.oldestFirst == Array(2...51))
    }

    @Test("capacity one always holds exactly the latest element")
    func capacityOne() {
        var history = BoundedHistory<String>(capacity: 1)
        history.append("a")
        history.append("b")
        #expect(history.count == 1)
        #expect(history.latest == "b")
        #expect(history.newestFirst == ["b"])
    }

    @Test("eviction continues to drop one element per append once full")
    func steadyStateEviction() {
        var history = BoundedHistory<Int>(capacity: 2)
        for value in 1...6 { history.append(value) }
        #expect(history.oldestFirst == [5, 6])
    }
}
