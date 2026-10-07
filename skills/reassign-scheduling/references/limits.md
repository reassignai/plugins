# Subscription access and refusal codes

## Access is checked on every request

The current plan is `trial`, `pro`, or `none`. An active trial or subscription
allows MCP access, including recurrence, backlog, focus intervals, and
microtasks. There are no free/guest feature tiers or plan-based date horizons.

A grant can outlive subscription access. When the plan becomes `none`, reads
and writes are rejected **before any tool runs**: HTTP 403, JSON-RPC error
`code: -32600`, message “Reassign needs an active subscription.” Its error
`data` is `{code:"permission", feature:"mcp"}`; this is a transport refusal,
not a tool-result envelope. Relay it and explain that subscription
access must be restored. Shorter dates, one-off events, smaller batches, and
reconnecting do not bypass it. Other 403 responses can have different causes
(such as a rejected origin); do not treat every 403 as a subscription failure.
A revoked or invalid authorization instead needs authentication/reconnection.

`write_events` `reflect` and `review_day` `confirm` require a past date in the
user's timezone, even if today's event has ended. Today or a future day is a
`validation` error, not a reason to upgrade. `discard` works on any day.
A `discard` of a day with nothing recorded returns `noop:true`, empty
`updated` / `deletedIds` arrays, and no `undoToken`.

## Tool refusal codes

| code | what it means | next action |
|---|---|---|
| `permission` | a plan gate or an action restriction, such as parking a recurring, sleep, reviewed, or not-owned event | relay the message; offer an upgrade only for a plan gate |
| `scope` | the connection lacks this OAuth scope | reconnect with the needed permission |
| `read_only` | the event or requested field is not writable here, including a recurring task's planned date/window | use the owning calendar/task app |
| `conflict` | the requested time is taken, a category name or an id is already in use, or a short busy state blocks the write | time: choose another slot. Name: reuse the id from the message, or pick another name. Busy state: retry once |
| `not_found` | the referenced event, item, area, activity type, day, or token does not exist | re-read and resolve the target |
| `stale` | an `undo_changes` token whose rows changed again after the write | the undo changed nothing; tell the user and do not retry the token |
| `validation` | arguments are invalid, contradictory, or use an old field name or format | correct them |
| `rate_limited` | an abuse/request budget was exceeded | keep the draft and wait as directed |
| `internal` | a backend operation failed | inspect the result before a bounded retry |

There is no `ambiguous` error code. `find_event` reports an event tie as the
`ambiguous: true` field; ask the user which event they meant. That flag does
not cover its `inbox` matches; resolve any unclear Inbox target too.
`batch_rejected` is only the top-level code of a rejected batch whose failed
rows disagree; a batch row never carries it. `unauthorized` is a REST code; a
tool result never carries it.

Do not offer an upgrade for `scope`, `read_only`, or `rate_limited`. Repeating
the same denied call cannot fix account access, scopes, or ownership.

## Where the code lives

- A batch row is `{index, status: "ok" | "error" | "skipped", result?, error?,
  reason?, warnings?}`. A failed row has `error: {code, message, conflicts?,
  nearestSlots?, issues?, feature?, conflictingRows?, conflictingRowsTruncated?,
  usage?, reassignTargets?}`.
  A `conflict` names each clash (the stored `id`, or
  `batchIndex` for a clash inside the same call) and offers `nearestSlots`.
- A successful event-write row can carry `warnings:["classification_pending"]`
  when it queued AI classification and the account permits it. The write landed,
  but eligible area, activity type, kind, or energy fields may change after the
  reply. Native creates protect their kind, including default `blocking`, and
  explicit non-null categories; manual choices stay protected (taxonomy.md).
  Re-read when those values matter; the warning does not promise a change or
  give a completion time.
- A whole-tool failure uses `isError:true` and one text block. The text is
  the JSON envelope `{"error": {"code", "message", ...}}`, with optional
  diagnostics below, also for the prose tool `show_day`.
  `_meta["reassign/error"].code` repeats the code when the client exposes it.
- Arguments that fail a tool's input schema never reach Reassign. The MCP SDK
  refuses them as prose `Input validation error: ...`, with no code and no
  `_meta`. Correct the arguments. For `get_schedule`, `includeWeather:true`
  and `includeEnergy:true` each need `from` = `to`; `weatherLocation` needs
  `includeWeather:true`.
- A rejected batch (no op applied) is the second `isError:true` shape. Its
  text is `{"error": {"code", "message"}, "timezone"?, "results"}`, so the rows
  are still there. `error.code` is the code that the failed rows share, or
  `batch_rejected` when they differ. `_meta` carries a code only when the rows
  share one. Mixed failures have no single remedy: inspect each row.
- HTTP/JSON-RPC transport failures happen outside these tool envelopes.
- Current tool schemas include neither `llm_model` nor `conversation_id`. Model
  capture is disabled, and a result has only its own content block. Refresh
  stale tool schemas and omit these fields from calls.

### Structured diagnostics

- `issues` has up to 20 `{path, message, expected?}` entries. A path is an
  array of field names/indexes relative to the failed op; the row's `index`
  identifies that op. Top-level issues use paths relative to the body/query.
  `expected` names a known type or format, such as `uuid`, `YYYY-MM-DD`, or
  `YYYY-MM-DDTHH:MM`; semantic failures may omit it. Use these details to fix
  the named input instead of retrying the same call. SDK-level schema errors
  still use the prose response described above.
