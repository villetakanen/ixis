import CoreGraphics
import PraxisCore

/// Production `EventPostingAccess` over the public CoreGraphics preflight and
/// request functions.
///
/// `hasEventPostingAccess()` only preflights; it never prompts. Requesting is a
/// separate, explicit setup action. Both functions are injectable so tests can
/// verify the wiring without touching the real privacy database.
@MainActor
public final class CGEventPostingAccess: EventPostingAccess {
    public typealias Check = @MainActor () -> Bool

    private let preflight: Check
    private let request: Check
    private(set) public var preflightCount = 0
    private(set) public var requestCount = 0

    public init(
        preflight: @escaping Check = { CGPreflightPostEventAccess() },
        request: @escaping Check = { CGRequestPostEventAccess() }
    ) {
        self.preflight = preflight
        self.request = request
    }

    /// Current access, checked live. Called by the controller before every action.
    public func hasEventPostingAccess() -> Bool {
        preflightCount += 1
        return preflight()
    }

    /// Explicit setup action. May show the system prompt or open System
    /// Settings; returns the access state reported after the request. Never
    /// called from a navigation request.
    @discardableResult
    public func requestEventPostingAccess() -> Bool {
        requestCount += 1
        return request()
    }
}
