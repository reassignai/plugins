#!/usr/bin/env node
// Source of truth for client install deep links.
// Reads .mcp.json and derives Cursor + VS Code one-click install configs,
// writing them to dist/deeplinks.json. The reassign.ai connect.html widget
// (../reassignai, reassignai#35) imports this so its buttons never drift.
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const mcp = JSON.parse(readFileSync(join(root, ".mcp.json"), "utf8"));

const links = {};
for (const [name, server] of Object.entries(mcp.mcpServers)) {
  const { url } = server;

  // Cursor: ?name=<name>&config=<base64({url})>
  const cursorConfig = Buffer.from(JSON.stringify({ url })).toString("base64");
  const cursor = `https://cursor.com/install-mcp?name=${encodeURIComponent(
    name
  )}&config=${encodeURIComponent(cursorConfig)}`;

  // VS Code: ?name=<name>&config=<urlencoded({name,url})>
  const vscodeConfig = encodeURIComponent(JSON.stringify({ name, url }));
  const vscode = `https://insiders.vscode.dev/redirect/mcp/install?name=${encodeURIComponent(
    name
  )}&config=${vscodeConfig}`;

  links[name] = { url, cursor, vscode };
}

const out = join(root, "dist", "deeplinks.json");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(links, null, 2) + "\n");
console.log(`  wrote ${out}`);
