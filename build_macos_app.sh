#!/bin/bash

# ============================================
# macOS .app Builder for Flask Web Application
# Using PyInstaller
# ============================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="BeaverToJSON"
MAIN_SCRIPT="app.py"
ICON_FILE="icon.icns"  # Place your .icns file in the root directory
OUTPUT_DIR="dist"
BUILD_DIR="build"
SPEC_FILE="${APP_NAME}.spec"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  macOS App Builder for ${APP_NAME}${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Check if main script exists
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo -e "${RED}Error: ${MAIN_SCRIPT} not found!${NC}"
    exit 1
fi

# Check if virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo -e "${YELLOW}Warning: No virtual environment detected.${NC}"
    echo -e "${YELLOW}Attempting to activate .venv...${NC}"
    if [ -d ".venv" ]; then
        source .venv/bin/activate
        echo -e "${GREEN}Virtual environment activated.${NC}\n"
    else
        echo -e "${RED}Error: .venv directory not found. Please create a virtual environment.${NC}"
        exit 1
    fi
fi

# Install PyInstaller if not already installed
echo -e "${BLUE}Checking for PyInstaller...${NC}"
if ! python -c "import PyInstaller" 2>/dev/null; then
    echo -e "${YELLOW}PyInstaller not found. Installing...${NC}"
    pip install pyinstaller
    echo -e "${GREEN}PyInstaller installed successfully.${NC}\n"
else
    echo -e "${GREEN}PyInstaller already installed.${NC}\n"
fi

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR" "$OUTPUT_DIR" "$SPEC_FILE" 2>/dev/null || true
echo -e "${GREEN}Cleaned.${NC}\n"

# Check for icon file
ICON_OPTION=""
if [ -f "$ICON_FILE" ]; then
    echo -e "${GREEN}Icon file found: ${ICON_FILE}${NC}"
    ICON_OPTION="--icon=${ICON_FILE}"
else
    echo -e "${YELLOW}Warning: ${ICON_FILE} not found. App will use default icon.${NC}"
    echo -e "${YELLOW}To add a custom icon, place your .icns file as '${ICON_FILE}' in this directory.${NC}"
fi

echo ""

# Create PyInstaller spec file with proper Flask configuration
echo -e "${BLUE}Creating PyInstaller spec file...${NC}"

cat > "$SPEC_FILE" << 'SPECFILE'
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['app.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
    ],
    hiddenimports=[
        'flask',
        'werkzeug',
        'jinja2',
        'click',
        'itsdangerous',
        'markupsafe',
        'webview',
        'webview.platforms.cocoa',
        'webview.platforms',
        'webview.util',
        'webview.js',
        'webview.js.css',
        'Foundation',
        'WebKit',
        'AppKit',
        'objc',
        'PyObjCTools',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='BeaverToJSON',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,  # No console window on macOS
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
ICON_PLACEHOLDER
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='BeaverToJSON',
)

app = BUNDLE(
    coll,
    name='BeaverToJSON.app',
    icon=ICON_BUNDLE_PLACEHOLDER,
    bundle_identifier='com.beavertojson.app',
    info_plist={
        'CFBundleName': 'BeaverToJSON',
        'CFBundleDisplayName': 'Beaver to JSON',
        'CFBundleVersion': '2.2.0',
        'CFBundleShortVersionString': '2.2.0',
        'NSHighResolutionCapable': 'True',
    },
)
SPECFILE

# Update icon placeholders in spec file
if [ -n "$ICON_OPTION" ]; then
    sed -i '' "s|ICON_PLACEHOLDER|    icon='${ICON_FILE}',|g" "$SPEC_FILE"
    sed -i '' "s|ICON_BUNDLE_PLACEHOLDER|'${ICON_FILE}'|g" "$SPEC_FILE"
else
    sed -i '' "s|ICON_PLACEHOLDER||g" "$SPEC_FILE"
    sed -i '' "s|ICON_BUNDLE_PLACEHOLDER|None|g" "$SPEC_FILE"
fi

echo -e "${GREEN}Spec file created: ${SPEC_FILE}${NC}\n"

# Build the app
echo -e "${BLUE}Building macOS application...${NC}"
echo -e "${YELLOW}This may take a few minutes...${NC}\n"

pyinstaller --clean --noconfirm "$SPEC_FILE"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Build Successful!${NC}"
    echo -e "${GREEN}========================================${NC}\n"

    APP_PATH="${OUTPUT_DIR}/${APP_NAME}.app"

    if [ -d "$APP_PATH" ]; then
        echo -e "${GREEN}Application created at:${NC}"
        echo -e "${BLUE}${APP_PATH}${NC}\n"

        # Get app size
        APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
        echo -e "${BLUE}App size: ${APP_SIZE}${NC}\n"

        # Create a ZIP archive
        echo -e "${BLUE}Creating ZIP archive...${NC}"
        ZIP_NAME="${APP_NAME}_macOS.zip"
        cd "$OUTPUT_DIR"
        zip -r -q "../${ZIP_NAME}" "${APP_NAME}.app"
        cd ..

        if [ -f "$ZIP_NAME" ]; then
            ZIP_SIZE=$(du -sh "$ZIP_NAME" | cut -f1)
            echo -e "${GREEN}ZIP archive created:${NC}"
            echo -e "${BLUE}${ZIP_NAME} (${ZIP_SIZE})${NC}\n"
        fi

        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Next Steps:${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "1. Test the app: Open ${APP_PATH}"
        echo -e "2. The app will start a local server at http://127.0.0.1:5050"
        echo -e "3. Distribute: Share ${ZIP_NAME}"
        echo -e "\n${YELLOW}Note: Users may need to allow the app in System Preferences > Security & Privacy${NC}"
        echo -e "${YELLOW}if it's from an unidentified developer.${NC}\n"

    else
        echo -e "${RED}Error: Application not found at expected location${NC}"
        exit 1
    fi
else
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}  Build Failed!${NC}"
    echo -e "${RED}========================================${NC}\n"
    exit 1
fi
