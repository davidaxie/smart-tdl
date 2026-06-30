import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension principal class — turns shared text or a shared link into a queued
/// capture that the main app drains on its next activation (see `CaptureInbox`). The
/// extension never opens the full app and never writes `tasks.json` directly; it only
/// appends to the App Group queue, so capture is instant and the app stays the single
/// writer of the store.
///
/// NOT YET A BUILD TARGET. This file, its `Info.plist`, and `ShareExtension.entitlements`
/// are ready to drop into a new "Share Extension" target — see `ShareExtension/README.md`
/// for the exact steps. `CaptureInbox.swift` must be added to the extension target's
/// membership too (it's shared between app and extension). Everything here compiles once
/// the target exists with the App Group capability.
final class ShareViewController: SLComposeServiceViewController {

    /// Always valid — capture is forgiving; an empty note is simply dropped on post.
    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        var captured: [String] = []

        // Whatever the user typed in the share sheet's compose box.
        if let typed = contentText?.trimmingCharacters(in: .whitespacesAndNewlines), !typed.isEmpty {
            captured.append(typed)
        }

        let group = DispatchGroup()
        for item in (extensionContext?.inputItems as? [NSExtensionItem]) ?? [] {
            for provider in item.attachments ?? [] {
                // A shared URL → capture its string (e.g. an article to read).
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                        if let url = value as? URL { captured.append(url.absoluteString) }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
                        if let text = value as? String { captured.append(text) }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            let inbox = CaptureInbox()
            for text in captured { inbox.enqueue(text) }
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
