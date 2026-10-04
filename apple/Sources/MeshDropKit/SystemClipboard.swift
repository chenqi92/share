import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

@MainActor
public enum SystemClipboard {
    public static func copy(_ text: String) {
        #if os(macOS)
        write(text, to: .general)
        #elseif os(iOS) || os(visionOS)
        UIPasteboard.general.string = text
        #endif
    }

    #if os(macOS)
    static func write(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    #endif
}
