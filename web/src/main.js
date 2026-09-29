const app = document.querySelector("#app");

const pathParts = window.location.pathname
  .split("/")
  .filter(Boolean);

const [route, boatId] = pathParts;

function mountGodot(path, title) {
  app.innerHTML = "";

  // const heading = document.createElement("p");
  // heading.textContent = title;

  const iframe = document.createElement("iframe");
  iframe.title = title;
  iframe.src = path;
  iframe.style.width = "100%";
  iframe.style.height = "100vh";
  iframe.style.border = "0";

  // app.append(heading, iframe);
  app.append(iframe);
}

if (route === "boat" && boatId) {
  mountGodot(
    `/godot/client/client.html?boat=${encodeURIComponent(boatId)}`,
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