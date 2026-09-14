const app = document.querySelector("#app");

const parts = window.location.pathname
  .split("/")
  .filter(Boolean);

const route = parts[0];
const boatId = parts[1];

function mountGodot(path, title) {
  app.innerHTML = "";

  const heading = document.createElement("h1");
  heading.textContent = title;

  const iframe = document.createElement("iframe");
  iframe.title = title;
  iframe.src = path;
  iframe.style.width = "100%";
  iframe.style.height = "80vh";
  iframe.style.border = "0";

  app.append(heading, iframe);
}

if (route === "boat" && boatId) {
  mountGodot(
    `/godot/customizer/index.html?boat=${encodeURIComponent(boatId)}`,
    `Customizing boat ${boatId.toUpperCase()}`
  );
} else if (route === "simulation") {
  mountGodot(
    "/godot/simulation/index.html",
    "Ocean simulation"
  );
} else {
  app.textContent = "Open a URL such as /boat/ABCD";
}