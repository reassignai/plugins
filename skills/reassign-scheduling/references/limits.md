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

## Tool refusal codes

| code | what it means | next action |
|---|---|---|
| `permission` | the plan does not include this (the Pro gate), or the item is provider-owned (a Todoist/TickTick date) | relay the message; offer an upgrade only for the Pro gate |
| `scope` | the connection lacks this OAuth scope | reconnect with the needed permission |
| `read_only` | the event or requested field is not writable here | use the owning calendar/task app |
| `conflict` | the requested time is taken, or a short busy state blocks the write | choose another slot; retry a busy state once |
| `not_found` | the referenced event, item, area, activity type, day, or token does not exist | re-read and resolve the target |
| `validation` | arguments are invalid, contradictory, or use an old field name or format | correct them |
| `rate_limited` | an abuse/request budget was exceeded | keep the draft and wait as directed |
| `internal` | a backend operation failed | inspect the result before a bounded retry |

There is no `ambiguous` error code. `find_event` reports a tie as the
`ambiguous: true` field; ask the user which event they meant. `batch_rejected`
and `unauthorized` are REST codes; a tool result or batch row never carries
them.

Do not offer an upgrade for `scope`, `read_only`, or `rate_limited`. Repeating
the same denied call cannot fix account access, scopes, or ownership.

## Where the code lives

- A batch row is `{index, status: "ok" | "error" | "skipped", result?, error?,
  reason?}`. A failed row has `error: {code, message, conflicts?,
  nearestSlots?}`. A `conflict` names each clash (the stored `id`, or
  `batchIndex` for a clash inside the same call) and offers `nearestSlots`.
- A whole-tool failure uses `isError:true`, explanatory text, and
  `_meta["reassign/error"].code`. Clients may not expose that metadata to the
  model; if absent, relay the visible message without inventing a code.
- A rejected batch (no op applied) has a top-level code only when its failed
  rows agree on one. Mixed failures have no single remedy: inspect each row.
- HTTP/JSON-RPC transport failures happen outside these tool envelopes.

## Batches and retries

`write_events`, `delete_events`, `manage_backlog`, and `manage_categories` are
atomic by default: a refused op prevents the batch from landing. The valid ops
of a rolled-back batch are `skipped` rows with a `reason`; only the failed ops
are `error` rows. With `partial:true`, inspect the rows and retain successes.
An op that is not valid is an `error` row with `validation`, not a failure of
the whole call. A batch whose writes landed is never rejected: it keeps its
`undoToken`, also when the read-back of a row fails (an `internal` row).
`schedule` and `confirm_schedule` report independent indexed rows; an `ok`
proposal is not yet a booking. Do not assume every row failed from one error.

For an uncertain write outcome, read the affected schedule or Inbox before
retrying. Do not blindly repeat creates. For `schedule`, preserve the exact
request and `requestId` (the server replays only by `requestId`, within 60
seconds); for feedback, preserve `submissionId` and content. A limited retry is
appropriate for a transient failure; if it fails again, keep the intended
change/draft and explain the blocker instead of looping. An expired proposal
needs a new `schedule`, not another `confirm_schedule`.

## Undo

`write_events`, `delete_events`, `schedule`, `confirm_schedule`,
`manage_backlog`, `manage_categories`, and `review_day` return one `undoToken`
+ `expiresAt` (30 minutes) when they change data. A call that changed nothing,
or a rejected batch, has no token. `undo` takes `tokens` (1 to 20) and returns
only per-token `results`; an undo cannot itself be undone. When a calendar
sync is sending the same change at that moment, the undo row fails with
`conflict` and changes nothing: retry it after a moment.
