# Changelog

## 2026-06-24 - Bugfixes and library optimizations (v2.2)

### Fixed
- **Download JSON now saves a file.** It used the browser `<a download>` trick, which WKWebView ignores — it navigated to the blob URL and dumped the raw schema into the window instead of saving. Download now goes through a native Save panel via the Python bridge.

### Added
- **Output library** — saved schemas default to `~/Documents/AOS/BeaverToJSON/` (created on demand; you can still save anywhere from the dialog).
- **Save-location label** under the generated schema showing where downloads go.
- **Open Library button** that opens the output folder in Finder.

## 2026-06-19 - Presets, Reset, and notarized distribution (v2.1)

### Added
- **Reset button** — clears the form back to a single starter row to begin a new schema. Confirms once before discarding work.
- **Preset Manager** — a separate native window to save the current form, then reload, rename, or delete presets. Presets are stored on disk at `~/Library/Application Support/BeaverJSON/presets.json` and survive reinstalls.
- **Presets help icon** — `?` next to "Saved presets" reveals the storage path with a Reveal-in-Finder shortcut.
- **`build_dmg.sh`** — one command to sign (Developer ID + hardened runtime), build a styled DMG, notarize via Apple, staple, and verify. Identity, team ID, notary profile, bundle ID, and DMG icon positions are all overridable via env vars.
- **`entitlements.plist`** — hardened-runtime exceptions (JIT, unsigned executable memory, dyld env vars, library-validation) that a PyInstaller-bundled Python app needs to pass notarization.

### Fixed
- **Shutdown hang after loading a preset** — the preset window's Load button destroyed its own window from inside the JS-API bridge call, leaving an orphaned WebKit reference that deadlocked Cocoa at quit. Destroy is now deferred off the bridge thread, and the preset window cascade-closes when the main window closes.

### Changed
- **License switched from MIT to PolyForm Noncommercial 1.0.0** for public release. Free for personal, research, educational, and noncommercial use; commercial use needs a separate license.
- **README rewritten** for public release — leads with the LLM structured-output use case, covers the three install paths, and surfaces setup gotchas up front.

### Distribution
- Releases now ship a **signed + notarized `BeaverToJSON.dmg`** that opens on other Macs without the right-click-to-open Gatekeeper workaround.

## 2025-12-08 - MAJOR: Embedded Browser GUI (v2.0)

### COMPLETE REDESIGN: Native Desktop App with Embedded Browser
**What Changed:**
- **BEFORE**: App opened system browser (Safari/Chrome) in a separate window
- **NOW**: App opens its own GUI window with embedded browser (like a native app!)

**The Solution:**
- Replaced `webbrowser` module with **pywebview**
- Creates a standalone desktop window with embedded WebKit browser
- Clean, focused UI - no address bar, no browser tabs, no distractions
- Just your app content in a native macOS window

**User Experience:**
1. User double-clicks `BeaverToJSON.app`
2. A native desktop window opens immediately
3. Your web interface loads inside that window
4. Looks and feels like a true native macOS application
5. Close the window = quit the app (simple!)

**Technical Details:**
- Uses macOS native WebKit via PyObjC
- Flask runs in background thread
- GUI window displays localhost:5050
- Window is resizable, min size 800x600, default 1200x800

**Files Modified:**
- [app.py](app.py): Complete rewrite of main section
  - Removed: `webbrowser`, `time` modules
  - Added: `webview` (pywebview)
  - Lines 80-109: New GUI window creation code
- [requirements.txt](requirements.txt): Added `pywebview>=5.0`
- [build_macos_app.sh](build_macos_app.sh): Added pywebview hidden imports
- [test_gui.py](test_gui.py): New test script to verify GUI works

**Testing:**
```bash
# Test the GUI before building:
python test_gui.py

# Build the app:
./build_macos_app.sh
```

---

## 2025-12-08 - Critical UX Fix (v1.0)

### FIXED: Auto-Browser Opening
**Problem Identified:**
- The app imported `webbrowser` but never used it
- When users double-clicked the .app, Flask started but no browser opened
- With `console=False` in PyInstaller config, there was no visible UI at all
- Users were left confused with no way to access the app

**Solution Implemented:**
- Added `open_browser()` function that opens the default browser after a 1.5s delay
- Browser opening runs in a separate daemon thread to not block Flask
- Now when the .app is launched:
  1. Flask server starts on `http://127.0.0.1:5050`
  2. Browser automatically opens after 1.5 seconds
  3. User immediately sees the web interface

**Files Modified:**
- [app.py](app.py) - Added threading to auto-open browser
  - Lines 3-4: Added `threading` and `time` imports
  - Lines 81-84: New `open_browser()` function
  - Line 94: Thread to automatically open browser when app starts

**Testing:**
Run `./test_app.sh` to verify the browser opens automatically.

## Initial Release

### Created Build System
- Bash script to package Flask app into macOS .app using PyInstaller
- Automatic icon support (.icns)
- ZIP distribution creation
- Complete documentation (BUILD_INSTRUCTIONS.md, ICON_GUIDE.md)
