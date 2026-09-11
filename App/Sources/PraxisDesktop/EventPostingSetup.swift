import PraxisCore

/// Event-posting access that can also be requested through an explicit setup
/// action. The controller only ever sees the `EventPostingAccess` half; the
/// request half is reachable from the debug window's setup control alone.
@MainActor
public protocol EventPostingSetup: EventPostingAccess {
    /// May show the system prompt or open System Settings. Returns the access
    /// state reported after the request.
    @discardableResult
    func requestEventPostingAccess() -> Bool
}

extension CGEventPostingAccess: EventPostingSetup {}
