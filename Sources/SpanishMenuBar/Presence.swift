import CoreGraphics

/// "Seen" means: Mac awake, display on, session not locked / switched away, and the mouse moved recently.
enum Presence {
    static func userIsPresent(mouseMovedWithin window: Double) -> Bool {
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            if session["CGSSessionScreenIsLocked"] as? Bool == true { return false }
            if session[kCGSessionOnConsoleKey as String] as? Bool == false { return false }
        }
        if CGDisplayIsAsleep(CGMainDisplayID()) != 0 { return false }
        // Reading idle times needs no special permission (unlike event taps).
        let idle = [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged]
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
        return idle <= window
    }
}
