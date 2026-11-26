import AppKit

final class DockLocker {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var displays: [CGRect] = []
    private var allowed: Int?

    var optionOverride = true

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func update(allowedDisplay: CGDirectDisplayID?) {
        let ids = Displays.active()
        displays = ids.map(CGDisplayBounds)
        allowed = allowedDisplay.flatMap { ids.firstIndex(of: $0) }
    }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        stop()

        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        let callback: CGEventTapCallBack = { _, type, event, context in
            let locker = Unmanaged<DockLocker>.fromOpaque(context!).takeUnretainedValue()
            locker.handle(type, event)
            return Unmanaged.passUnretained(event)
        }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard let allowed, !(optionOverride && event.flags.contains(.maskAlternate)) else { return }

        let point = event.location
        let constrained = DockGeometry.constrain(point, displays: displays, allowed: allowed)
        guard constrained != point else { return }

        event.location = constrained
        event.setIntegerValueField(.mouseEventDeltaY, value: 0)
    }
}
