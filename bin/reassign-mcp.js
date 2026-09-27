#!/usr/bin/env node
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { constants } from "node:os";
import { dirname, join } from "node:path";

const url = process.env.REASSIGN_MCP_URL || "https://reassign.app/api/mcp";

// Validate before spawning to catch typos and non-http(s) schemes early.
let parsed;
try {
  parsed = new URL(url);
} catch {
  console.error(`reassign-mcp: invalid REASSIGN_MCP_URL: ${url}`);
  process.exit(1);
}
if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
  console.error(`reassign-mcp: REASSIGN_MCP_URL must be http(s), got ${parsed.protocol}`);
  process.exit(1);
}

// Run the pinned mcp-remote dependency with this Node, not `npx mcp-remote`:
// no registry fetch of an unpinned version at startup, and no shell on Windows.
const require = createRequire(import.meta.url);
const pkgPath = require.resolve("mcp-remote/package.json");
const { bin } = JSON.parse(readFileSync(pkgPath, "utf8"));
const proxy = join(dirname(pkgPath), typeof bin === "string" ? bin : bin["mcp-remote"]);

const child = spawn(process.execPath, [proxy, url], { stdio: "inherit" });

// MCP clients stop the server with a signal to this process only; pass it on
// so mcp-remote does not outlive the shim.
for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => child.kill(signal));
}
child.on("error", (err) => {
  console.error(`reassign-mcp: failed to start mcp-remote: ${err.message}`);
  process.exit(1);
});
child.on("exit", (code, signal) => {
  process.exit(signal ? 128 + (constants.signals[signal] ?? 0) : (code ?? 1));
});
