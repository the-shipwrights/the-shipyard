const app = document.querySelector("#app");

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

function handleRoute() {
  const pathParts = window.location.pathname
    .split("/")
    .filter(Boolean);

  const [route, boatId] = pathParts;

  if (route === "boat") {
    if (boatId) {
      // Existing boat: open customizer/controller view
      mountGodot(
        `/godot/client/client.html?boat=${encodeURIComponent(boatId)}`,
        `Customizing boat ${boatId.toUpperCase()}`
      );
    } else {
      // /boat without ID: mount builder view
      mountGodot(
        "/godot/client/client.html",
        "Boat Builder"
      );
    }
  } else if (route === "build") {
    // Explicit /build route: mount builder view
    mountGodot(
      "/godot/client/client.html",
      "Boat Builder"
    );
  } else if (route === "simulation") {
    mountGodot(
      "/godot/simulation/index.html",
      "Ocean simulation"
    );
  } else {
    // Default fallback: open builder instead of dead-ending on a text prompt
    mountGodot(
      "/godot/client/client.html",
      "Boat Builder"
    );
  }
}

handleRoute();
window.addEventListener("popstate", handleRoute);