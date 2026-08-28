# HiddenNotch

*[한국어](README.ko.md)*

A tiny macOS app that keeps the MacBook menu bar background black so the notch stops
standing out.

The state holds through the things that normally break this trick: connecting and
disconnecting an external display, changing the wallpaper, waking from sleep, rebooting.
You set it once and never touch it again.

584 KB on disk, 42 MB resident. No Dock icon — it lives in the menu bar only.

## Download

**[Get HiddenNotch 1.0 (dmg)](https://github.com/kimhung910924/hiddennotch/releases/latest)**

- macOS 13 Ventura or later
- Notarized by Apple, so it opens without a Gatekeeper warning
- Open the dmg and drag HiddenNotch to `Applications`
- Requests no permissions

## Contact

[rrllab.com](https://rrllab.com) · contact@rrllab.com

---

## Requirements to build

- macOS 13 Ventura or later
- Xcode 16 or later (the project uses file system synchronized groups)
- No external dependencies

## Build and run

```bash
xcodebuild -scheme HiddenNotch -configuration Release build
```

```bash
xcodebuild test -scheme HiddenNotch -configuration Debug
```

Opening it in Xcode works too. It never appears in the Dock, only as an icon on the right
side of the menu bar.

### Ship a release

```bash
./scripts/release.sh            # Developer ID signing, notarization, dmg
./scripts/release.sh --publish  # and upload to GitHub Releases
```

## How it works

The wallpaper file is never touched. A black panel is laid across the menu bar strip of
every screen that has a notch, sitting **just above the desktop and below everything else**
(`kCGDesktopIconWindowLevel + 1`). The menu bar itself is translucent, so when what is
behind it turns black, the bar and both sides of the notch go black together while menu
bar text and icons stay visible.

The level is deliberately low because of the cases where there is **no** menu bar. Mission
Control and full screen apps draw their own UI all the way to the top of the display, and a
panel above them clips it — the visible symptom was desktop thumbnails in Mission Control
losing their top edge. The menu bar strip is territory ordinary windows cannot occupy
anyway, so a low level is not covered during normal use.

- The panel sets `ignoresMouseEvents = true`, so it never swallows a click.
- It joins all Spaces (`canJoinAllSpaces`) and stays out of Cmd-Tab and Mission Control
  cycling.
- Overlay height is not hardcoded. Per screen it takes the largest of the safe area inset,
  the auxiliary area, and the measured menu bar height — the numbers differ per display
  (33 pt built-in, 30 pt external, in one measured setup).
- On an external display `visibleFrame` does not shrink even when a menu bar is present, so
  the height cannot be derived from it. The real menu bar window coordinates are read from
  the window list instead (`MenuBarProbe`). Only coordinates and owner are read, so no
  screen recording permission is needed and no private API is involved.
- AppKit's habit of pushing windows below the menu bar is disabled by overriding
  `constrainFrameRect`. Without that one override the black strip sits one menu bar height
  too low.

## External displays

The default follows the plan: **notch screens only**. Turning on `Apply to external
displays` in the menu blacks out the menu bar on non-notch external monitors as well. It is
a toggle rather than always-on so the default behavior matches the original spec.

That setting is a third `UserDefaults` value (`applyToAllScreens`), which departs from the
two-value rule in the plan. The core rule still holds: no screen ID, coordinate, or
resolution is ever stored.

## What keeps the state from slipping

Four layers, because each one alone was seen to fail:

1. **Full rebuild** — when the screen set changes, existing window frames are not patched.
   Every overlay is discarded and rebuilt.
2. **Delayed re-check** — right after an external display is connected, macOS does not
   settle the screen list and coordinates in one shot. State is applied immediately and then
   re-checked at 0.5 s, 1.5 s, and 3 s. Bursts of events are debounced.
3. **Watchdog** — every 15 seconds it compares screen count, overlay count, and frames by
   value alone, and rebuilds itself on any mismatch. Missing an event notification is
   recoverable.
4. **No cache** — screen IDs, coordinates, and resolutions are never persisted. The only
   values in `UserDefaults` are `isEnabled` and `launchAtLoginRequested`.

## Launch at login

Uses `SMAppService.mainApp`. When macOS puts registration in the `requiresApproval` state,
the menu shows an entry that opens the Login Items pane in System Settings.

Registration can fail for ad-hoc signed development builds. To verify launch at login for
real, move the app to `/Applications` first.

## Verified and remaining

Confirmed on hardware (built-in notch display plus a connected external monitor):

- Only notch screens are targeted; no overlay is created on the external monitor.
- The overlay lands at exactly 1470×33 at the top of the built-in display, matching the
  menu bar strip.
- 16 unit tests pass.

Still needs a human looking at the screen:

- Menu bar text and icons are not covered
- Full screen apps are not covered at the top — the overlay is meant to disappear on its
  own when the screen reports a menu bar / safe area of 0, but some macOS versions may keep
  the value, so this needs real-world confirmation
- Behavior with menu bar auto-hide turned on

## Layout

```text
HiddenNotch/
├── App/          entry point, app lifecycle
├── StatusBar/    menu bar item and menu
├── Display/      screen snapshot, notch detection, rebuild coordination
├── Overlay/      the black panel and its geometry
├── Stability/    system event watching, debounce and retry, watchdog
├── LoginItem/    SMAppService registration
└── Settings/     the two UserDefaults values
```

The original planning document is [HIDDENNOTCH-PLAN.md](HIDDENNOTCH-PLAN.md) (Korean).
