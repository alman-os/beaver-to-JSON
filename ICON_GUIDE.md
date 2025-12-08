# How to Create an .icns Icon File for macOS

## Quick Method (Using Online Tools)

1. Create or find a **1024x1024 PNG** image for your app icon
2. Use an online converter like:
   - https://cloudconvert.com/png-to-icns
   - https://anyconv.com/png-to-icns-converter/
3. Download the `.icns` file
4. Rename it to `icon.icns` and place it in the root of this repository

## Manual Method (Using macOS Built-in Tools)

### Step 1: Prepare Your Icon Image
- Create a **1024x1024 PNG** image
- Name it `icon.png`
- Place it in this directory

### Step 2: Create Icon Set
```bash
# Create iconset directory
mkdir icon.iconset

# Generate all required icon sizes
sips -z 16 16     icon.png --out icon.iconset/icon_16x16.png
sips -z 32 32     icon.png --out icon.iconset/icon_16x16@2x.png
sips -z 32 32     icon.png --out icon.iconset/icon_32x32.png
sips -z 64 64     icon.png --out icon.iconset/icon_32x32@2x.png
sips -z 128 128   icon.png --out icon.iconset/icon_128x128.png
sips -z 256 256   icon.png --out icon.iconset/icon_128x128@2x.png
sips -z 256 256   icon.png --out icon.iconset/icon_256x256.png
sips -z 512 512   icon.png --out icon.iconset/icon_256x256@2x.png
sips -z 512 512   icon.png --out icon.iconset/icon_512x512.png
sips -z 1024 1024 icon.png --out icon.iconset/icon_512x512@2x.png
```

### Step 3: Convert to .icns
```bash
# Convert iconset to icns
iconutil -c icns icon.iconset -o icon.icns

# Clean up
rm -rf icon.iconset
```

## Note
If you don't provide an `icon.icns` file, the build script will still work but your app will use the default Python icon.
