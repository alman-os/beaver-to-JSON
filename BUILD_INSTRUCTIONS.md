# macOS App Build Instructions

## Prerequisites
- macOS operating system
- Python 3.x installed
- Virtual environment activated

## Quick Start

### 1. (Optional) Add Your Icon
- Create or obtain an `icon.icns` file
- Place it in the root directory of this project
- See [ICON_GUIDE.md](ICON_GUIDE.md) for help creating an .icns file
- If no icon is provided, the app will use the default Python icon

### 2. Run the Build Script
```bash
./build_macos_app.sh
```

### 3. What the Script Does
The script will automatically:
- ✓ Activate your virtual environment (if not already active)
- ✓ Install PyInstaller (if needed)
- ✓ Clean previous builds
- ✓ Generate a PyInstaller spec file configured for Flask
- ✓ Bundle your app with all templates and static files
- ✓ Include your icon (if provided)
- ✓ Create a standalone macOS .app
- ✓ Create a ZIP archive for distribution

## Output
After successful build, you'll find:
- **dist/BeaverToJSON.app** - The standalone macOS application
- **BeaverToJSON_macOS.zip** - ZIP archive ready for distribution

## Testing Your App
1. Navigate to the `dist` folder
2. Double-click `BeaverToJSON.app`
3. The app will start a local web server
4. Your default browser should open to `http://127.0.0.1:5050`

## Distribution
- Share the `BeaverToJSON_macOS.zip` file with others
- Users can extract and run the .app file
- **Note**: Users may need to right-click > Open the first time due to macOS Gatekeeper
- For production apps, consider code signing for a better user experience

## Troubleshooting

### "App can't be opened because it is from an unidentified developer"
Users should:
1. Right-click the app
2. Select "Open"
3. Click "Open" in the dialog

### Build fails with missing dependencies
Ensure all dependencies are installed:
```bash
pip install -r requirements.txt
pip install pyinstaller
```

### App doesn't start
Check the Console.app for error messages or run from terminal:
```bash
./dist/BeaverToJSON.app/Contents/MacOS/BeaverToJSON
```

## Customization
Edit [build_macos_app.sh](build_macos_app.sh) to customize:
- `APP_NAME` - Change the application name
- `ICON_FILE` - Use a different icon filename
- Info.plist settings in the spec file
