#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/reassign-scheduling/SKILL.md"

echo "→ Validating canonical SKILL.md"
test -f "$SKILL" || { echo "missing $SKILL"; exit 1; }
head -1 "$SKILL" | grep -q '^---$' || { echo "SKILL.md missing frontmatter"; exit 1; }
lines=$(wc -l < "$SKILL"); [ "$lines" -le 600 ] || echo "  warn: SKILL.md is $lines lines (>600 target)"

# Both manifest pairs ship, and a client reads exactly one of them: the Agent
# Plugins root pair (VS Code, Cursor, Copilot, Codex, Kiro) or .claude-plugin/
# + .mcp.json (Claude Code). A malformed one is invisible until the client that
# reads it fails, so parse every one here rather than trusting the diff.
echo "→ Validating plugin manifests"
for manifest in plugin.json mcp.json .mcp.json .claude-plugin/plugin.json .claude-plugin/marketplace.json server.json; do
  test -f "$ROOT/$manifest" || { echo "missing $manifest"; exit 1; }
done
ROOT="$ROOT" node -e '
  const { readFileSync } = require("fs"), { join } = require("path");
  const root = process.env.ROOT;
  const load = (f) => {
    try { return JSON.parse(readFileSync(join(root, f), "utf8")); }
    catch (e) { throw new Error(f + " is not valid JSON: " + e.message); }
  };
  const v = "1.0.0";
  const plugin = load("plugin.json"), mcp = load("mcp.json"), claudeMcp = load(".mcp.json");
  load(".claude-plugin/plugin.json"); load(".claude-plugin/marketplace.json"); load("server.json");
  if (plugin.$schema !== `https://agent-plugins.org/schemas/${v}/plugin.schema.json`)
    throw new Error("plugin.json: wrong or missing Agent Plugins $schema");
  if (mcp.$schema !== `https://agent-plugins.org/schemas/${v}/mcp.schema.json`)
    throw new Error("mcp.json: wrong or missing Agent Plugins $schema");
  // The two MCP configs describe the SAME endpoint in two vocabularies: the
  // spec says stdio | streamable-http | sse, Claude Code says stdio | http | sse.
  // So they are NOT copies of each other — a copy-paste between them is a silent
  // break, and so is moving the URL in only one of them.
  const urls = (file, cfg, allowed) => {
    const entries = Object.entries(cfg.mcpServers ?? {});
    if (!entries.length) throw new Error(file + ": no mcpServers — nothing would register");
    for (const [name, s] of entries)
      if (!allowed.includes(s.type))
        throw new Error(`${file}: server "${name}" has type "${s.type}", expected ${allowed.join(" | ")}`);
    return new Map(entries.map(([name, s]) => [name, s.url]));
  };
  const spec = urls("mcp.json", mcp, ["stdio", "streamable-http", "sse"]);
  const claude = urls(".mcp.json", claudeMcp, ["stdio", "http", "sse"]);
  for (const [name, url] of spec) {
    if (!claude.has(name)) throw new Error(`.mcp.json: missing server "${name}" that mcp.json declares`);
    if (claude.get(name) !== url)
      throw new Error(`server "${name}" url drift: mcp.json ${url} vs .mcp.json ${claude.get(name)}`);
  }
  for (const name of claude.keys())
    if (!spec.has(name)) throw new Error(`mcp.json: missing server "${name}" that .mcp.json declares`);
'

echo "→ Validating version lockstep"
node "$ROOT/scripts/version.mjs" check

echo "✓ Build complete. Plugin + standalone skill consume skills/ in place; nothing to copy."
