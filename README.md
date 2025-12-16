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

- Shows only useful modes by default: 1920×1080 @ 60Hz (HiDPI) and 2560×1440 @ 60Hz (HiDPI)
- Hides all modes below 60Hz
- Toggle "Show All Modes" (⌘A) to see every available mode
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
- For each display, you'll see:
  - Current mode (✓)
  - By default: 1920×1080 @ 60Hz (HiDPI) and 2560×1440 @ 60Hz (HiDPI)
  - No low-resolution entries and nothing under 60Hz
  - Enable "Show All Modes" (⌘A) to see everything supported and above 60Hz

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

- The app queries all display modes and filters for clarity
- Default list only shows HiDPI 1080p/1440p at ≥ 60Hz
- "Show All Modes" reveals every available mode that's ≥ 60Hz

## Credits / Origin

This project is a fork and substantial rework of the excellent `displaymode` by p00ya:
- Original repository: https://github.com/p00ya/displaymode
- The original adds a CLI utility for macOS (10.6+). This repo focuses on a modern menu bar app with Shortcuts. Some ideas and constants were informed by the original project. License retained in `LICENSE.txt`.

## License

See `LICENSE.txt`.
