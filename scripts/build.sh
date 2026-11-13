#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/reassign-scheduling/SKILL.md"

echo "→ Validating canonical SKILL.md"
test -f "$SKILL" || { echo "missing $SKILL"; exit 1; }
head -1 "$SKILL" | grep -q '^---$' || { echo "SKILL.md missing frontmatter"; exit 1; }
lines=$(wc -l < "$SKILL"); [ "$lines" -le 600 ] || echo "  warn: SKILL.md is $lines lines (>600 target)"

# Both manifest pairs ship, and a client reads exactly one of them: the Agent
# Plugins root pair (VS Code, Cursor, Copilot, Codex, Kiro) or claude/.claude-plugin/
# + claude/.mcp.json (Claude Code). A malformed one is invisible until the client that
# reads it fails, so parse every one here rather than trusting the diff.
echo "→ Validating plugin manifests"
for manifest in plugin.json mcp.json claude/.mcp.json claude/.claude-plugin/plugin.json .claude-plugin/marketplace.json server.json; do
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
  const plugin = load("plugin.json"), mcp = load("mcp.json"), claudeMcp = load("claude/.mcp.json");
  load("claude/.claude-plugin/plugin.json"); load(".claude-plugin/marketplace.json"); load("server.json");
  if (plugin.$schema !== `https://agent-plugins.org/schemas/${v}/plugin.schema.json`)
    throw new Error("plugin.json: wrong or missing Agent Plugins $schema");
  if (mcp.$schema !== `https://agent-plugins.org/schemas/${v}/mcp.schema.json`)
    throw new Error("mcp.json: wrong or missing Agent Plugins $schema");
  // The OpenAI portal reads extensions["com.openai"]. A missing asset or a text
  // over its limit shows only at the upload, so check the block here.
  const oa = plugin.extensions?.["com.openai"];
  if (oa) {
    const { existsSync } = require("fs");
    const ui = oa.interface ?? {}, cases = oa.review?.test_cases ?? {};
    const max = (what, text, n) => {
      if (typeof text !== "string" || !text || text.length > n)
        throw new Error(`plugin.json com.openai: ${what} must be 1 to ${n} characters`);
    };
    max("displayName", ui.displayName, 30); max("shortDescription", ui.shortDescription, 30);
    max("longDescription", ui.longDescription, 4000); max("developerName", ui.developerName, 80);
    const prompts = [].concat(ui.defaultPrompt ?? []);
    if (prompts.length > 3) throw new Error("plugin.json com.openai: at most 3 defaultPrompt entries");
    prompts.forEach((t) => max("defaultPrompt", t, 128));
    if ((ui.capabilities ?? []).length > 20) throw new Error("plugin.json com.openai: at most 20 capabilities");
    (ui.capabilities ?? []).forEach((t) => max("capability", t, 120));
    for (const key of ["logo", "composerIcon", "logoDark", "composerIconDark"])
      if (ui[key] && !(ui[key].startsWith("./") && existsSync(join(root, ui[key]))))
        throw new Error(`plugin.json com.openai: ${key} "${ui[key]}" must be a ./ path to a file in the repo`);
    if ((cases.positive ?? []).length !== 5 || (cases.negative ?? []).length !== 3)
      throw new Error("plugin.json com.openai: the MCP review needs exactly 5 positive and 3 negative test cases");
    for (const c of [...(cases.positive ?? []), ...(cases.negative ?? [])])
      if ("tools_triggered" in c && !/^[a-z_]+(, [a-z_]+)*$/.test(c.tools_triggered ?? ""))
        throw new Error("plugin.json com.openai: tools_triggered must be one string of tool names, for example \"get_schedule, write_events\"");
  }
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
  const claude = urls("claude/.mcp.json", claudeMcp, ["stdio", "http", "sse"]);
  for (const [name, url] of spec) {
    if (!claude.has(name)) throw new Error(`claude/.mcp.json: missing server "${name}" that mcp.json declares`);
    if (claude.get(name) !== url)
      throw new Error(`server "${name}" url drift: mcp.json ${url} vs claude/.mcp.json ${claude.get(name)}`);
  }
  for (const name of claude.keys())
    if (!spec.has(name)) throw new Error(`mcp.json: missing server "${name}" that claude/.mcp.json declares`);
'

# claude.ai and Cowork refuse to install a plugin with a top-level bin/, so the
# npm shim lives in npm/. Fail here rather than at directory validation.
echo "→ Validating surfaces"
test ! -e "$ROOT/bin" || { echo "top-level bin/ blocks Cowork and Claude apps; move it (npm shim → npm/)"; exit 1; }

# The Claude directory takes only a clean plugin folder from an unverified
# organization, so claude/ holds a copy of skills/. skills/ is the source.
# The Claude icon is a copy of the OpenAI logo, so a new logo reaches both listings.
icon=$(node -p 'require(process.argv[1]).icon ?? ""' "$ROOT/claude/.claude-plugin/plugin.json")
test -n "$icon" || { echo "claude/.claude-plugin/plugin.json: missing icon"; exit 1; }
cmp -s "$ROOT/claude/$icon" "$ROOT/assets/logo.png" || { echo "claude/$icon must exist and match assets/logo.png"; exit 1; }

echo "→ Syncing claude/skills from skills/"
rm -rf "$ROOT/claude/skills" && cp -R "$ROOT/skills" "$ROOT/claude/skills"

echo "→ Validating version lockstep"
node "$ROOT/scripts/version.mjs" check

echo "✓ Build complete. skills/ is the source; claude/skills is its copy for the Claude plugin."
