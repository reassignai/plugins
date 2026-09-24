# Reassign

**Reassign: a circular 24-hour day planner. One capability, five package forms, one canonical skill.**

Reassign plans, edits, and reviews your day on a circular 24-hour calendar. It
applies ADHD-friendly time-management methods as concrete edits to the dial, not
advice recited back at you. The same scheduling capability ships in several package
forms, all backed by one canonical skill and the Reassign MCP.

## Install

| Form | How |
|---|---|
| **Claude Code plugin** | `/plugin marketplace add reassignai/plugins` → `/plugin install reassign@reassign` |
| **Agent Plugin** (VS Code, Cursor, Copilot, Codex, Kiro) | Install from source with the repo URL — e.g. VS Code's **Chat: Install Plugin From Source** → `https://github.com/reassignai/plugins` |
| **Standalone skill** | `npx skills add reassignai/plugins` |
| **Claude.ai / ChatGPT connector** | Add a custom connector pointing at `https://reassign.app/api/mcp` |
| **npm (any stdio MCP client)** | `npx -y @reassign/mcp` |

## What's inside

```
plugins/                                  ← repo root = plugin root
├── plugin.json                           ← Agent Plugins 1.0.0 manifest
├── mcp.json                              ← Agent Plugins MCP config (streamable-http)
├── .claude-plugin/
│   ├── plugin.json                       ← Claude Code manifest
│   └── marketplace.json
├── .mcp.json                             ← Claude Code MCP config (type "http")
├── skills/
│   └── reassign-scheduling/              ← canonical skill (every form, zero copy)
│       ├── SKILL.md
│       └── references/
│           ├── adhd-methods.md
│           ├── focus.md             ← focus intervals, live pauses, and saved rhythms
│           ├── workflows.md
│           ├── taxonomy.md
│           ├── calendars.md          ← calendar and task-app sync, import policies, event kinds, mirroring
│           ├── reflection.md         ← reviewing a past day: marks + adherence
│           └── limits.md             ← subscription access, refusal codes, and retries
├── server.json                           ← Official MCP Registry entry
├── package.json                          ← npm client shim
├── bin/reassign-mcp.js
├── scripts/
│   ├── build.sh                          ← validates manifests + version lockstep
│   └── version.mjs                       ← reads/sets the two version trains
├── .github/workflows/
│   ├── publish-registry.yml
│   └── publish-npm.yml
├── README.md
└── LICENSE
```

The `skills/reassign-scheduling/` directory is the single source of truth: every
package form consumes it in place, with no copying.

### Two manifests, on purpose

The root `plugin.json`/`mcp.json` pair is [Agent Plugins
1.0.0](https://agent-plugins.org/); `.claude-plugin/plugin.json` + `.mcp.json` is
the Claude Code format. Clients auto-detect by manifest path and read exactly
one pair, so both ship side by side. They are **not** copies of each other — the
same endpoint is `"type": "streamable-http"` under the spec and `"type": "http"`
for Claude Code, so `scripts/build.sh` checks each file's transport vocabulary
separately — and cross-checks that the two still name the same servers at the
same URLs, since a copy-paste and a one-sided URL move are both silent breaks.

### Versions

Two independent trains, both checked by `scripts/build.sh`:

| Train | Files | What it tracks |
|---|---|---|
| `plugin` | `plugin.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `SKILL.md` | the skill and its manifests |
| `package` | `package.json`, `server.json` | the npm shim + registry entry, released on a `v*` tag |

```bash
node scripts/version.mjs                 # print both
node scripts/version.mjs check           # exit 1 on drift
node scripts/version.mjs set plugin 1.11.0
```

## Links

- Website: [reassign.ai](https://reassign.ai)
- MCP endpoint: `https://reassign.app/api/mcp`
- Developer docs (MCP setup, REST API, error codes): [reassign.dev](https://reassign.dev)

## License

[Apache-2.0](LICENSE) © Pogled Naprej d.o.o.
