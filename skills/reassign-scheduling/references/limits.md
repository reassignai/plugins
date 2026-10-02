# Subscription access and refusal codes

## Access is checked on every request

The current plan is `trial`, `pro`, or `none`. An active trial or subscription
allows MCP access, including recurrence, backlog, focus intervals, and
microtasks. There are no free/guest feature tiers or plan-based date horizons.

A grant can outlive subscription access. When the plan becomes `none`, reads
and writes are rejected **before any tool runs**: HTTP 403, JSON-RPC error
`code: -32600`, message “Reassign needs an active subscription.” This response
does not carry a tool error code. Relay it and explain that subscription
access must be restored. Shorter dates, one-off events, smaller batches, and
reconnecting do not bypass it. Other 403 responses can have different causes
(such as a rejected origin); do not treat every 403 as a subscription failure.
A revoked or invalid authorization instead needs authentication/reconnection.

`review_day` `confirm` still requires a past date. Today or a future day is a
`validation` error, not a reason to upgrade. `discard` works on any day.
A `discard` of a day with nothing recorded succeeds and has no `undoToken`.

## Tool refusal codes

| code | what it means | next action |
|---|---|---|
| `permission` | the plan does not include this (the Pro gate), or the item is provider-owned (a recurring task date) | relay the message; offer an upgrade only for the Pro gate |
| `scope` | the connection lacks this OAuth scope | reconnect with the needed permission |
| `read_only` | the event or requested field is not writable here | use the owning calendar/task app |
| `conflict` | the requested time is taken, or a short busy state blocks the write | choose another slot; retry a busy state once |
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
  reason?}`. A failed row has `error: {code, message, conflicts?,
  nearestSlots?}`. A `conflict` names each clash (the stored `id`, or
  `batchIndex` for a clash inside the same call) and offers `nearestSlots`.
- A whole-tool failure uses `isError:true` and one text block. The text is
  the JSON envelope `{"error": {"code", "message"}}`, also for the prose tool
  `show_day`. `_meta["reassign/error"].code`
  repeats the code when the client exposes it.
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
- A tool schema can list `llm_model` (required). It is an analytics field;
  the server does not enforce it. Set it to your model id. There is no
  `conversation_id`: a result has only its own content block.

## Batches and retries

`write_events`, `delete_events`, `manage_inbox`, and `manage_categories` are
atomic by default: a refused op prevents the batch from landing. The valid ops
of a rolled-back batch are `skipped` rows with a `reason`; only the failed ops
are `error` rows. With `partial:true`, inspect the rows and retain successes.
An op that is not valid is an `error` row with `validation`, not a failure of
the whole call. A batch whose writes landed is never rejected, also when the
read-back of a row fails (an `internal` row).
`schedule_events` and `confirm_schedule` are atomic by default too: one failed row
writes nothing, and the other rows are `skipped`. Set `partial:true` for
best effort. A replayed `schedule_events` row stays `ok` with `replayed: true`, because
an earlier call booked it. An `ok` proposal is not yet a booking.

For an uncertain write outcome, read the affected schedule or Inbox before
retrying. Do not blindly repeat creates. For `schedule_events`, preserve the exact
request and `requestId` (the server replays only by `requestId`, within 60
seconds); for feedback, preserve `submissionId` and content. A limited retry is
appropriate for a transient failure; if it fails again, keep the intended
change/draft and explain the blocker instead of looping. An expired proposal
needs a new `schedule_events`, not another `confirm_schedule`.

## Undo

`write_events`, `delete_events`, `schedule_events`, `confirm_schedule`,
`manage_inbox`, `manage_categories`, and `review_day` return one `undoToken`
and `expiresAt` (30 minutes) when they change data. A call that changed
nothing, or a rejected batch, has no token. The server records the undo after
the change lands. When that record fails, the change stays and the result has
no `undoToken`: tell the user that this change has no undo. `undo_changes` takes
`tokens` (1 to 20) and returns only per-token `results`, in the order of
`tokens`; an undo cannot itself be undone. It undoes the newest write first, so
the token order does not matter. A token reverts one time: a second `undo_changes` of
it is a `validation` row ("Nothing to undo for this token"). When a calendar
sync sends the same change at that moment, the undo row fails with `conflict`
and changes nothing: retry it after a moment.

A token is `stale` when a row that its write touched changed again later (a
move, a park, a delete, a sync edit), or when it would delete a category that a
later write uses. The undo then changes nothing. Tell the user, and offer to
edit the current state instead. A sync that only stores the same values again
does not make a token stale.

Each undo row result is `{reverted, restored, removed, voided,
occurrenceRestored?}`. The four counts are always there (0 when none);
`reverted` = `restored` + `removed` + `voided`. `occurrenceRestored` is there
only when it is above 0.
