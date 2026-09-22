# Notch Timer

A minimal timer and stopwatch for macOS, built with SwiftUI and AppKit. Hover to reveal controls, make an adjustment, and move away to return to the compact notch.

![Notch Timer demo](docs/demo.gif)

## Features

- **One compact control strip** — adjust everything directly inside the notch.
- **Compact progress fill** — the timer fills green from left to right while running and turns red when stopped. The expanded strip stays black; a running stopwatch uses a solid green tint.
- **Timer and stopwatch** — quick presets or a custom duration from 1 second to 99:59.
- **Hover interaction** — controls stay open while you use them and collapse when you leave.
- **Drag to position** — move the compact notch or expanded strip anywhere on your displays; its position is saved.
- **Subtle animation** — smooth transitions with support for Reduce Motion.
- **Button feedback** — quiet macOS system sounds, with a separate **Button Sounds** toggle in the menu bar menu.
- **Completion sound** — optional audio alert, with duration and sound preferences saved between launches.
- **Native and local** — no dependencies, accounts, or network access; no Dock icon.

## Get started

Requires **macOS 14+** and a **Swift 6 toolchain** (Xcode or Command Line Tools).

```sh
git clone https://github.com/Samie-ub/notch-timer.git
cd notch-timer
bash scripts/build-app.sh
open "dist/Notch Timer.app"
```

The build script creates a locally signed app in `dist/`. For development, run `swift run` or open `Package.swift` in Xcode.

## Controls

| Action | How |
| --- | --- |
| Reveal controls | Hover over the notch or click the time |
| Start or pause | Click the play/pause button |
| Change duration | Click the time, then choose a preset or **Custom** |
| Apply custom time | Click the checkmark or press Return |
| Switch modes | Click the mode name and choose Timer or Stopwatch |
| Reset or toggle sound | Use the reset or speaker button |
| Collapse | Move away from the notch or press Escape |
| Move the notch | Click and drag the compact notch or expanded strip |
| Reset position | Choose **Reset Notch Position** from the menu bar icon |
| Quit | Use the timer icon in the menu bar |

Pause before changing mode or duration. Unapplied custom-time changes are discarded when the strip closes. Active timer sessions do not persist after quitting.

The notch starts centered on the primary display, below the camera cutout on Macs that have one. Drag it to reposition it; expansion and collapse keep your chosen position, with adjustments at screen edges to keep all controls visible. Adjust its dimensions and top spacing in [`NotchLayout`](Sources/NotchTimer/App.swift).

## Development

```sh
swift test --disable-sandbox
```

Timer logic lives in `Sources/TimerCore`; the macOS interface lives in `Sources/NotchTimer`. Tests cover timing, pause/resume, completion, mode changes, and formatting.
