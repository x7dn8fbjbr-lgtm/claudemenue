import AppKit
import Carbon.HIToolbox

class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKey: (() -> Void)?

    func start() {
        var hotKeyID = EventHotKeyID(signature: 0x434D4A4B, id: 1) // "CMJK"
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ptr = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotKey?() }
                return noErr
            },
            1, &eventSpec, selfPtr, &eventHandler
        )

        // ⌘⇧J: keyCode 38 = J
        RegisterEventHotKey(38, UInt32(cmdKey | shiftKey), hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func stop() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandler { RemoveEventHandler(ref); eventHandler = nil }
    }

    deinit { stop() }
}
