import json
import os
import subprocess
import sys
import threading
from flask import Flask, render_template, request, Response, jsonify, abort
import webview

import presets

app = Flask(__name__)

main_window = None
preset_window = None
_window_lock = threading.Lock()


def _defer_destroy(window, delay=0.05):
    """Destroy a pywebview window from a fresh thread.

    Why: when destroy() is called synchronously inside a JS-API bridge
    call, the bridge thread is still tied to that window's WebKit engine.
    Tearing the window down underneath itself leaves an orphan reference
    that deadlocks Cocoa at app quit. Spawning a thread lets the bridge
    call return first, then the window is closed cleanly.
    """
    def _run():
        import time
        if delay:
            time.sleep(delay)
        try:
            window.destroy()
        except Exception:
            pass
    threading.Thread(target=_run, daemon=True).start()


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/presets")
def presets_page():
    return render_template("presets.html")


@app.post("/generate_schema")
def generate_schema():
    """
    Expect JSON like:
    {
      "title": "response_schema",
      "properties": [
        {"name": "Prompt_1", "type": "string",
         "description": "Analyze KPIs", "required": true},
        ...
      ]
    }
    """
    data = request.get_json(force=True) or {}

    title = (data.get("title") or "response_schema").strip() or "response_schema"
    props = data.get("properties", [])
    properties = {}
    required = []

    for p in props:
        name = (p.get("name") or "").strip()
        if not name:
            continue

        prop_type = (p.get("type") or "string").strip().lower()
        # basic safety: only allow standard JSON Schema primitive types
        if prop_type not in {"string", "number", "integer", "boolean", "array", "object"}:
            prop_type = "string"

        description = (p.get("description") or "").strip()

        prop_schema = {"type": prop_type}
        if description:
            prop_schema["description"] = description

        properties[name] = prop_schema
        # All properties are required by design.
        required.append(name)

    schema = {
        "type": "object",
        "title": title,
        "properties": properties,
        "additionalProperties": False,
    }
    if required:
        schema["required"] = required

    ordered_schema = {
        "title": schema["title"],
        "type": "object",
        "properties": schema["properties"],
    }
    # Only include required when present so empty arrays don't show up
    if "required" in schema:
        ordered_schema["required"] = schema["required"]
    ordered_schema["additionalProperties"] = False

    return Response(
        json.dumps({"schema": ordered_schema}, indent=2),
        mimetype="application/json",
    )


@app.get("/api/presets")
def api_list_presets():
    return jsonify({"presets": presets.list_summaries()})


@app.get("/api/presets/<preset_id>")
def api_get_preset(preset_id):
    p = presets.get_one(preset_id)
    if p is None:
        abort(404)
    return jsonify(p)


@app.post("/api/presets")
def api_create_preset():
    data = request.get_json(force=True) or {}
    name = data.get("name") or ""
    state = data.get("state") or {}
    return jsonify(presets.save_one(name, state)), 201


@app.put("/api/presets/<preset_id>")
def api_update_preset(preset_id):
    data = request.get_json(force=True) or {}
    p = presets.update_one(
        preset_id,
        name=data.get("name"),
        state=data.get("state"),
    )
    if p is None:
        abort(404)
    return jsonify(p)


@app.delete("/api/presets/<preset_id>")
def api_delete_preset(preset_id):
    if not presets.delete_one(preset_id):
        abort(404)
    return ("", 204)


class Bridge:
    """JS-callable bridge exposed to both pywebview windows."""

    def __init__(self, base_url):
        self.base_url = base_url

    def get_main_form_state(self):
        if main_window is None:
            return None
        try:
            return main_window.evaluate_js("window.getFormState && window.getFormState()")
        except Exception:
            return None

    def apply_preset_to_main(self, state):
        if main_window is None:
            return False
        payload = json.dumps(state or {})
        try:
            main_window.evaluate_js(
                f"window.setFormState && window.setFormState({payload})"
            )
            return True
        except Exception:
            return False

    def open_preset_manager(self):
        global preset_window
        with _window_lock:
            if preset_window is not None:
                try:
                    # Bring existing window forward; pywebview lacks a true "focus",
                    # so re-show as fallback.
                    preset_window.show()
                except Exception:
                    pass
                return True
            window = webview.create_window(
                title="BeaverJSON · Presets",
                url=f"{self.base_url}/presets",
                width=720,
                height=620,
                resizable=True,
                min_size=(560, 460),
                background_color="#FFFFFF",
                text_select=True,
                js_api=self,
            )
            preset_window = window

        def _on_closed():
            global preset_window
            with _window_lock:
                preset_window = None

        try:
            window.events.closed += _on_closed
        except Exception:
            pass
        return True

    def get_presets_path(self):
        return str(presets.PRESETS_FILE)

    def reveal_presets_dir(self):
        path = presets.PRESETS_DIR
        try:
            path.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(path)], check=False)
            elif sys.platform.startswith("win"):
                os.startfile(str(path))  # type: ignore[attr-defined]
            else:
                subprocess.run(["xdg-open", str(path)], check=False)
            return True
        except Exception:
            return False

    def close_preset_manager(self):
        global preset_window
        with _window_lock:
            target = preset_window
            preset_window = None
        if target is not None:
            _defer_destroy(target)
        return True


def start_flask_server(port):
    """Start Flask server in a separate thread"""
    app.run(host="127.0.0.1", port=port, debug=False, use_reloader=False)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5050"))
    url = f"http://127.0.0.1:{port}"

    # Start Flask server in background thread
    flask_thread = threading.Thread(target=start_flask_server, args=(port,), daemon=True)
    flask_thread.start()

    bridge = Bridge(url)

    # Create GUI window with embedded browser
    main_window = webview.create_window(
        title="Beaver to JSON",
        url=url,
        width=1200,
        height=800,
        resizable=True,
        fullscreen=False,
        min_size=(800, 600),
        background_color='#FFFFFF',
        text_select=True,
        js_api=bridge,
    )

    def _on_main_closed():
        global preset_window
        with _window_lock:
            target = preset_window
            preset_window = None
        if target is not None:
            try:
                target.destroy()
            except Exception:
                pass

    try:
        main_window.events.closed += _on_main_closed
    except Exception:
        pass

    # Start the GUI - this will open the window with embedded browser
    # No external browser, no address bar, just your app in a clean window
    webview.start(debug=False)
