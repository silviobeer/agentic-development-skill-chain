import http from "node:http";
import { fileURLToPath } from "node:url";

let profile = { timezone: "UTC" };

export function getProfile() {
  return { ...profile };
}

export function resetProfile() {
  profile = { timezone: "UTC" };
}

export function saveProfile(input) {
  // BUG: success is returned without persisting input.timezone.
  return { ok: true };
}

const page = `<!doctype html>
<html lang="en">
  <body>
    <main>
      <h1>Profile</h1>
      <label for="timezone">Timezone</label>
      <select id="timezone">
        <option value="UTC">UTC</option>
        <option value="Europe/Zurich">Europe/Zurich</option>
      </select>
      <button id="save" type="button">Save</button>
      <p id="status" role="status"></p>
    </main>
    <script>
      const timezone = document.querySelector('#timezone');
      const status = document.querySelector('#status');
      fetch('/api/profile').then(r => r.json()).then(p => { timezone.value = p.timezone; });
      document.querySelector('#save').addEventListener('click', async () => {
        const response = await fetch('/api/profile', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ timezone: timezone.value })
        });
        const result = await response.json();
        status.textContent = result.ok ? 'Saved' : 'Save failed';
      });
    </script>
  </body>
</html>`;

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

export function createServer() {
  return http.createServer(async (request, response) => {
    if (request.method === "GET" && request.url === "/") {
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      response.end(page);
      return;
    }

    if (request.method === "GET" && request.url === "/api/profile") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify(getProfile()));
      return;
    }

    if (request.method === "POST" && request.url === "/api/profile") {
      const input = await readJson(request);
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify(saveProfile(input)));
      return;
    }

    response.writeHead(404);
    response.end("Not found");
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT ?? 4173);
  createServer().listen(port, "127.0.0.1", () => {
    console.log(`Profile fixture listening on http://127.0.0.1:${port}`);
  });
}
