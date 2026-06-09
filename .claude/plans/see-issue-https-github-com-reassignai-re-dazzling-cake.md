# Plan — #187 MCP + Skills distribution: build the `reassignai/plugins` cascade repo

## Context

GitHub issue [reassignai/reassign#187](https://github.com/reassignai/reassign/issues/187) is the **tracker** for shipping Reassign's scheduling capability as **one capability / five package forms / one canonical `SKILL.md`** out of a single new **public** repo. Both product repos (`reassign`, `reassignai`) are private, so neither can be the plugin root — hence this repo, `reassignai/plugins` (currently empty: git-initialized, remote set, **no commits yet**).

The full design lives in `../reassignai/plan/braindump/reassign-distribution-spec.md`. **Two things in that spec are stale and must be corrected as we build:**

1. **Repo slug** — spec uses placeholder `reassign-app/reassign`; the real slug is **`reassignai/plugins`** (per the issues). Affects `marketplace.json` install command, `server.json` repository URL, `package.json` repository, skills source paths.
2. **MCP tool names** — spec §2 lists `get_context`, `find_free_slots`, `commit`, `write_taxonomy` (aspirational). The **real** tools registered in `../reassign/lib/mcp/server.ts` (server name `reassign`) are:
   `get_schedule` · `write_events` · `delete_events` · `manage_categories` · `schedule` · `confirm_schedule` · `find_event` · `show_day` · `undo` · `send_feedback`.
   The SKILL.md `allowed-tools` + body **must use these real names** (referenced as `mcp__reassign__<tool>`), and the workflows must be rewritten to the real verbs (`get_schedule` first; `schedule` → `confirm_schedule`; bulk via `write_events`; removals via `delete_events`; areas/types via `manage_categories`).

**Intended outcome:** a well-formed public repo that, once published, cascades into PulseMCP / GitHub MCP Registry / VS Code Gallery / Glama / skills.sh / claudemarketplaces.com with near-zero marginal submission cost (the monetization thesis: first-mover, near-zero-CAC discovery in under-served Productivity/ADHD).

## Approach (per user direction)

**First action: write a working build spec into this repo at `docs/build-plan.md` (gitignored — NOT committed).** It is the corrected, repo-specific, real-tool-name version of the distribution spec, reorganized as an ordered set of small **T-steps**. Then we execute the T-steps one at a time, **committing each step separately**. The spec doc references each step as `T1`…`Tn` so we can point at them as we go.

Scope of executable build work = sub-issue **#230** (the `[app]` repo). External publishing (#231) and the `reassign.ai` front door (reassignai#35) stay as a **credentialed follow-up checklist** in the doc, not executed in the build phase. `connect.html` + `.well-known/skills/index.json` are **site files → the `../reassignai` repo**. **MCPB: skipped. npm shim: included.**

### T-step breakdown (each = one commit)

Each step lists exact file contents/commands in `docs/build-plan.md`. Corrected slug `reassignai/plugins`; real tool names throughout.

- **T0 — Working spec.** Write `docs/build-plan.md`; add it (and `dist/`, `node_modules/`, `.DS_Store`) to `.gitignore`. *(the spec file itself is uncommitted; the `.gitignore` line is the only T0 commit.)*

- **T1 — Repo meta.** `LICENSE` (Apache-2.0, author **Pogled Naprej d.o.o.**) + `README.md` (what it is, the five forms, install snippets: `/plugin marketplace add reassignai/plugins`, `npx skills add reassignai/plugins`, Claude/ChatGPT copy-URL `https://reassign.app/api/mcp`). *Commit: "repo meta: license + readme".*

- **T2 — Skill manifest.** `skills/reassign-scheduling/SKILL.md` — frontmatter (`name: reassign-scheduling` = folder; pushy `description` ≤1024 chars, *what*+*when*, ending "Always call `get_schedule` before proposing or changing any times."; `license: Apache-2.0`; `allowed-tools` = the 10 real `mcp__reassign__*` tools; `metadata.version/author/category: productivity`; **no top-level `version`**) + body (always `get_schedule` first; 4 core workflows in real verbs — schedule: `schedule`→`confirm_schedule`+`undoToken`; find time: `get_schedule` free-slots→place by energy; review: `get_schedule` range→summarize by area; bulk: `write_events`/`delete_events`/`manage_categories`; "what not to do" + clinical guardrail). *Commit: "skill: canonical SKILL.md".*

- **T3 — Skill references.** `references/adhd-methods.md` (§4 catalog as **actions on the dial, not advice**, 🩺-tagged + guardrail), `references/workflows.md`, `references/taxonomy.md` (grounded in `../reassign/lib/mcp/tools/taxonomy.ts`). *Commit: "skill: references".*

- **T4 — Plugin form.** `.claude-plugin/plugin.json` (name `reassign`, repo `reassignai/plugins`) + `.claude-plugin/marketplace.json` (one plugin, `source: "./"`) + root `.mcp.json` (`mcpServers.reassign` http `https://reassign.app/api/mcp` — key `reassign` → `mcp__reassign__*`, matches `allowed-tools`). Local test `/plugin marketplace add ./` → `/plugin install reassign@reassign`. *Commit: "plugin: manifest + marketplace + .mcp.json".*

- **T5 — Registry manifest.** `server.json` (name **`app.reassign/reassign`**, status active, repo `reassignai/plugins`, `remotes:[streamable-http → reassign.app/api/mcp]`, no `packages[]`). *Commit: "mcp registry: server.json".*

- **T6 — npm shim.** `package.json` (`@reassign/mcp`, `mcpName: app.reassign/reassign` matching `server.json`, `bin.reassign-mcp`, `files:["bin"]`) + `bin/reassign-mcp.js` (spawn `npx -y mcp-remote ${REASSIGN_MCP_URL||…}`). *Commit: "npm shim: @reassign/mcp".*

- **T7 — Scripts.** `scripts/build.sh` (validate SKILL.md frontmatter + line budget, run gen-deeplinks; no MCPB) + `scripts/gen-deeplinks.js` (reads `.mcp.json` → Cursor base64 + VS Code url-encoded configs; live `connect.html` consumes output in the site repo). *Commit: "scripts: build + gen-deeplinks".*

- **T8 — CI.** `.github/workflows/publish-registry.yml` — on tag `v*`: `mcp-publisher publish --file ./server.json` (DNS/OIDC; registry is preview → on-tag only). *Commit: "ci: publish to mcp registry on tag".*

**Description-triggering note (during T2):** iterate the `description` so it fires on should-trigger phrases ("plan my day", "I feel overwhelmed", "time blocking") and stays quiet on near-misses.

## Follow-up checklist (credentialed / external — NOT executed in build phase)

Documented in `docs/build-plan.md` as the post-build sequence; each needs accounts/secrets/DNS:
1. Create/flip repo to **public** on GitHub; push; set topics (Step 2).
2. **DNS TXT** at `_mcp-registry.reassign.app`; `mcp-publisher login dns --domain reassign.app`; first `publish`.
3. `npm publish --access public` for `@reassign/mcp`.
4. Self-host marketplace already live via the repo; submit to community directory `clau.de/plugin-directory-submission`.
5. **Connectors Directory** submission — needs MCP-side gating in `../reassign` (every tool `title` + `readOnlyHint`/`destructiveHint`, OAuth 2.1+PKCE callbacks, live privacy policy, ≥3 prompts, 3–5 screenshots; `show_day` = interactive MCP App badge; `oauth-protected-resource` served from **reassign.app**). Flag: verify/add tool annotations + the clinical guardrail in `../reassign/lib/mcp/server.ts` instructions.
6. **#231** — `npx skills add reassignai/plugins` (and via reassign.ai once #35 ships); agenticskills.io; ChatGPT Apps; awesome-skills PRs (`VoltAgent/awesome-agent-skills`, `hesreallyhim/awesome-claude-code`, `travisvn/awesome-claude-skills`); confirm claudemarketplaces.com auto-crawl.
7. **reassignai#35** (site repo) — `web/connect.html` widget + `reassign.ai/.well-known/skills/index.json` pointing at `github:reassignai/plugins/skills/reassign-scheduling`.

## Open item to resolve during execution

The spec says the MCP `instructions` should be **generated from SKILL.md, never duplicated**, but `../reassign/lib/mcp/server.ts` currently hard-codes them and they **lack the clinical guardrail**. Out of scope for this repo, but we'll note a follow-up issue/change in `../reassign` to (a) add the guardrail and (b) keep instructions ↔ SKILL.md aligned.

## Verification

- **Skill validity:** `SKILL.md` frontmatter parses; `name` == folder; ≤~500 lines; `allowed-tools` exactly the 10 real `mcp__reassign__*` names.
- **Plugin:** `/plugin marketplace add ./` + `/plugin install reassign@reassign` succeeds locally; the connected `reassign` MCP tools (this session has them) resolve and a real `get_schedule` call returns the day.
- **server.json / package.json:** `mcpName` == `server.json` name; JSON valid (`node -e` / `jq`).
- **scripts/build.sh** runs clean.
- **End-to-end smoke:** with the plugin installed, ask "plan my afternoon" → skill triggers → `get_schedule` → `schedule`/`confirm_schedule` → `show_day` renders the dial.
