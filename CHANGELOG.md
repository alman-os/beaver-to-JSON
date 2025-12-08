# Changelog

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
