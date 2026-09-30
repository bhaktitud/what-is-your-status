const LEGACY_STORAGE_KEY = "work-queue.tasks.v1";
const LANES = {
  action: { label: "Perlu gue gerakkan", className: "status-action" },
  external: { label: "Nunggu pihak luar", className: "status-external" },
  internal: { label: "Nunggu internal", className: "status-internal" },
  blocked: { label: "Terhambat", className: "status-blocked" },
  done: { label: "Selesai", className: "status-done" },
};

const queueContent = document.querySelector("#queue-content");
const taskDialog = document.querySelector("#task-dialog");
const taskForm = document.querySelector("#task-form");
const taskFormError = document.querySelector("#task-form-error");
const personDialog = document.querySelector("#person-dialog");
const personForm = document.querySelector("#person-form");
const personFormError = document.querySelector("#person-form-error");
const detailDialog = document.querySelector("#detail-dialog");
const detailContent = document.querySelector("#detail-content");
const searchInput = document.querySelector("#search-input");
const saveStatus = document.querySelector("#save-status");
const storageLabel = document.querySelector("#storage-label");
const storageMark = document.querySelector("#storage-mark");
const toast = document.querySelector("#toast");

let tasks = [];
let people = [];
let currentFilter = "all";
let query = "";
let storageError = "";
let activeTaskId = "";
let toastTimeout;

function setStorageState(label, state) {
  storageLabel.textContent = label;
  storageMark.dataset.state = state;
}

function localDateValue(date = new Date()) {
  const adjusted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return adjusted.toISOString().slice(0, 10);
}

function formatDate(value, options = { day: "numeric", month: "short", year: "numeric" }) {
  if (!value) return "Belum diatur";
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return "Tanggal tidak valid";
  return new Intl.DateTimeFormat("id-ID", options).format(date);
}

function escapeHTML(value) {
  return String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]);
}

