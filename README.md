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
| **Standalone skill** | `npx skills add reassignai/plugins` |
| **Claude.ai / ChatGPT connector** | Add a custom connector pointing at `https://reassign.app/api/mcp` |
| **npm (any stdio MCP client)** | `npx -y @reassign/mcp` |

## What's inside

```
plugins/                                  ← repo root = plugin root
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .mcp.json
├── skills/
│   └── reassign-scheduling/              ← canonical skill (plugin + standalone, zero copy)
│       ├── SKILL.md
│       └── references/
│           ├── adhd-methods.md
│           ├── workflows.md
│           ├── taxonomy.md
│           └── calendars.md          ← connected-calendar sync, event kinds, mirroring
├── server.json                           ← Official MCP Registry entry
├── package.json                          ← npm client shim
├── bin/reassign-mcp.js
├── scripts/
│   └── build.sh
├── .github/workflows/
│   ├── publish-registry.yml
│   └── publish-npm.yml
├── README.md
└── LICENSE
```

The `skills/reassign-scheduling/` directory is the single source of truth: both the
Claude Code plugin and the standalone skill consume it in place, with no copying.

## Links

- Website: [reassign.ai](https://reassign.ai)
- MCP endpoint: `https://reassign.app/api/mcp`

## License

[Apache-2.0](LICENSE) © Pogled Naprej d.o.o.