- A caller-supplied `write_events` create `id` must be a UUID. Omit it for a
  server-generated UUID. Invalid IDs fail per-op validation before writing,
  also with `dryRun:true`. Occurrence IDs and checklist item IDs keep their
  own formats; copy them from reads.
- Entitlement refusals can include `feature`, such as `calendar_sync`, `mcp`,
  or REST's `api`. An Inbox capture with an explicit list and no sync access
  is `permission` with `feature:"calendar_sync"`; an unusable list is
  `validation`. A `permission` code alone does not establish a plan problem.
- Stale undo stamp mismatches can include `conflictingRows` and
  `conflictingRowsTruncated`; see §Undo.
- A refused `manage_categories` delete of an entry that items use can include
  `usage` and `reassignTargets`; see taxonomy.md §Deleting safely.

## Batches and retries

`write_events`, `delete_events`, `manage_inbox`, and `manage_categories` are
atomic by default: a refused op prevents the batch from landing. The valid ops
of a rolled-back batch are `skipped` rows with a `reason`; only the failed ops
are `error` rows. With `partial:true`, inspect the rows and retain successes.
An op that is not valid is an `error` row with `validation`, not a failure of
the whole call. A batch whose writes landed is never rejected, also when the
read-back of a row fails (an `internal` row).

Applied `write_events` / `delete_events` results read stored state after the
whole batch commits. A later op, such as a future-series split, can affect an
earlier op's returned event. These are not intermediate per-op snapshots or
a guaranteed common transaction-time snapshot. Dry runs do not read committed
results.

### Check event ops without applying them

`write_events` accepts optional top-level `dryRun:true` with the usual `ops`.
Use it when checking a proposed batch would help; it is not a required step for
an already authorized write. It still needs the connection's `events:write` scope.

- The server plans the ops against existing events and each other, without
  changing data or issuing an undo token. A valid op returns `status:"skipped"`
  with `reason:"Dry run: this op is valid and was not applied."`; it has no
  created/updated event result.
- Invalid ops retain their usual `error` rows, including `conflicts` and
  `nearestSlots` when applicable. All-valid dry runs succeed with skipped rows;
  any failed op makes the dry run an `isError:true` rejected batch. Inspect the
  reasons and errors instead of treating every skipped row as a rollback.
- To apply the authorized ops, send them again without `dryRun:true`. The
  server checks current conflicts again; a dry run reserves no time and has no
  commit token. `delete_events` and `manage_inbox` do not accept this flag.

### Retry after an uncertain result

For an uncertain write outcome, read the affected schedule or Inbox before
retrying. Do not blindly repeat creates. `write_events` has no `requestId`
replay field. For feedback, preserve `submissionId` and content. A limited
retry is appropriate for a transient failure; if it fails again, keep the
intended change/draft and explain the blocker instead of looping.

## Undo

`write_events`, `delete_events`, `manage_inbox`, `manage_categories`, and
`review_day` return one `undoToken` and `expiresAt` (30 minutes) when an undo
receipt is recorded. A call that changed nothing, or a rejected batch, has no
token. Missing undo fields alone do not prove a no-op. The server records undo
after the change lands. When that record fails, the change stays and the result
has no `undoToken`: tell the user that this change has no undo. `undo_changes` takes
`tokens` (1 to 20) and returns only per-token `results`, in the order of
`tokens`; an undo cannot itself be undone. It undoes the newest write first, so
the token order does not matter. A token reverts one time: a second `undo_changes` of
it is a `validation` row ("Nothing to undo for this token"). When a calendar
sync sends the same change at that moment, the undo row fails with `conflict`
and changes nothing: retry it after a moment.

A token is `stale` when a row that its write touched changed again later (a
move, a park, a delete, a sync edit), or when it would delete a category that a
later write uses. An undo that brings back a hidden shared default is also
stale when a visible category now has its name. The undo then changes nothing and leaves
the token active.
Tell the user, and offer to edit the current state instead. A sync that only
stores the same values again does not make a token stale.

Stamp mismatches include up to 50 `conflictingRows: [{entity, id, reason}]`
from the user's receipt. Reasons are `changed`, `deleted`, or `newly_present`;
`conflictingRowsTruncated:true` means more blockers were omitted. Use those
rows to explain what prevents undo. A stale token from before stamp tracking
has no invented row IDs; not every stale refusal has this list.

Each undo row result is `{reverted, restored, removed, voided,
occurrenceRestored?}`. The four counts are always there (0 when none);
`reverted` = `restored` + `removed` + `voided`. `occurrenceRestored` is there
only when it is above 0.

## Stale connector catalogs

Fresh `tools/list` is authoritative for the deployed catalog. `get_schedule`
requires `from` + `to`; `send_feedback` requires `reports`. Old date/default
forms and standalone feedback fields are not aliases. If the connector still
lists removed names such as `schedule`, `confirm_schedule`, `manage_backlog`,
or `undo`, refresh its catalog and compare it with fresh discovery.

Server discovery identifies the contract release and, when available, the
serving commit. Use that identity to distinguish a deployment mismatch from a
stale host catalog. A version change does not itself refresh the host's cache;
do not send removed tool names as a workaround.
