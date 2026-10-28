const app = document.querySelector("#app");
let adminCredentials = null;

function mountGodot(path, title) {
  app.innerHTML = "";

  const iframe = document.createElement("iframe");
  iframe.title = title;
  iframe.src = path;
  iframe.style.width = "100%";
  iframe.style.height = "100vh";
  iframe.style.border = "0";

  app.append(iframe);
}

function setMessage(target, message, isError = false) {
  target.textContent = message;
  target.classList.toggle("error", isError);
  target.hidden = !message;
}

function encodeBasicCredentials({ username, password }) {
  const bytes = new TextEncoder().encode(`${username}:${password}`);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return `Basic ${btoa(binary)}`;
}

async function adminRequest(path, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("Authorization", encodeBasicCredentials(adminCredentials));
  if (options.body) headers.set("Content-Type", "application/json");

  const response = await fetch(path, { ...options, headers });
  if (!response.ok) {
    const result = await response.json().catch(() => ({}));
    throw new Error(result.detail || `Request failed (${response.status})`);
  }
  if (response.status === 204) return null;
  return response.json();
}

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function showAdminLogin(content) {
  content.replaceChildren();
  const form = element("form", "admin-login");
  form.innerHTML = `
    <h2>Operator sign in</h2>
    <p>Use the operator credentials configured on this computer.</p>
    <label>Username<input name="username" autocomplete="username" required></label>
    <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
    <p class="admin-message" role="alert" hidden></p>
    <button type="submit">Sign in</button>
  `;
  const message = form.querySelector(".admin-message");
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = new FormData(form);
    adminCredentials = {
      username: String(data.get("username")),
      password: String(data.get("password")),
    };
    try {
      const boats = await adminRequest("/api/admin/boats");
      showAdminBoats(content, boats);
    } catch (error) {
      adminCredentials = null;
      setMessage(message, error.message, true);
    }
  });
  content.append(form);
}

function makeColorInput(labelText, value) {
  const label = element("label", "color-field", labelText);
  const input = document.createElement("input");
  input.type = "color";
  input.value = /^#[0-9a-fA-F]{6}$/.test(value) ? value : "#ffffff";
  label.append(input);
  return input;
}

function makeBoatCard(boat, content) {
  const card = element("article", "boat-card");
  const heading = element("div", "boat-card-heading");
  const title = element("h2", "", `Boat ${boat.id}`);
  const statusTag = element("span", "boat-status", boat.status);
  heading.append(title, statusTag);

  const meta = element(
    "p",
    "boat-meta",
    `Created ${new Date(boat.created_at).toLocaleString()} · Updated ${new Date(boat.updated_at).toLocaleString()}`,
  );
  const form = element("form", "boat-edit-form");
  const customization = boat.customization || {};
  const colorFields = element("div", "color-fields");
  const primary = makeColorInput("Primary", customization.primary || "#2f7fff");
  const secondary = makeColorInput("Secondary", customization.secondary || "#ffffff");
  const accent = makeColorInput("Accent", customization.accent || "#ff8800");
  colorFields.append(primary.parentElement, secondary.parentElement, accent.parentElement);

  const statusLabel = element("label", "status-field", "Status");
  const status = document.createElement("select");
  for (const value of ["customizing", "launched"]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    option.selected = boat.status === value;
    status.append(option);
  }
  statusLabel.append(status);

  const structureLabel = element("label", "structure-field", "Boat structure (JSON)");
  const structure = document.createElement("textarea");
  structure.rows = 9;
  structure.spellcheck = false;
  structure.value = JSON.stringify(boat.boat, null, 2);
  structureLabel.append(structure);

  const actions = element("div", "boat-actions");
  const save = element("button", "", "Save changes");
  save.type = "submit";
  const remove = element("button", "danger", "Delete boat");
  remove.type = "button";
  const message = element("p", "admin-message");
  message.hidden = true;
  actions.append(save, remove);

  form.append(colorFields, statusLabel, structureLabel, actions, message);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    save.disabled = true;
    try {
      const updatedBoat = JSON.parse(structure.value);
      await adminRequest(`/api/admin/boats/${encodeURIComponent(boat.id)}`, {
        method: "PATCH",
        body: JSON.stringify({
          boat: updatedBoat,
          customization: {
            primary: primary.value,
            secondary: secondary.value,
            accent: accent.value,
          },
          status: status.value,
        }),
      });
      const refreshed = await adminRequest("/api/admin/boats");
      showAdminBoats(content, refreshed, `Boat ${boat.id} saved.`);
    } catch (error) {
      setMessage(message, error.message, true);
      save.disabled = false;
    }
  });
  remove.addEventListener("click", async () => {
    if (!window.confirm(`Delete boat ${boat.id}? This cannot be undone.`)) return;
    remove.disabled = true;
    try {
      await adminRequest(`/api/admin/boats/${encodeURIComponent(boat.id)}`, {
        method: "DELETE",
      });
      const refreshed = await adminRequest("/api/admin/boats");
      showAdminBoats(content, refreshed, `Boat ${boat.id} deleted.`);
    } catch (error) {
      setMessage(message, error.message, true);
      remove.disabled = false;
    }
  });

  card.append(heading, meta, form);
  return card;
}

function showAdminBoats(content, boats, notice = "") {
  content.replaceChildren();
  const toolbar = element("div", "admin-toolbar");
  const count = element("p", "", `${boats.length} boat${boats.length === 1 ? "" : "s"}`);
  const actions = element("div", "admin-toolbar-actions");
  const refresh = element("button", "secondary", "Refresh");
  refresh.addEventListener("click", async () => {
    refresh.disabled = true;
    try {
      showAdminBoats(content, await adminRequest("/api/admin/boats"));
    } catch (error) {
      setMessage(noticeNode, error.message, true);
      refresh.disabled = false;
    }
  });
  const logout = element("button", "secondary", "Sign out");
  logout.addEventListener("click", () => {
    adminCredentials = null;
    showAdminLogin(content);
  });
  actions.append(refresh, logout);
  toolbar.append(count, actions);

  const noticeNode = element("p", "admin-message", notice);
  noticeNode.hidden = !notice;
  const list = element("section", "boat-list");
  if (boats.length === 0) {
    list.append(element("p", "empty-state", "No boats have been submitted yet."));
  } else {
    for (const boat of boats) list.append(makeBoatCard(boat, content));
  }
  content.append(toolbar, noticeNode, list);
}

function mountAdmin() {
  app.innerHTML = `
    <main class="admin-shell">
      <header class="admin-header">
        <div><p class="eyebrow">THE SHIPYARD</p><h1>Operator console</h1></div>
        <a href="/">Participant page</a>
      </header>
      <div class="admin-content"></div>
    </main>
  `;
  showAdminLogin(app.querySelector(".admin-content"));
}

function handleRoute() {
  const pathParts = window.location.pathname.split("/").filter(Boolean);
  const [route, boatId] = pathParts;

  if (route === "admin") {
    mountAdmin();
  } else if (route === "boat") {
    if (boatId) {
      mountGodot(
        `/godot/client/client.html?boat=${encodeURIComponent(boatId)}`,
        `Customizing boat ${boatId.toUpperCase()}`,
      );
    } else {
      mountGodot("/godot/client/client.html", "Boat Builder");
    }
  } else if (route === "build") {
    mountGodot("/godot/client/client.html", "Boat Builder");
  } else if (route === "simulation") {
    mountGodot("/godot/simulation/index.html", "Ocean simulation");
  } else {
    mountGodot("/godot/client/client.html", "Boat Builder");
  }
}

handleRoute();
window.addEventListener("popstate", handleRoute);
