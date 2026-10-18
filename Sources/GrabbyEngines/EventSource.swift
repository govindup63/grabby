import CoreGraphics

/// One tagged source for everything Grabby posts, so its own taps can ignore its own events.
public enum GrabbyEventSource {
    public static let tag: Int64 = 0x4752_4142  // "GRAB"

    nonisolated(unsafe) public static let shared: CGEventSource? = {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = tag
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    public static func isOwnEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == tag
    }
}