function createId() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `task-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function validateTasks(value) {
  if (!Array.isArray(value)) throw new Error("Data task bukan berupa daftar.");
  const validLanes = new Set(Object.keys(LANES));
  const validTasks = value.every((task) => (
    task
    && typeof task.id === "string"
    && typeof task.title === "string"
    && typeof task.project === "string"
    && typeof task.owner === "string"
    && typeof task.nextAction === "string"
    && typeof task.followUpAt === "string"
    && validLanes.has(task.lane)
    && Array.isArray(task.events)
    && task.events.every((event) => (
      event
      && typeof event.note === "string"
      && typeof event.date === "string"
    ))
  ));
  if (!validTasks) throw new Error("Sebagian data task tidak bisa dibaca.");
  return value;
}

function validatePeople(value) {
  if (!Array.isArray(value) || !value.every((person) => (
    person
    && typeof person.id === "string"
    && typeof person.name === "string"
  ))) {
    throw new Error("Daftar orang dari SQLite tidak bisa dibaca.");
  }
  return value;
}

async function requestJSON(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...options.headers,
    },
  });
  if (response.status === 204) return null;
  let result;
  try {
    result = await response.json();
  } catch {
    throw new Error("Server lokal tidak memberi respons JSON. Jalankan ulang dengan python3 server.py.");
  }
  if (!response.ok) {
    const error = new Error(result?.error || `Request gagal (${response.status}).`);
    error.status = response.status;
    throw error;
  }
  return result;
}

function showStorageFailure(error) {
  const detail = error instanceof Error ? error.message : "Database SQLite tidak bisa diakses.";
  storageError = detail;
  saveStatus.textContent = "Database bermasalah";
  setStorageState("Database bermasalah", "error");
}

function showStorageReady(message = "Perubahan tersimpan") {
  storageError = "";
  saveStatus.textContent = message;
  setStorageState("Database SQLite aktif", "saved");
}

async function readTasks() {
  queueContent.setAttribute("aria-busy", "true");
  queueContent.innerHTML = '<div class="loading-state"><p>Memuat task dari SQLite...</p></div>';
  saveStatus.textContent = "Menghubungkan ke SQLite...";
  setStorageState("Menghubungkan ke database...", "loading");
  try {
    const result = await requestJSON("/api/tasks");
    tasks = validateTasks(result.tasks);
    if (!tasks.length) {
      let legacyWarning = "";
      try {
        const legacyData = localStorage.getItem(LEGACY_STORAGE_KEY);
        if (legacyData !== null) {
          const legacyTasks = validateTasks(JSON.parse(legacyData));
          if (legacyTasks.length) {
            const imported = await requestJSON("/api/tasks/import", {
              method: "POST",
              body: JSON.stringify({ tasks: legacyTasks }),
            });
            tasks = validateTasks(imported.tasks);
            try {
              localStorage.removeItem(LEGACY_STORAGE_KEY);
            } catch {
              legacyWarning = "Data lama berhasil disalin, tetapi salinan browser tidak bisa dibersihkan.";
            }
          }
        }
      } catch (error) {
        legacyWarning = `Data lama dari browser belum diimpor: ${error.message}`;
      }
      if (legacyWarning) showToast(legacyWarning, true);
      else if (tasks.length) showToast("Task dari browser berhasil dipindahkan ke SQLite.");
    }
    const peopleResult = await requestJSON("/api/people");
    people = validatePeople(peopleResult.people);
    showStorageReady("Database SQLite aktif");
    render();
    renderOwnerOptions(taskForm.elements.id.value
      ? taskForm.elements.owner.value
      : "Gue");
    renderPeopleList();
  } catch (error) {
    showStorageFailure(error);
    render();
  }
}

function renderOwnerOptions(selectedName = "") {
    const options = people.map((person) => `
      <option value="${escapeHTML(person.name)}">${escapeHTML(person.name)}</option>
    `).join("");
    taskForm.elements.owner.innerHTML = `
      <option value="">Pilih orang</option>
      ${options}
    `;
    taskForm.elements.owner.value = people.some((person) => person.name === selectedName)
      ? selectedName
      : "";
}

function renderPeopleList() {
    const peopleList = document.querySelector("#people-list");
    peopleList.innerHTML = people.length
      ? people.map((person) => `<li>${escapeHTML(person.name)}</li>`).join("")
      : '<li class="people-empty">Belum ada orang tersimpan.</li>';
}

function openPersonDialog() {
    personForm.reset();
    personFormError.textContent = "";
    renderPeopleList();
    personDialog.showModal();
    personForm.elements.name.focus();
}

async function handlePersonSubmit(event) {
    event.preventDefault();
    personFormError.textContent = "";
    const name = personForm.elements.name.value.trim().replace(/\s+/g, " ");
    if (!name) {
      personFormError.textContent = "Nama orang harus diisi.";
      return;
    }

    const submitButton = personForm.querySelector('[type="submit"]');
    submitButton.disabled = true;
    try {
      const result = await requestJSON("/api/people", {
        method: "POST",
        body: JSON.stringify({ name }),
      });
      people = [...people, result.person].sort((a, b) => a.name.localeCompare(b.name, "id"));
      renderOwnerOptions(result.person.name);
      renderPeopleList();
      showStorageReady();
      personDialog.close();
      taskForm.elements.owner.focus();
      showToast(`${result.person.name} ditambahkan ke daftar orang.`);
    } catch (error) {
      personFormError.textContent = error instanceof Error ? error.message : "Orang belum tersimpan.";
      if (!Number.isInteger(error?.status) || error.status >= 500) showStorageFailure(error);
      personForm.elements.name.focus();
    } finally {
      submitButton.disabled = false;
  }
}

function getCounts() {
  const active = tasks.filter((task) => task.lane !== "done");
  return {
    all: tasks.length,
    action: active.filter((task) => task.lane === "action").length,
    waiting: active.filter((task) => task.lane === "external" || task.lane === "internal").length,
    "no-followup": active.filter((task) => !task.followUpAt).length,
    blocked: active.filter((task) => task.lane === "blocked").length,
  };
}

function updateCounts() {
  const counts = getCounts();
  document.querySelectorAll("[data-count]").forEach((element) => {
    element.textContent = counts[element.dataset.count] ?? 0;
  });
  document.querySelectorAll("[data-summary]").forEach((element) => {
    element.textContent = counts[element.dataset.summary] ?? 0;
  });
  document.querySelectorAll("[data-filter]").forEach((element) => {
    element.classList.toggle("is-active", element.dataset.filter === currentFilter);
    if (element.matches(".nav-item")) {
      if (element.dataset.filter === currentFilter) element.setAttribute("aria-current", "page");
      else element.removeAttribute("aria-current");
    }
  });
}

function matchesFilter(task) {
  const active = task.lane !== "done";
  if (currentFilter === "all") return true;
  if (currentFilter === "action") return task.lane === "action";
  if (currentFilter === "waiting") return task.lane === "external" || task.lane === "internal";
  if (currentFilter === "no-followup") return active && !task.followUpAt;
  if (currentFilter === "blocked") return task.lane === "blocked";
  return false;
}

function matchesQuery(task) {
  if (!query) return true;
  const searchable = [
    task.title,
    task.project,
    task.owner,
    task.nextAction,
    ...task.events.map((event) => event.note),
  ].join(" ").toLocaleLowerCase("id-ID");
  return searchable.includes(query);
}

function isOverdue(task) {
  return task.followUpAt && task.followUpAt < localDateValue() && task.lane !== "done";
}

function followUpText(task) {
  if (!task.followUpAt) return '<span class="followup-empty">Follow-up belum diatur</span>';
  if (isOverdue(task)) {
    return `<span class="followup-late">Terlambat, ${escapeHTML(formatDate(task.followUpAt))}</span>`;
  }
  if (task.followUpAt === localDateValue()) {
    return '<span class="followup-today">Follow-up hari ini</span>';
  }
  return `<span>Follow-up ${escapeHTML(formatDate(task.followUpAt))}</span>`;
}

function taskCard(task) {
  const lane = LANES[task.lane];
  const nextAction = task.nextAction || "Tambahkan langkah berikutnya";
  return `
    <button class="task-card" type="button" data-action="open-task" data-id="${escapeHTML(task.id)}" aria-label="Buka task ${escapeHTML(task.title)}">
      <span class="task-card-top">
        <span class="project-label">${escapeHTML(task.project || "Tanpa nama proyek")}</span>
        <span class="status-label ${lane.className}">${escapeHTML(lane.label)}</span>
      </span>
      <span class="task-title">${escapeHTML(task.title)}</span>
      <span class="task-next">
        <span class="task-next-label">Langkah berikutnya</span>
        <span class="task-next-text">${escapeHTML(nextAction)}</span>
      </span>
      <span class="task-meta">
        <span class="task-meta-group">
          <span>Ditangani oleh <span class="owner-name">${escapeHTML(task.owner || "Belum ditentukan")}</span></span>
          ${followUpText(task)}
        </span>
        ${task.isExample ? '<span class="example-note">Contoh</span>' : ""}
      </span>
    </button>
  `;
}

function sortTasks(list) {
  return [...list].sort((a, b) => {
    const aFollowUp = a.followUpAt || "9999-12-31";
    const bFollowUp = b.followUpAt || "9999-12-31";
    if (aFollowUp !== bFollowUp) return aFollowUp.localeCompare(bFollowUp);
    return (b.updatedAt || "").localeCompare(a.updatedAt || "");
  });
}

function sectionMarkup(title, description, list, extraClass = "") {
  if (!list.length) return "";
  return `
    <section class="queue-column ${extraClass}" aria-label="${escapeHTML(title)}">
      <div class="queue-heading">
        <h2>${escapeHTML(title)}</h2>
        <p>${escapeHTML(description)}</p>
      </div>
      <div class="task-stack">${sortTasks(list).map(taskCard).join("")}</div>
    </section>
  `;
}

function emptyState() {
  const isSearching = Boolean(query);
  const filterLabels = {
    action: "Tidak ada task yang perlu kamu gerakkan.",
    waiting: "Tidak ada task yang sedang menunggu orang lain.",
    "no-followup": "Semua task aktif sudah punya jadwal follow-up.",
    blocked: "Tidak ada task yang sedang terhambat.",
  };
  if (isSearching || currentFilter !== "all") {
    return `
      <div class="empty-state">
        <span class="empty-mark" aria-hidden="true"></span>
        <h2>${escapeHTML(isSearching ? "Tidak ada hasil yang cocok." : filterLabels[currentFilter] || "Belum ada task di sini.")}</h2>
        <p>${escapeHTML(isSearching ? "Coba kata lain atau bersihkan pencarian." : "Pilih filter lain untuk melihat kerjaan yang berbeda.")}</p>
        ${isSearching ? '<button class="button button-quiet" type="button" data-action="clear-search">Bersihkan pencarian</button>' : ""}
      </div>
    `;
  }
  return `
    <div class="empty-state">
      <span class="empty-mark" aria-hidden="true"></span>
      <h2>Belum ada kerjaan yang dicatat.</h2>
      <p>Tambahkan task aktif agar jelas siapa yang menangani dan apa langkah berikutnya.</p>
      <div class="empty-actions">
        <button class="button button-primary" type="button" data-action="new-task">Tambah task pertama</button>
        <button class="button button-quiet" type="button" data-action="load-example">Coba contoh dari skenario kamu</button>
      </div>
    </div>
  `;
}

function errorState() {
  return `
    <div class="error-state">
      <h2>Database SQLite belum bisa diakses.</h2>
      <p>${escapeHTML(storageError)} Pastikan aplikasi berjalan lewat python3 server.py.</p>
      <div class="empty-actions">
        <button class="button button-quiet" type="button" data-action="retry-database">Coba hubungkan lagi</button>
      </div>
    </div>
  `;
}

function renderQueue() {
  queueContent.setAttribute("aria-busy", "false");
  if (storageError) {
    queueContent.innerHTML = errorState();
    return;
  }

  const visible = tasks.filter((task) => matchesFilter(task) && matchesQuery(task));
  if (!visible.length) {
    queueContent.innerHTML = emptyState();
    return;
  }

  const visibleDone = visible.filter((task) => task.lane === "done");
  const visibleAction = visible.filter((task) => task.lane === "action");
  const visibleWaiting = visible.filter((task) => task.lane === "external" || task.lane === "internal");
  const visibleBlocked = visible.filter((task) => task.lane === "blocked");

  if (currentFilter !== "all") {
    const filterTitle = {
      action: "Perlu gue gerakkan",
      waiting: "Nunggu orang lain",
      "no-followup": "Belum ada follow-up",
      blocked: "Terhambat",
    }[currentFilter] || "Semua kerjaan";
    queueContent.innerHTML = `
      <div class="queue-heading">
        <h2>${escapeHTML(filterTitle)}</h2>
        <p>${visible.length} task</p>
      </div>
      <div class="task-stack">${sortTasks(visible).map(taskCard).join("")}</div>
    `;
    return;
  }

  const sections = [
    sectionMarkup("Perlu gue gerakkan", "Aksi berikutnya ada di kamu", visibleAction),
    sectionMarkup("Nunggu orang lain", "Menunggu tindak lanjut dari orang lain", visibleWaiting, "section-gap"),
    sectionMarkup("Terhambat", "Perlu dibuka sebelum bisa lanjut", visibleBlocked, "section-gap"),
    sectionMarkup("Selesai", "Riwayat kerja yang sudah ditutup", visibleDone, "section-gap"),
  ].filter(Boolean);

  queueContent.innerHTML = sections.length
    ? `<div class="queue-grid">${sections.join("")}</div>`
    : emptyState();
}

function render() {
  updateCounts();
  renderQueue();
}

function showToast(message, isError = false) {
  clearTimeout(toastTimeout);
  toast.textContent = message;
  toast.classList.toggle("is-error", isError);
  toast.classList.add("is-visible");
  toastTimeout = window.setTimeout(() => toast.classList.remove("is-visible"), 3400);
}

function openTaskForm(task) {
  taskForm.reset();
  taskFormError.textContent = "";
  taskForm.elements.id.value = task?.id || "";
  taskForm.elements.title.value = task?.title || "";
  taskForm.elements.project.value = task?.project || "";
  taskForm.elements.lane.value = task?.lane || "action";
  renderOwnerOptions(task?.owner || "Gue");
  taskForm.elements.nextAction.value = task?.nextAction || "";
  taskForm.elements.followUpAt.value = task?.followUpAt || "";
  document.querySelector("#task-dialog-title").textContent = task ? "Edit task" : "Tambah task";
  taskDialog.showModal();
  taskForm.elements.title.focus();
}

function openTaskDetails(taskId) {
  const task = tasks.find((item) => item.id === taskId);
  if (!task) return;
  activeTaskId = taskId;
  renderDetail(task);
  detailDialog.showModal();
  detailDialog.querySelector(".icon-button").focus();
}

function renderDetail(task) {
  const lane = LANES[task.lane];
  const events = [...task.events].sort((a, b) => b.date.localeCompare(a.date));
  detailContent.innerHTML = `
    <article class="detail-panel">
      <header class="detail-header">
        <div>
          <p class="detail-project">${escapeHTML(task.project || "Tanpa nama proyek")}</p>
          <h2 id="detail-title">${escapeHTML(task.title)}</h2>
          ${task.isExample ? '<p class="example-note">Contoh dari skenario kamu</p>' : ""}
        </div>
        <button class="icon-button" type="button" aria-label="Tutup detail task" data-action="close-detail">×</button>
      </header>
      <div class="detail-content">
        <section class="detail-focus" aria-label="Langkah berikutnya">
          <p class="detail-label">Langkah berikutnya</p>
          <p class="next-action">${escapeHTML(task.nextAction || "Belum ditentukan")}</p>
        </section>
        <section class="detail-meta" aria-label="Status dan penanggung jawab">
          <div class="detail-meta-row">
            <span class="detail-label">Status</span>
            <span class="status-label ${lane.className}">${escapeHTML(lane.label)}</span>
          </div>
          <div class="detail-meta-row">
            <span class="detail-label">Giliran ada pada</span>
            <span class="detail-value">${escapeHTML(task.owner || "Belum ditentukan")}</span>
          </div>
          <div class="detail-meta-row">
            <span class="detail-label">Jadwal follow-up</span>
            <span class="detail-value">${task.followUpAt ? escapeHTML(formatDate(task.followUpAt)) : "Belum diatur"}</span>
          </div>
          <div class="detail-meta-row">
            <span class="detail-label">Terakhir diubah</span>
            <span class="detail-value">${escapeHTML(formatDate(task.updatedAt, { day: "numeric", month: "short", year: "numeric" }))}</span>
          </div>
        </section>
        <section aria-labelledby="activity-title">
          <div class="detail-section-heading">
            <h3 id="activity-title">Riwayat update</h3>
            <p>${events.length} catatan</p>
          </div>
          ${events.length
            ? `<ol class="activity-list">${events.map((event) => `
              <li class="activity-item">
                <time class="activity-date" datetime="${escapeHTML(event.date)}">${escapeHTML(formatDate(event.date))}</time>
                <p class="activity-note">${escapeHTML(event.note)}</p>
              </li>
            `).join("")}</ol>`
            : '<p class="activity-empty">Belum ada update. Catat perubahan terakhir supaya alurnya tetap jelas.</p>'}
        </section>
        <form class="event-form" id="event-form">
          <label class="field">
            <span>Catat update</span>
            <textarea name="note" required maxlength="240" rows="2" placeholder="Apa yang berubah, dan siapa yang perlu bergerak?"></textarea>
          </label>
          <div class="field-row">
            <label class="field">
              <span>Tanggal update</span>
              <input name="date" type="date" required value="${localDateValue()}">
            </label>
            <button class="button button-primary" type="submit">Simpan update</button>
          </div>
        </form>
        <div class="detail-actions">
          <button class="button button-quiet" type="button" data-action="edit-task" data-id="${escapeHTML(task.id)}">Edit task</button>
          ${task.lane !== "done"
            ? `<button class="button button-quiet" type="button" data-action="complete-task" data-id="${escapeHTML(task.id)}">Tandai selesai</button>`
            : ""}
          <button class="button button-danger push-right" type="button" data-action="delete-task" data-id="${escapeHTML(task.id)}">Hapus task</button>
        </div>
      </div>
    </article>
  `;
}

async function createExample() {
  const example = {
    id: createId(),
    title: "Integrasi WebBeds ke TourPlan",
    project: "WebBeds ke TourPlan",
    lane: "action",
    owner: "Gue",
    nextAction: "Follow up mapping process dan kebutuhan freelancer",
    followUpAt: "",
    updatedAt: "2026-10-13",
    isExample: true,
    events: [
      { id: createId(), date: "2026-10-12", note: "Email ke Jared sudah dikirim" },
      { id: createId(), date: "2026-10-13", note: "Jared sudah membalas" },
    ],
  };
  try {
    const result = await requestJSON("/api/tasks", {
      method: "POST",
      body: JSON.stringify(example),
    });
    tasks = [result.task, ...tasks];
    showStorageReady();
  } catch (error) {
    showStorageFailure(error);
    showToast(`Contoh gagal disimpan. ${error instanceof Error ? error.message : "Database SQLite tidak bisa diakses."}`, true);
    return;
  }
  currentFilter = "all";
  query = "";
  searchInput.value = "";
  showToast("Contoh dimuat. Edit atau hapus kapan saja.");
}

async function handleTaskSubmit(event) {
  event.preventDefault();
  taskFormError.textContent = "";
  const formData = new FormData(taskForm);
  const id = String(formData.get("id") || "");
  const existing = tasks.find((task) => task.id === id);
  const now = localDateValue();
  const nextTask = {
    id: existing?.id || createId(),
    title: String(formData.get("title") || "").trim(),
    project: String(formData.get("project") || "").trim(),
    lane: String(formData.get("lane") || "action"),
    owner: String(formData.get("owner") || "").trim(),
    nextAction: String(formData.get("nextAction") || "").trim(),
    followUpAt: String(formData.get("followUpAt") || ""),
    updatedAt: now,
    isExample: false,
    events: existing ? [...existing.events] : [{ id: createId(), date: now, note: "Task dibuat." }],
  };

  if (!nextTask.title || !nextTask.owner || !nextTask.nextAction) {
    taskFormError.textContent = "Nama task, penanggung jawab, dan langkah berikutnya perlu diisi.";
    return;
  }
  if (!Object.hasOwn(LANES, nextTask.lane)) {
    taskFormError.textContent = "Pilih status task yang tersedia.";
    return;
  }

  try {
    const result = await requestJSON(existing ? `/api/tasks/${encodeURIComponent(existing.id)}` : "/api/tasks", {
      method: existing ? "PUT" : "POST",
      body: JSON.stringify(nextTask),
    });
    tasks = existing
      ? tasks.map((task) => task.id === existing.id ? result.task : task)
      : [result.task, ...tasks];
    showStorageReady();
    taskDialog.close();
    render();
    if (detailDialog.open && activeTaskId === result.task.id) renderDetail(result.task);
    showToast(existing ? "Task diperbarui." : "Task ditambahkan.");
  } catch (error) {
    showStorageFailure(error);
    taskFormError.textContent = `Task belum tersimpan. ${error instanceof Error ? error.message : "Database SQLite tidak bisa diakses."}`;
  }
}

async function handleEventSubmit(event) {
  if (event.target.id !== "event-form") return;
  event.preventDefault();
  const task = tasks.find((item) => item.id === activeTaskId);
  if (!task) return;
  const formData = new FormData(event.target);
  const note = String(formData.get("note") || "").trim();
  const date = String(formData.get("date") || "");
  if (!note || !date) return;

  try {
    const result = await requestJSON(`/api/tasks/${encodeURIComponent(task.id)}/events`, {
      method: "POST",
      body: JSON.stringify({ date, note }),
    });
    tasks = tasks.map((item) => item.id === task.id ? result.task : item);
    showStorageReady();
    render();
    renderDetail(result.task);
    showToast("Update dicatat.");
  } catch (error) {
    showStorageFailure(error);
    showToast(`Update belum tersimpan. ${error instanceof Error ? error.message : "Database SQLite tidak bisa diakses."}`, true);
  }
}

async function handleClick(event) {
  const control = event.target.closest("[data-action], [data-filter]");
  if (!control) return;

  if (control.dataset.filter) {
    currentFilter = control.dataset.filter;
    render();
    return;
  }

  const { action, id } = control.dataset;
  if (action === "new-task") openTaskForm();
  if (action === "close-task-dialog") taskDialog.close();
  if (action === "open-person-dialog") openPersonDialog();
  if (action === "close-person-dialog") personDialog.close();
  if (action === "close-detail") detailDialog.close();
  if (action === "open-task") openTaskDetails(id);
  if (action === "edit-task") {
    const task = tasks.find((item) => item.id === id);
    if (!task) return;
    detailDialog.close();
    openTaskForm(task);
  }
  if (action === "load-example") await createExample();
  if (action === "clear-search") {
    searchInput.value = "";
    query = "";
    searchInput.focus();
    render();
  }
  if (action === "retry-database") await readTasks();
  if (action === "complete-task") {
    const task = tasks.find((item) => item.id === id);
    if (!task) return;
    try {
      const result = await requestJSON(`/api/tasks/${encodeURIComponent(id)}`, {
        method: "PUT",
        body: JSON.stringify({ ...task, lane: "done" }),
      });
      tasks = tasks.map((item) => item.id === id ? result.task : item);
      showStorageReady();
      render();
      renderDetail(result.task);
      showToast("Task ditandai selesai.");
    } catch (error) {
      showStorageFailure(error);
      showToast(`Status belum tersimpan. ${error instanceof Error ? error.message : "Database SQLite tidak bisa diakses."}`, true);
    }
  }
  if (action === "delete-task") {
    const task = tasks.find((item) => item.id === id);
    if (!task || !window.confirm(`Hapus "${task.title}" beserta riwayat update-nya?`)) return;
    try {
      await requestJSON(`/api/tasks/${encodeURIComponent(id)}`, { method: "DELETE" });
      tasks = tasks.filter((item) => item.id !== id);
      showStorageReady();
      detailDialog.close();
      render();
      showToast("Task dihapus.");
    } catch (error) {
      showStorageFailure(error);
      showToast(`Task belum dihapus. ${error instanceof Error ? error.message : "Database SQLite tidak bisa diakses."}`, true);
    }
  }
}

taskForm.addEventListener("submit", (event) => {
  event.preventDefault();
  void handleTaskSubmit(event);
});
personForm.addEventListener("submit", (event) => {
  event.preventDefault();
  void handlePersonSubmit(event);
});
document.addEventListener("submit", (event) => {
  if (event.target.id === "event-form") void handleEventSubmit(event);
});
document.addEventListener("click", (event) => {
  void handleClick(event);
});
searchInput.addEventListener("input", () => {
  query = searchInput.value.trim().toLocaleLowerCase("id-ID");
  render();
});
taskForm.elements.lane.addEventListener("change", () => {
  if (taskForm.elements.id.value) return;
  if (taskForm.elements.lane.value === "action" && !taskForm.elements.owner.value.trim()) {
    taskForm.elements.owner.value = "Gue";
  }
  if (taskForm.elements.lane.value !== "action" && taskForm.elements.owner.value.trim() === "Gue") {
    taskForm.elements.owner.value = "";
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "/" && !taskDialog.open && !detailDialog.open && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName)) {
    event.preventDefault();
    searchInput.focus();
  }
});
detailDialog.addEventListener("close", () => {
  activeTaskId = "";
});

document.querySelector("#today-label").textContent = new Intl.DateTimeFormat("id-ID", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
}).format(new Date());

window.requestAnimationFrame(readTasks);
