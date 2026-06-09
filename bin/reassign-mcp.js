#!/usr/bin/env node
import { spawn } from "node:child_process";

const url = process.env.REASSIGN_MCP_URL || "https://reassign.app/api/mcp";

// Validate before spawning: on Windows we use shell:true, so an http(s) check
// keeps a URL with shell metacharacters out of cmd.exe (and catches typos).
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

const child = spawn("npx", ["-y", "mcp-remote", url], {
  stdio: "inherit",
  shell: process.platform === "win32",
});
child.on("error", (err) => {
  console.error(`reassign-mcp: failed to start (is npx on PATH?): ${err.message}`);
  process.exit(1);
});
child.on("exit", (code) => process.exit(code ?? 0));
