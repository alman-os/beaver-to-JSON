import json
import os
import threading
from flask import Flask, render_template, request, Response
import webview
app = Flask(__name__)


@app.route("/")
def index():
    return render_template("index.html")


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



def start_flask_server(port):
    """Start Flask server in a separate thread"""
    app.run(host="127.0.0.1", port=port, debug=False, use_reloader=False)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5050"))
    url = f"http://127.0.0.1:{port}"

    # Start Flask server in background thread
    flask_thread = threading.Thread(target=start_flask_server, args=(port,), daemon=True)
    flask_thread.start()

    # Create GUI window with embedded browser
    # This opens a native app window that displays your web app
    window = webview.create_window(
        title="Beaver to JSON",
        url=url,
        width=1200,
        height=800,
        resizable=True,
        fullscreen=False,
        min_size=(800, 600),
        background_color='#FFFFFF',
        text_select=True
    )

    # Start the GUI - this will open the window with embedded browser
    # No external browser, no address bar, just your app in a clean window
    webview.start(debug=False)
