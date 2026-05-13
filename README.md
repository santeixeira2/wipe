# Wipe

A macOS menu bar app to monitor and clean up disk space hogs.

## Features

- Lives in the menu bar, out of the Dock
- Shows free disk space at a glance
- Scans common space hogs: DerivedData, npm cache, iOS Simulators, Android SDK, and more
- One-click delete with a clear warning explaining what each folder contains
- Launch at Login toggle
- Low disk space alert: sends a notification when free space drops below a configurable threshold (5, 10, 15, 20 or 30 GB)

## Requirements

- macOS 13 (Ventura) or later

## Installation

No Apple Developer account required. Build it yourself:

1. Clone the repo
2. Open `Wipe.xcodeproj` in Xcode
3. Select your Mac as the run destination
4. Press `Cmd+R`

> First launch on another Mac will show a Gatekeeper warning. To bypass it, run:
> ```
> xattr -rd com.apple.quarantine /path/to/Wipe.app
> ```

## Folders monitored

| Folder | Safe to delete |
|---|---|
| DerivedData | Yes, Xcode rebuilds automatically |
| Xcode Archives | Yes, but you lose crash symbolication for old builds |
| iOS Simulators | Yes, Xcode re-downloads when needed |
| npm cache | Yes |
| Library/Caches | Yes |
| Android SDK | Yes, if you no longer develop for Android |
| Arduino | Yes, if you no longer use Arduino |
| Cursor | Yes, but resets all settings and extensions |
| Google Chrome | Yes, but deletes bookmarks, passwords and history |

## License

MIT
