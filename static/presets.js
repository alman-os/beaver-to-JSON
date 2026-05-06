document.addEventListener("DOMContentLoaded", () => {
  const nameInput = document.getElementById("new-preset-name");
  const saveBtn = document.getElementById("save-preset-btn");
  const refreshBtn = document.getElementById("refresh-btn");
  const listEl = document.getElementById("preset-list");
  const statusEl = document.getElementById("save-status");
  const themeToggle = document.getElementById("theme-toggle");
  const helpToggle = document.getElementById("help-toggle");
  const helpPanel = document.getElementById("help-panel");
  const helpPath = document.getElementById("help-path");
  const revealBtn = document.getElementById("reveal-btn");

  function applyTheme(theme) {
    const normalized = theme === "light" ? "light" : "dark";
    document.body.dataset.theme = normalized;
    try {
      localStorage.setItem("schemaMakerTheme", normalized);
    } catch (err) {
      // ignore
    }
    themeToggle.textContent = normalized === "dark" ? "Light mode" : "Dark mode";
  }

  function initTheme() {
    let stored = null;
    try {
      stored = localStorage.getItem("schemaMakerTheme");
    } catch (err) {
      stored = null;
    }
    applyTheme(stored || "dark");
  }

  themeToggle.addEventListener("click", () => {
    const current = document.body.dataset.theme || "dark";
    applyTheme(current === "dark" ? "light" : "dark");
  });

  function setStatus(msg, kind) {
    statusEl.textContent = msg || "";
    statusEl.dataset.kind = kind || "";
    if (msg) {
      setTimeout(() => {
        if (statusEl.textContent === msg) {
          statusEl.textContent = "";
          statusEl.dataset.kind = "";
        }
      }, 2500);
    }
  }

  async function getMainFormState() {
    if (window.pywebview && window.pywebview.api && window.pywebview.api.get_main_form_state) {
      return await window.pywebview.api.get_main_form_state();
    }
    return null;
  }

  async function applyPresetToMain(state) {
    if (window.pywebview && window.pywebview.api && window.pywebview.api.apply_preset_to_main) {
      return await window.pywebview.api.apply_preset_to_main(state);
    }
    return false;
  }

  async function closeSelf() {
    if (window.pywebview && window.pywebview.api && window.pywebview.api.close_preset_manager) {
      try {
        await window.pywebview.api.close_preset_manager();
      } catch (err) {
        // ignore
      }
    }
  }

  function formatDate(iso) {
    if (!iso) return "";
    try {
      const d = new Date(iso);
      return d.toLocaleString();
    } catch (err) {
      return iso;
    }
  }

  function renderList(items) {
    listEl.innerHTML = "";
    if (!items.length) {
      const p = document.createElement("p");
      p.className = "preset-empty";
      p.textContent = "No presets saved yet.";
      listEl.appendChild(p);
      return;
    }
    items.forEach((preset) => {
      const row = document.createElement("div");
      row.className = "preset-row";
      row.dataset.id = preset.id;

      const meta = document.createElement("div");
      meta.className = "preset-meta";
      const nameEl = document.createElement("div");
      nameEl.className = "preset-name";
      nameEl.textContent = preset.name;
      const tsEl = document.createElement("div");
      tsEl.className = "preset-ts";
      tsEl.textContent = "Updated " + formatDate(preset.updated_at);
      meta.appendChild(nameEl);
      meta.appendChild(tsEl);

      const actions = document.createElement("div");
      actions.className = "preset-actions";

      const loadBtn = document.createElement("button");
      loadBtn.type = "button";
      loadBtn.textContent = "Load";
      loadBtn.addEventListener("click", () => loadPreset(preset.id));

      const renameBtn = document.createElement("button");
      renameBtn.type = "button";
      renameBtn.className = "ghost";
      renameBtn.textContent = "Rename";
      renameBtn.addEventListener("click", () => renamePreset(preset));

      const deleteBtn = document.createElement("button");
      deleteBtn.type = "button";
      deleteBtn.className = "danger";
      deleteBtn.textContent = "Delete";
      deleteBtn.addEventListener("click", () => deletePreset(preset));

      actions.appendChild(loadBtn);
      actions.appendChild(renameBtn);
      actions.appendChild(deleteBtn);

      row.appendChild(meta);
      row.appendChild(actions);
      listEl.appendChild(row);
    });
  }

  async function refreshList() {
    try {
      const res = await fetch("/api/presets");
      const data = await res.json();
      renderList(data.presets || []);
    } catch (err) {
      listEl.innerHTML = "";
      const p = document.createElement("p");
      p.className = "preset-empty";
      p.textContent = "Failed to load presets.";
      listEl.appendChild(p);
    }
  }

  async function savePreset() {
    const name = nameInput.value.trim();
    if (!name) {
      setStatus("Give the preset a name first.", "error");
      nameInput.focus();
      return;
    }
    const state = await getMainFormState();
    if (!state) {
      setStatus("Couldn't read form state from main window.", "error");
      return;
    }
    try {
      const res = await fetch("/api/presets", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, state }),
      });
      if (!res.ok) throw new Error("save failed");
      nameInput.value = "";
      setStatus("Saved.", "ok");
      refreshList();
    } catch (err) {
      setStatus("Failed to save preset.", "error");
    }
  }

  async function loadPreset(id) {
    try {
      const res = await fetch("/api/presets/" + encodeURIComponent(id));
      if (!res.ok) throw new Error("not found");
      const preset = await res.json();
      const ok = await applyPresetToMain(preset.state || {});
      if (ok) {
        await closeSelf();
      } else {
        setStatus("Couldn't apply preset to main window.", "error");
      }
    } catch (err) {
      setStatus("Failed to load preset.", "error");
    }
  }

  async function renamePreset(preset) {
    const next = prompt("New name for this preset:", preset.name);
    if (next == null) return;
    const trimmed = next.trim();
    if (!trimmed || trimmed === preset.name) return;
    try {
      const res = await fetch("/api/presets/" + encodeURIComponent(preset.id), {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: trimmed }),
      });
      if (!res.ok) throw new Error("rename failed");
      refreshList();
    } catch (err) {
      setStatus("Failed to rename preset.", "error");
    }
  }

  async function deletePreset(preset) {
    if (!confirm(`Delete preset "${preset.name}"? This can't be undone.`)) return;
    try {
      const res = await fetch("/api/presets/" + encodeURIComponent(preset.id), {
        method: "DELETE",
      });
      if (!res.ok && res.status !== 204) throw new Error("delete failed");
      refreshList();
    } catch (err) {
      setStatus("Failed to delete preset.", "error");
    }
  }

  helpToggle.addEventListener("click", async () => {
    const open = !helpPanel.hasAttribute("hidden") ? false : true;
    if (open) {
      helpPanel.removeAttribute("hidden");
      helpToggle.setAttribute("aria-expanded", "true");
      try {
        if (window.pywebview && window.pywebview.api && window.pywebview.api.get_presets_path) {
          const path = await window.pywebview.api.get_presets_path();
          if (path) helpPath.textContent = path;
        }
      } catch (err) {
        // keep the default ~/Library/... text
      }
    } else {
      helpPanel.setAttribute("hidden", "");
      helpToggle.setAttribute("aria-expanded", "false");
    }
  });

  revealBtn.addEventListener("click", async () => {
    if (window.pywebview && window.pywebview.api && window.pywebview.api.reveal_presets_dir) {
      try {
        await window.pywebview.api.reveal_presets_dir();
      } catch (err) {
        setStatus("Couldn't open Finder.", "error");
      }
    } else {
      setStatus("Reveal only works inside the BeaverJSON app.", "error");
    }
  });

  saveBtn.addEventListener("click", savePreset);
  refreshBtn.addEventListener("click", refreshList);
  nameInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") savePreset();
  });

  initTheme();

  // pywebview's api is injected asynchronously; wait for it before first paint
  // so save/load can use the bridge immediately.
  if (window.pywebview && window.pywebview.api) {
    refreshList();
  } else {
    window.addEventListener("pywebviewready", refreshList, { once: true });
    setTimeout(refreshList, 400); // fallback for plain browser
  }
});
