document.addEventListener("DOMContentLoaded", () => {
  const propertiesContainer = document.getElementById("properties-container");
  const addPropertyBtn = document.getElementById("add-property-btn");
  const generateBtn = document.getElementById("generate-btn");
  const copyBtn = document.getElementById("copy-btn");
  const downloadBtn = document.getElementById("download-btn");
  const resetBtn = document.getElementById("reset-btn");
  const presetsBtn = document.getElementById("presets-btn");
  const openLibraryBtn = document.getElementById("open-library-btn");
  const themeToggle = document.getElementById("theme-toggle");
  const outputEl = document.getElementById("schema-output");
  const titleInput = document.getElementById("schema-title");
  const initialOutputText = outputEl.textContent;
  let propCounter = 0;
  let lastSchemaText = outputEl.textContent.trim();

  function applyTheme(theme) {
    const normalized = theme === "light" ? "light" : "dark";
    document.body.dataset.theme = normalized;
    try {
      localStorage.setItem("schemaMakerTheme", normalized);
    } catch (err) {
      // ignore storage issues (private mode, etc.)
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

  function createPropertyRow(initial = {}) {
    propCounter += 1;
    const row = document.createElement("div");
    row.className = "property-row";
    row.dataset.id = String(propCounter);

    row.innerHTML = `
      <div>
        <div class="tiny-label">Name</div>
        <input type="text" class="prop-name" placeholder="Prompt_1"
               value="${initial.name || ""}">
      </div>
      <div>
        <div class="tiny-label">Type</div>
        <select class="prop-type">
          <option value="string">string</option>
          <option value="number">number</option>
          <option value="integer">integer</option>
          <option value="boolean">boolean</option>
          <option value="array">array</option>
          <option value="object">object</option>
        </select>
      </div>
      <div>
        <div class="tiny-label">Description</div>
        <input type="text" class="prop-description"
               placeholder="Explain this field's purpose"
               value="${initial.description || ""}">
      </div>
      <div class="action-cell">
        <button type="button" class="remove-btn">✕</button>
      </div>
    `;

    // Set type if provided
    if (initial.type) {
      row.querySelector(".prop-type").value = initial.type;
    }

    row.querySelector(".remove-btn").addEventListener("click", () => {
      row.remove();
    });

    propertiesContainer.appendChild(row);
  }

  addPropertyBtn.addEventListener("click", () => {
    createPropertyRow();
  });

  generateBtn.addEventListener("click", async () => {
    const title = titleInput.value.trim() || "response_schema";

    const rows = Array.from(
      propertiesContainer.querySelectorAll(".property-row"),
    );
    const props = [];

    for (const row of rows) {
      const name = row.querySelector(".prop-name").value.trim();
      const type = row.querySelector(".prop-type").value;
      const description = row.querySelector(".prop-description").value.trim();

      if (!name) continue;

      props.push({ name, type, description, required: true });
    }

    const payload = { title, properties: props };

    try {
      const res = await fetch("/generate_schema", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        throw new Error("Request failed");
      }

      const data = await res.json();
      const schema = data.schema || data;

      const pretty = JSON.stringify(schema, null, 2);
      outputEl.textContent = pretty;
      lastSchemaText = pretty;
    } catch (err) {
      outputEl.textContent =
        "// Error while generating schema:\n// " + String(err);
      lastSchemaText = "";
    }
  });

  copyBtn.addEventListener("click", async () => {
    const text = outputEl.textContent.trim();
    if (!text) return;

    try {
      await navigator.clipboard.writeText(text);
      copyBtn.textContent = "Copied!";
      setTimeout(() => {
        copyBtn.textContent = "Copy";
      }, 1200);
    } catch (err) {
      console.error("Copy failed", err);
    }
  });

  function flashDownload(label) {
    downloadBtn.textContent = label;
    setTimeout(() => {
      downloadBtn.textContent = "Download JSON";
    }, 1400);
  }

  downloadBtn.addEventListener("click", async () => {
    const text = outputEl.textContent.trim();
    if (!text || text === initialOutputText.trim()) return;

    const filename = (titleInput.value.trim() || "response_schema") + ".json";

    // In the app, save through the Python bridge — WKWebView won't honor
    // the <a download> trick and would just navigate to the blob URL.
    if (window.pywebview && window.pywebview.api && window.pywebview.api.save_json) {
      try {
        const res = await window.pywebview.api.save_json(filename, text);
        if (res && res.ok) {
          flashDownload("Saved!");
        } else if (res && res.cancelled) {
          // user dismissed the dialog — no feedback needed
        } else {
          flashDownload("Save failed");
        }
      } catch (err) {
        console.error("Save failed", err);
        flashDownload("Save failed");
      }
      return;
    }

    // Fallback for running in a plain browser during development.
    const blob = new Blob([text], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  if (openLibraryBtn) {
    openLibraryBtn.addEventListener("click", async () => {
      if (window.pywebview && window.pywebview.api && window.pywebview.api.open_library) {
        try {
          await window.pywebview.api.open_library();
        } catch (err) {
          console.error("Open library failed", err);
        }
      }
    });
  }

  function getFormState() {
    const rows = Array.from(
      propertiesContainer.querySelectorAll(".property-row"),
    );
    const properties = rows.map((row) => ({
      name: row.querySelector(".prop-name").value,
      type: row.querySelector(".prop-type").value,
      description: row.querySelector(".prop-description").value,
    }));
    return { title: titleInput.value, properties };
  }

  function setFormState(state) {
    const safe = state || {};
    titleInput.value = safe.title || "";
    propertiesContainer.innerHTML = "";
    propCounter = 0;
    const props = Array.isArray(safe.properties) ? safe.properties : [];
    if (props.length === 0) {
      createPropertyRow();
    } else {
      props.forEach((p) => createPropertyRow(p || {}));
    }
    outputEl.textContent = initialOutputText;
    lastSchemaText = "";
  }

  window.getFormState = getFormState;
  window.setFormState = setFormState;

  resetBtn.addEventListener("click", () => {
    if (!confirm("Clear the current form and start fresh?")) return;
    setFormState({
      title: "",
      properties: [
        {
          name: "Prompt_1",
          type: "string",
          description: "Main instruction for the model.",
        },
      ],
    });
  });

  presetsBtn.addEventListener("click", async () => {
    if (window.pywebview && window.pywebview.api && window.pywebview.api.open_preset_manager) {
      try {
        await window.pywebview.api.open_preset_manager();
      } catch (err) {
        console.error("Failed to open preset manager", err);
      }
    } else {
      window.open("/presets", "_blank");
    }
  });

  themeToggle.addEventListener("click", () => {
    const current = document.body.dataset.theme || "dark";
    applyTheme(current === "dark" ? "light" : "dark");
  });

  // Seed with one starter row to avoid empty screen
  createPropertyRow({
    name: "Prompt_1",
    type: "string",
    description: "Main instruction for the model.",
    required: true,
  });

  initTheme();
});
