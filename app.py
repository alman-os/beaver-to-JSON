import json
import os
from flask import Flask, render_template, request, Response
import webbrowser
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



if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5050"))
    url = f"http://127.0.0.1:{port}"
    print(f"SchemaMaker Mini running at {url}")

    # debug=False so it behaves nicely once packaged
    # use_reloader=False to avoid forking issues in restricted environments
    app.run(host="127.0.0.1", port=port, debug=False, use_reloader=False)
