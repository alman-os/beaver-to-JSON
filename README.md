# BeaverJSON

Build JSON Schemas for LLM structured-output prompts. macOS app, runs locally, no network calls.

You give it field names, types, and descriptions; it writes the JSON Schema you paste into Claude, GPT, Gemini, or whatever needs a strict response format. Save reusable shapes as presets so you stop rewriting the same five-prompt schema by hand.

**Latest release: v2.2 — bugfixes and library optimizations.** Download JSON now saves through a native dialog, with an output library at `~/Documents/AOS/BeaverToJSON/`. Full history in the [changelog](CHANGELOG.md).

## Table of Contents

- [What Does This Do](#what-does-this-do)
- [Installation](#installation)
- [Usage](#usage)
- [What Can You Do With This](#what-can-you-do-with-this)
- [Privacy](#privacy)
- [Tech Details](#tech-details)
- [Contributing](#contributing)
- [License](#license)

## What Does This Do

- Builds **JSON Schemas** with `type`, `title`, `properties`, `required`, and `additionalProperties: false` — the shape Claude / OpenAI / Gemini structured-output endpoints expect.
- **Form UI** for properties: name, primitive type, description. Add and remove rows as you go.
- **One-click export**: Generate → Copy to clipboard, or Download as `.json`.
- **Preset Manager** in a separate window — save the current form, reload it later, rename, delete. Stored as a single JSON file on disk so presets survive reinstalls.
- **Reset** button to clear the form between schemas without restarting the app.
- **Light / Dark** themes that remember themselves.
- **Local only.** No telemetry, no auth, no network calls. The Flask backend listens on `127.0.0.1` only.

## Installation

### Option A: Download the signed DMG (recommended)

1. Grab `BeaverToJSON_v2-2_macOS-silicon.dmg` from the latest [Release](https://github.com/alman-os/beaver-to-JSON/releases).
2. Open the DMG, drag `BeaverToJSON.app` to Applications.
3. Launch from Applications.

The DMG is signed with an Apple Developer ID and notarized by Apple, so it opens without the right-click dance. The product name in the UI is **BeaverJSON**; the `.app` file is `BeaverToJSON.app` — same thing.

**macOS:** 10.13 (High Sierra) or later.

**If you grabbed an unsigned build** (older release, or your own local build without `build_dmg.sh`): right-click the app → Open → Open in the dialog. Once only.

### Option B: Run from source

```
git clone https://github.com/alman-os/beaver-to-JSON.git
cd beaver-to-JSON
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

**Python 3.11+ required** (developed on 3.13). On Homebrew: `brew install python@3.13`.

### Option C: Build your own .app or DMG

```
source .venv/bin/activate
./build_macos_app.sh    # produces dist/BeaverToJSON.app
./build_dmg.sh          # sign + DMG + notarize (needs Apple Dev ID + notarytool profile)
```

Identity, team ID, notary profile, bundle ID, and DMG icon positions are all overridable via env vars — see the top of `build_dmg.sh`.

### Known setup gotchas

**`pip: command not found` after `source .venv/bin/activate`.** The venv's shebangs are stale — usually after moving the repo (e.g. out of iCloud sync) or copying from another machine. Recreate it:

```
rm -rf .venv && python3.13 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

**Port 5050 already in use.** Set a different port: `PORT=5060 python app.py`.

**Build script reports PyInstaller missing.** Activate the venv *before* running `./build_macos_app.sh` — the script uses `pip` from your `PATH`.

**Notarization rejected.** The most common cause is a stale `entitlements.plist` or unsigned nested binary. `xcrun notarytool log <submission-id> --keychain-profile <profile>` returns the per-file rejection list.

## Usage

### Quick start

1. Open the app.
2. Set **Schema title** — this becomes the `title` field in the output.
3. Click **+ Add property** for each field you want the LLM to return.
4. For each row: type a `name`, pick a `type` (`string`, `number`, `integer`, `boolean`, `array`, `object`), and write a `description`. The description is what the model reads to figure out what to put in that field — write it like an instruction.
5. Click **Generate**.
6. **Copy** to clipboard or **Download JSON**. That's the schema, ready to paste into your prompt config.

All properties in the output are marked required and `additionalProperties` is set to `false`. That's the strictest shape, which is what you want when you're going to parse the model's response.

### Saving and reusing presets

- Click **Presets** in the header — preset manager window opens.
- Type a name, click **Save preset**. The current form is captured.
- **Load** drops the saved form back into the main window. **Rename** and **Delete** also live here.
- The `?` icon next to "Saved presets" reveals where presets live on disk, with a **Reveal in Finder** shortcut. Presets are a plain JSON file you can copy between machines.

### Resetting

The **Reset** button (next to Download JSON) clears the form back to a single starter row. It asks once before nuking your work.

## What Can You Do With This

- **Constrain Claude / GPT / Gemini output** for any app that needs predictable JSON back — sales-call summarizers, content generators, RAG pipelines, agent tooling.
- **Standardize prompt shapes across a team** — design the schema once, save it as a preset, share `presets.json` with teammates.
- **Iterate on prompt design** without juggling escape characters in your IDE. Edit the form, regenerate, paste, repeat.
- **Generate test fixtures** for code that consumes structured LLM responses.

What it isn't: a full JSON Schema editor. It writes `type: object` schemas with required, primitive-typed properties — the 90% shape for structured output. If you need `oneOf`, conditional schemas, or deeply nested objects, write those by hand on top of what BeaverJSON gives you.

## Privacy

- Runs entirely on your Mac.
- Flask binds to `127.0.0.1` only — never reachable from your network.
- No analytics, no crash reporting, no auto-update phone-home.
- Presets are stored locally at `~/Library/Application Support/BeaverJSON/presets.json`. Nothing leaves the machine.

## Tech Details

- **Backend:** Flask 3 on `127.0.0.1:5050`, background thread.
- **Frontend:** Vanilla JS, no framework, no build step.
- **Window:** pywebview with native Cocoa WebKit via `pyobjc`. Two windows (main + preset manager) communicate over the pywebview JS-API bridge.
- **Packaging:** PyInstaller `.app` bundle, signed with Developer ID + hardened runtime, notarized by Apple.
- **Entry point:** [app.py](app.py). Preset storage in [presets.py](presets.py). Frontend in [templates/](templates) and [static/](static).
- **Build scripts:** [build_macos_app.sh](build_macos_app.sh) (.app), [build_dmg.sh](build_dmg.sh) (signed + notarized DMG).

## Contributing

PRs welcome for bug fixes and small QoL improvements. For larger ideas — new schema features, alternative export formats, Windows or Linux support — open an issue first so we can talk shape before you spend time.

When sending a PR:

- Keep the diff focused — one concern per PR.
- Match the existing JS style (vanilla, no build step).
- Include reproduction steps for bug fixes.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE.md). Free for personal, research, educational, and other noncommercial use. Commercial use requires a separate license — open an issue if that's your situation.
