#!/usr/bin/env node
// Keeps the repo's two independent version trains in lockstep.
//
//   plugin  — the skill and every manifest that advertises it. Four files now
//             that the Agent Plugins manifest sits beside the Claude one, and a
//             client reading the wrong manifest sees the wrong version.
//   package — the npm shim and the MCP registry entry. Tagged `v*`, and
//             publish-npm.yml already verifies package.json against the tag.
//
// Deliberately separate: the shim's version tracks what npm has published, not
// what the skill says, so conflating them would break that tag check.
//
//   node scripts/version.mjs                → print both
//   node scripts/version.mjs check          → exit 1 on any disagreement
//   node scripts/version.mjs set plugin 1.9.0
//
// Edits in place with a targeted replace rather than a JSON round-trip: these
// files are hand-formatted (inline `keywords`, one-line plugin entries) and
// reserialising them would churn every line of the diff.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

/** A `"version": "…"` field. Each target file holds exactly one, which the
 *  match count below enforces — a second one would mean this rewrites the
 *  wrong thing silently. */
const JSON_VERSION = /("version"\s*:\s*")([^"]+)(")/g;
/** The same field in SKILL.md's YAML frontmatter (`  version: "1.9.0"`). */
const YAML_VERSION = /^(\s*version:\s*")([^"]+)(")/gm;

const TRAINS = {
  plugin: {
    what: "skill + plugin manifests",
    files: [
      ["plugin.json", JSON_VERSION],
      [".claude-plugin/plugin.json", JSON_VERSION],
      [".claude-plugin/marketplace.json", JSON_VERSION],
      ["skills/reassign-scheduling/SKILL.md", YAML_VERSION],
    ],
  },
  package: {
    what: "npm shim + MCP registry entry (git-tagged)",
    files: [
      ["package.json", JSON_VERSION],
      ["server.json", JSON_VERSION],
    ],
  },
};

function read(path, pattern) {
  const text = readFileSync(join(ROOT, path), "utf8");
  const hits = [...text.matchAll(pattern)];
  if (hits.length !== 1) {
    throw new Error(
      `${path}: expected exactly 1 version field, found ${hits.length}`,
    );
  }
  return { text, version: hits[0][2] };
}

/** Every file of a train, not just the first — reporting one file's version as
 *  the train's is how drift stays invisible. */
function survey(files) {
  return files.map(([path, pattern]) => [path, read(path, pattern).version]);
}

function check() {
  let failed = false;
  for (const [train, { what, files }] of Object.entries(TRAINS)) {
    const found = survey(files);
    const versions = new Set(found.map(([, v]) => v));
    if (versions.size === 1) {
      console.log(`✓ ${train} ${found[0][1]} — ${what}`);
      continue;
    }
    failed = true;
    console.error(`✗ ${train} disagrees — ${what}`);
    for (const [path, version] of found) console.error(`    ${version}  ${path}`);
  }
  if (failed) {
    console.error("\nFix with: node scripts/version.mjs set <train> <version>");
    process.exit(1);
  }
}

function set(train, version) {
  const target = TRAINS[train];
  if (!target) {
    console.error(`unknown train "${train}" — expected one of: ${Object.keys(TRAINS).join(", ")}`);
    process.exit(1);
  }
  if (!/^\d+\.\d+\.\d+(?:-[\w.]+)?$/.test(version)) {
    console.error(`"${version}" is not a semver version`);
    process.exit(1);
  }
  // Read every file before writing any: a throw partway through the loop would
  // otherwise leave the train half-bumped — the exact drift this script prevents.
  const staged = target.files.map(([path, pattern]) => {
    const { text, version: was } = read(path, pattern);
    return [path, was, text.replace(pattern, `$1${version}$3`)];
  });
  for (const [path, was, text] of staged) {
    writeFileSync(join(ROOT, path), text);
    console.log(`  ${was} → ${version}  ${path}`);
  }
  console.log(`✓ ${train} now ${version}`);
}

const [command, ...rest] = process.argv.slice(2);
try {
  if (!command) {
    for (const [train, { what, files }] of Object.entries(TRAINS)) {
      const seen = [...new Set(survey(files).map(([, v]) => v))];
      const drift = seen.length > 1 ? "  ← drift, run `check`" : "";
      console.log(`${train}\t${seen.join(" / ")}\t${what}${drift}`);
    }
  } else if (command === "check") {
    check();
  } else if (command === "set") {
    if (rest.length !== 2) {
      console.error("usage: node scripts/version.mjs set <plugin|package> <version>");
      process.exit(1);
    }
    set(...rest);
  } else {
    console.error(`unknown command "${command}" — expected: check | set`);
    process.exit(1);
  }
} catch (err) {
  console.error(err.message);
  process.exit(1);
}
