# Subscription access and refusal codes

## Access is checked on every request

The current plan is `trial`, `pro`, or `none`. An active trial or subscription
allows MCP access, including recurrence, backlog, focus intervals, and
microtasks. There are no free/guest feature tiers or plan-based date horizons.

A grant can outlive subscription access. When the plan becomes `none`, reads
and writes are rejected **before any tool runs**: HTTP 403, JSON-RPC error
`code: -32600`, message “Reassign needs an active subscription.” This response
does not carry a tool `errorCode`. Relay it and explain that subscription
access must be restored. Shorter dates, one-off events, smaller batches, and
reconnecting do not bypass it. Other 403 responses can have different causes
(such as a rejected origin); do not treat every 403 as a subscription failure.
A revoked or invalid authorization instead needs authentication/reconnection.

`review_day` confirm/discard still requires a past date. Today or a future day
is a `validation` error, not a reason to upgrade.

## Tool refusal codes

| code | what it means | next action |
|---|---|---|
| `permission` | account access does not permit the action | relay the access message |
| `scope` | the connection lacks this capability | reconnect with the needed permission |
| `read_only` | the event or requested field is not writable here | use the owning calendar/task app |
| `conflict` | requested time is occupied | choose another slot |
| `not_found` | the referenced event, area, activity type, or day does not exist | re-read and resolve the target |
| `ambiguous` | more than one resource matches | narrow the reference |
| `validation` | arguments are invalid or contradictory | correct them |
| `rate_limited` | an abuse/request budget was exceeded | keep the draft and wait as directed |
| `internal` | a backend operation failed | inspect the result before a bounded retry |

Do not offer an upgrade for `scope`, `read_only`, or `rate_limited`. Repeating
the same denied call cannot fix account access, scopes, or ownership.

## Where the code lives

- Individual failed batch items use `errorCode` alongside the error message.
- A whole-tool failure uses `isError:true`, explanatory text, and
  `_meta["reassign/error"].code`. Clients may not expose that metadata to the
  model; if absent, relay the visible message without inventing a code.
- A rejected batch has a top-level metadata code only when its failed items
  agree on one. Mixed failures have no single remedy: inspect each item.
- HTTP/JSON-RPC transport failures happen outside these tool envelopes.

## Batches and retries

`write_events`, `delete_events`, and `manage_backlog` are atomic by default:
a refused op prevents the batch from landing. With `partial:true`, inspect the
per-item results and retain successes. An item marked `skipped` was not applied.
`schedule` and `confirm_schedule` report independent indexed results; an `ok`
proposal is not yet a booking. Do not assume every item failed from one error.

For an uncertain write outcome, read the affected schedule or Inbox before
retrying. Do not blindly repeat creates. For `schedule`, preserve the exact
request and `request_id`; for feedback, preserve `submissionId` and content.
A limited retry is appropriate for a transient failure; if it fails again,
keep the intended change/draft and explain the blocker instead of looping.
An expired proposal needs a new `schedule`, not another `confirm_schedule`.
