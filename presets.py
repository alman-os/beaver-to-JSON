"""Disk-backed preset CRUD for BeaverJSON.

Presets are stored as a single JSON file at:
    ~/Library/Application Support/BeaverJSON/presets.json

File schema:
    {"presets": [
        {"id": "...", "name": "...", "created_at": "...",
         "updated_at": "...", "state": {...}}
    ]}
"""
import json
import os
import sys
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path


def _presets_dir() -> Path:
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    elif sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", Path.home()))
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "BeaverJSON"


PRESETS_DIR = _presets_dir()
PRESETS_FILE = PRESETS_DIR / "presets.json"

_lock = threading.Lock()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_dir() -> None:
    PRESETS_DIR.mkdir(parents=True, exist_ok=True)


def _read_raw() -> dict:
    if not PRESETS_FILE.exists():
        return {"presets": []}
    try:
        with PRESETS_FILE.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"presets": []}
    if not isinstance(data, dict) or not isinstance(data.get("presets"), list):
        return {"presets": []}
    return data


def _write_raw(data: dict) -> None:
    _ensure_dir()
    tmp = PRESETS_FILE.with_suffix(".json.tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, PRESETS_FILE)


def _summary(p: dict) -> dict:
    return {
        "id": p.get("id"),
        "name": p.get("name"),
        "created_at": p.get("created_at"),
        "updated_at": p.get("updated_at"),
    }


def list_summaries() -> list:
    with _lock:
        data = _read_raw()
    return [_summary(p) for p in data["presets"]]


def get_one(preset_id: str):
    with _lock:
        data = _read_raw()
    for p in data["presets"]:
        if p.get("id") == preset_id:
            return p
    return None


def save_one(name: str, state: dict) -> dict:
    name = (name or "").strip() or "Untitled preset"
    now = _now_iso()
    preset = {
        "id": str(uuid.uuid4()),
        "name": name,
        "created_at": now,
        "updated_at": now,
        "state": state or {},
    }
    with _lock:
        data = _read_raw()
        data["presets"].append(preset)
        _write_raw(data)
    return preset


def update_one(preset_id: str, name=None, state=None):
    with _lock:
        data = _read_raw()
        for p in data["presets"]:
            if p.get("id") == preset_id:
                if name is not None:
                    cleaned = name.strip()
                    if cleaned:
                        p["name"] = cleaned
                if state is not None:
                    p["state"] = state
                p["updated_at"] = _now_iso()
                _write_raw(data)
                return p
    return None


def delete_one(preset_id: str) -> bool:
    with _lock:
        data = _read_raw()
        before = len(data["presets"])
        data["presets"] = [p for p in data["presets"] if p.get("id") != preset_id]
        if len(data["presets"]) == before:
            return False
        _write_raw(data)
    return True
