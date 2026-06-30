# Share Extension — capture from anywhere

Turns shared text / links into a Smart TDL task. The extension only appends to the App
Group queue (`CaptureInbox`); the app drains it into today's list on next activation
(`TaskStore.drainCaptures()`, already wired in `SmartTDLApp`).

**Why it isn't a build target yet:** an app-extension target plus the App Group
capability require an Apple Developer team and provisioning — they can't be created or
signed under the headless/ad-hoc build loop. The code and config here are complete and
ready; adding the target is a few clicks in Xcode once signing is set up.

## Files
- `ShareViewController.swift` — the principal class (capture logic).
- `Info.plist` — the `NSExtension` declaration (share-services point + activation rules).
- `ShareExtension.entitlements` — the `group.com.smarttdl` App Group.

## Steps to add the target (in Xcode, after team signing is set up)
1. **File ▸ New ▸ Target… ▸ Share Extension.** Name it `ShareExtension`. Delete the
   stub files Xcode generates and add the three files in this folder instead.
2. **Signing & Capabilities** (for BOTH the app target and the new extension target):
   add the **App Groups** capability and check **`group.com.smarttdl`**. The app already
   ships an entitlements file expecting this group; the extension uses
   `ShareExtension.entitlements`.
3. **Target membership:** add `SmartTDL/CaptureInbox.swift` to the **ShareExtension**
   target too (Xcode ▸ File Inspector ▸ Target Membership). It's the one shared source.
4. Confirm the extension's **Info.plist** is set to this folder's `Info.plist`, and its
   **Code Signing Entitlements** build setting points to `ShareExtension.entitlements`.
5. Build & run the app once so the App Group container exists, then share text/a link
   from Safari → **Add to Smart TDL** → reopen the app: the capture appears in Today.

## Verify (the part that needs a device)
- Share plain text → a task with that text lands in Today.
- Share a Safari URL → a task with the URL lands in Today.
- Capture while the app is backgrounded → it drains on next foreground
  (`scenePhase == .active`), not just cold launch.
