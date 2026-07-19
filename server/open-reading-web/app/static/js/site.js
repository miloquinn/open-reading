(() => {
  const toggle = document.querySelector("[data-nav-toggle]");
  const nav = document.querySelector("[data-nav]");

  if (toggle && nav) {
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
  }

  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy || "");
        const oldText = button.textContent;
        button.textContent = "已复制";
        setTimeout(() => {
          button.textContent = oldText;
        }, 1500);
      } catch {
        button.textContent = "复制失败";
      }
    });
  });

  const dropzone = document.querySelector("[data-dropzone]");
  const fileInput = document.querySelector("[data-file-input]");
  const fileName = document.querySelector("[data-file-name]");

  function formatBytes(bytes) {
    if (!bytes) return "0 B";
    const units = ["B", "KiB", "MiB", "GiB"];
    const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), 3);
    return `${(bytes / 1024 ** index).toFixed(index ? 1 : 0)} ${units[index]}`;
  }

  function showFile() {
    const selected = fileInput?.files?.[0];
    if (selected && fileName) {
      fileName.textContent = `${selected.name} · ${formatBytes(selected.size)}`;
    }
  }

  if (dropzone && fileInput) {
    ["dragenter", "dragover"].forEach((eventName) => {
      dropzone.addEventListener(eventName, (event) => {
        event.preventDefault();
        dropzone.classList.add("dragover");
      });
    });
    ["dragleave", "drop"].forEach((eventName) => {
      dropzone.addEventListener(eventName, (event) => {
        event.preventDefault();
        dropzone.classList.remove("dragover");
      });
    });
    dropzone.addEventListener("drop", (event) => {
      if (event.dataTransfer?.files?.length) {
        fileInput.files = event.dataTransfer.files;
        showFile();
      }
    });
    fileInput.addEventListener("change", showFile);
  }

  function escapeHtml(value) {
    const node = document.createElement("span");
    node.textContent = value;
    return node.innerHTML;
  }

  function updateOptions(selector, json) {
    const select = document.querySelector(selector);
    if (!select) return;
    try {
      const values = JSON.parse(json || "[]");
      if (values.length) {
        select.innerHTML = values
          .map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`)
          .join("");
      }
    } catch {
      // Server validation remains authoritative if configuration JSON is malformed.
    }
  }

  document.querySelectorAll("[data-platform]").forEach((radio) => {
    radio.addEventListener("change", () => {
      if (!radio.checked) return;
      updateOptions("[data-package-select]", radio.dataset.packageTypes);
      updateOptions("[data-arch-select]", radio.dataset.architectures);
    });
  });

  const uploadForm = document.querySelector("[data-upload-form]");
  if (uploadForm) {
    uploadForm.addEventListener("submit", () => {
      const submit = uploadForm.querySelector("[data-submit]");
      const progress = uploadForm.querySelector("[data-progress]");
      if (submit) {
        submit.disabled = true;
        submit.textContent = "正在发布…";
      }
      if (progress) progress.hidden = false;
    });
  }
})();
