## Build

- Script: run [scripts/build_release.sh](scripts/build_release.sh) to build a Release app.
- Make: run `make release` from the repo root.
- Output: the app is written to `/Users/ken/knyc-dev/displaymodemenu/build/Release/DisplayModeMenu.app`.

Example:

```bash
./scripts/build_release.sh
# or
make release
```

# DisplayModeMenu

A lightweight macOS menu bar app for switching display resolutions, with Shortcuts integration. Requires macOS 13+ (Ventura or later).

- Favorites pinned at the top: 2560×1440@60 HiDPI and 1920×1080@60 HiDPI for each display
- Per-display submenus under “All Modes”; shows all modes ≥60Hz and respects the low-resolution toggle
- Low Resolution toggle (⌘L) to include non-HiDPI modes; off by default
- Hides all modes below 60Hz
- Integrates with Shortcuts to set a display mode like `1920x1080@60`
- Auto-refreshes on display hot-plug/unplug

> Tip: System Settings > Displays can also list resolutions (Advanced → "Show resolutions as list").

## Build & Run

- Open `displaymodemenu.xcodeproj` in Xcode
- Select the `DisplayModeMenu` scheme
- Run (⌘R)

The app runs as a background (LSUIElement) menu bar app.

## Using the Menu

- Click the 🖥️ icon in the menu bar
- Favorites section (per display):
  - ☆ 2560×1440@60 HiDPI
  - ☆ 1920×1080@60 HiDPI
- All Modes: each display has a submenu listing all modes ≥60Hz
- Low Resolution toggle (⌘L): when on, non-HiDPI variants appear in All Modes (favorites remain HiDPI)
- Current mode is checkmarked

## Shortcuts Integration

The app registers a "Set Display Mode" shortcut.

Parameters:
- Resolution: `WIDTHxHEIGHT` or `WIDTHxHEIGHT@REFRESH`, e.g. `1920x1080@60`
- Display Name (optional): disambiguated name like `LG HDR 4K-0`

Examples:
```
Resolution: 1920x1080@60
Display Name: (empty → main display)
```
```
Resolution: 2560x1440@60
Display Name: DELL U2723QE-0
```

## Notes on Mode Listing

- Favorites (per display): 2560×1440@60 HiDPI, 1920×1080@60 HiDPI
- All Modes submenu: all modes ≥60Hz; includes non-HiDPI only when Low Resolution is enabled
- Current mode is always shown (and checkmarked)

## Credits / Origin

- Conceptual reference: `displaymode` by p00ya (Apache 2.0) — used as inspiration only; this app is a clean, independent implementation focused on a menu bar/Shortcuts experience.
- Modern menu bar app and Shortcuts integration authored for this project.

## License

- Licensed under Apache 2.0. See `LICENSE.txt`.
- Copyright 2025 Ken Ng.
