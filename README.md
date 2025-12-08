# Beaver to JSON - macOS Desktop App

A Flask-based web application packaged as a native macOS desktop app with embedded browser.

## What This Is

This is a **local web application** that runs as a **native macOS app** with an embedded browser window. When users double-click the app, they get a clean desktop window showing your web interface - no external browser, no address bar, no distractions.

## Key Features

- **Native GUI Window**: Uses pywebview for embedded WebKit browser
- **Self-Contained**: Flask backend + web frontend in one .app file
- **Clean UX**: Just your app content, no browser chrome
- **Offline Ready**: Runs completely locally, no internet required
- **Easy Distribution**: Single .app file or .zip for sharing

## Quick Start

### 1. Development Setup
```bash
# Activate virtual environment
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the app locally
python app.py
# A GUI window will open with your app
```

### 2. Test the GUI
```bash
# Quick test to verify pywebview works
python test_gui.py
```

### 3. Build for Distribution
```bash
# Create the standalone .app
./build_macos_app.sh

# Output:
# - dist/BeaverToJSON.app
# - BeaverToJSON_macOS.zip (for distribution)
```

## How It Works

```
┌─────────────────────────────────────┐
│  BeaverToJSON.app                   │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   Native Window (pywebview)   │ │
│  │   ┌───────────────────────┐   │ │
│  │   │                       │   │ │
│  │   │   Your Web App UI     │   │ │
│  │   │   (Flask templates)   │   │ │
│  │   │                       │   │ │
│  │   └───────────────────────┘   │ │
│  │   Embedded WebKit Browser     │ │
│  └───────────────────────────────┘ │
│          ↕                          │
│  Flask Server (localhost:5050)     │
└─────────────────────────────────────┘
```

**When the app launches:**
1. Flask server starts in background thread
2. pywebview creates a native macOS window
3. Embedded browser loads `http://127.0.0.1:5050`
4. User sees your web interface in a clean desktop window

## User Experience

### What Users See:
- ✅ Double-click app icon
- ✅ Native window opens immediately
- ✅ Your web interface loads inside
- ✅ Clean, focused UI (no browser tabs/address bar)
- ✅ Close window to quit

### What Users DON'T See:
- ❌ No external browser opening
- ❌ No "localhost:5050" in address bar
- ❌ No browser chrome or navigation controls
- ❌ No confusion about what to do

## Project Structure

```
beaver-to-JSON/
├── app.py                    # Main Flask + pywebview app
├── requirements.txt          # Python dependencies
├── build_macos_app.sh       # Build script for .app
├── templates/
│   └── index.html           # Your web interface
├── static/
│   ├── app.js               # JavaScript
│   └── style.css            # Styles
└── dist/                    # Build output (created by script)
    └── BeaverToJSON.app
```

## Requirements

- macOS 10.13 or later
- Python 3.8+
- Dependencies:
  - Flask >= 3.0
  - pywebview >= 5.0 (with PyObjC)

## Documentation

- [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md) - Complete build guide
- [ICON_GUIDE.md](ICON_GUIDE.md) - How to create custom .icns icon
- [CHANGELOG.md](CHANGELOG.md) - Version history and changes

## Distribution

### For Developers:
```bash
./build_macos_app.sh
# Share BeaverToJSON_macOS.zip
```

### For End Users:
1. Download `BeaverToJSON_macOS.zip`
2. Extract the .zip file
3. Move `BeaverToJSON.app` to Applications folder
4. Right-click and select "Open" (first time only)
5. App window opens with the interface

## Customization

### Window Settings
Edit [app.py](app.py) line 95-105 to customize:
- Window title
- Default size (width/height)
- Minimum size
- Background color

### App Name & Icon
Edit [build_macos_app.sh](build_macos_app.sh):
- `APP_NAME` - Change application name
- `ICON_FILE` - Custom icon filename

## Troubleshooting

### GUI window doesn't open
```bash
# Test pywebview installation:
python test_gui.py
```

### Build fails
```bash
# Clean and rebuild:
rm -rf build dist *.spec
pip install --upgrade pyinstaller pywebview
./build_macos_app.sh
```

### "App can't be opened" on first launch
Users should:
1. Right-click the app
2. Select "Open"
3. Click "Open" in dialog
(macOS Gatekeeper security - only needed once)

## License

See [LICENSE](LICENSE)

---

**Made with Flask + pywebview + PyInstaller**
