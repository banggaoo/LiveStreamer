import Foundation

/**
 flash.events.IEventDispatcher for Swift
 */
public protocol IEventDispatcher: class {
    func addEventListener(_ type: String, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func removeEventListener(_ type: String, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func dispatch(event: Event)
    func dispatch(_ type: String, bubbles: Bool, data: Any?)
}

public enum EventPhase: UInt8 {
    case capturing = 0
    case atTarget  = 1
    case bubbling  = 2
    case dispose   = 3
}

// MARK: -
/**
 flash.events.Event for Swift
 */
public class Event: NSObject {
    public static let SYNC: String = "sync"
    public static let EVENT: String = "event"
    public static let IO_ERROR: String = "ioError"
    public static let RTMP_STATUS: String = "rtmpStatus"

    public static func from(_ notification: Notification) -> Event {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let event: Event = userInfo["event"] as? Event else {
            return Event(type: Event.EVENT)
        }
        return event
    }

    public fileprivate(set) var type: String
    public fileprivate(set) var bubbles: Bool
    public fileprivate(set) var data: Any?
    public fileprivate(set) var target: AnyObject?

    public override var description: String {
        return Mirror(reflecting: self).description
    }

    public init(type: String, bubbles: Bool = false, data: Any? = nil) {
        self.type = type
        self.bubbles = bubbles
        self.data = data
    }
}

// MARK: -
/**
 flash.events.EventDispatcher for Swift
 */
public class EventDispatcher: NSObject, IEventDispatcher {

    private weak var target: AnyObject?

    override public init() {
        super.init()
    }

    public init(target: AnyObject) {
        self.target = target
    }

    deinit {
        target = nil
    }

    public final func addEventListener(_ type: String, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self, selector: selector, name: Notification.Name(rawValue: "\(type)/\(useCapture)"), object: target ?? self
        )
    }

    public final func removeEventListener(_ type: String, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self, name: Notification.Name(rawValue: "\(type)/\(useCapture)"), object: target ?? self
        )
    }

    public func dispatch(event: Event) {
        event.target = target ?? self
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "\(event.type)/false"), object: target ?? self, userInfo: ["event": event]
        )
        event.target = nil
    }

    public final func dispatch(_ type: String, bubbles: Bool, data: Any?) {
        dispatch(event: Event(type: type, bubbles: bubbles, data: data))
    }
}
