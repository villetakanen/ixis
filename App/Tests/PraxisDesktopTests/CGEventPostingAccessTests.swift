import Testing
@testable import PraxisDesktop

@MainActor
@Suite("CGEventPostingAccess wiring")
struct AccessWiringTests {
    /// Builds an access wrapper over counters, so no real privacy call happens.
    @MainActor
    final class Probe {
        var preflightResult = false
        var requestResult = false
        private(set) var preflights = 0
        private(set) var requests = 0

        func makeAccess() -> CGEventPostingAccess {
            CGEventPostingAccess(
                preflight: { [self] in preflights += 1; return preflightResult },
                request: { [self] in requests += 1; return requestResult }
            )
        }
    }

    @Test("checking access preflights once and never requests")
    func checkOnlyPreflights() {
        let probe = Probe()
        probe.preflightResult = true
        let access = probe.makeAccess()
        #expect(access.hasEventPostingAccess() == true)
        probe.preflightResult = false
        #expect(access.hasEventPostingAccess() == false, "each check reflects the live answer")
        #expect(probe.preflights == 2)
        #expect(probe.requests == 0)
        #expect(access.preflightCount == 2)
        #expect(access.requestCount == 0)
    }

    @Test("requesting access is a separate explicit action and reports the request's answer")
    func requestIsExplicit() {
        let probe = Probe()
        probe.requestResult = true
        let access = probe.makeAccess()
        #expect(access.requestEventPostingAccess() == true)
        #expect(probe.requests == 1)
        #expect(probe.preflights == 0, "requesting does not implicitly preflight")
    }

    @Test("the real preflight can be consulted without prompting and returns a Bool")
    func realPreflightIsCallable() {
        // CGPreflightPostEventAccess reports current state without showing UI.
        // The value depends on the tester's privacy settings and is not asserted.
        let access = CGEventPostingAccess()
        _ = access.hasEventPostingAccess()
        #expect(access.preflightCount == 1)
        #expect(access.requestCount == 0)
    }
}
