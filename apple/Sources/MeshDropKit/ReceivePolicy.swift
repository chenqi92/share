import Foundation

enum ReceivePolicy {
    static func autoAcceptTrusted(defaults: UserDefaults) -> Bool {
        let key = "meshdrop.autoReceiveTrusted"
        if let saved = defaults.object(forKey: key) as? Bool { return saved }
        // The old default required two opposing switches. Preserve an explicit
        // manual choice made with that override disabled; migrate the default.
        let manual = defaults.object(forKey: "meshdrop.verifyBeforeReceive") as? Bool == false
            && defaults.object(forKey: "meshdrop.autoAcceptTrusted") as? Bool == false
        defaults.set(!manual, forKey: key)
        return !manual
    }

    static func shouldAutoAccept(isTrusted: Bool, enabled: Bool) -> Bool {
        isTrusted && enabled
    }
}
