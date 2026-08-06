# Plan limits and refusal codes

The detail behind SKILL.md §Plan limits and refusals: what a plan allows, and
how to read a refusal when it doesn't.

## Why a limit can appear mid-conversation

Every write re-checks the caller's **current** plan. That isn't the plan that
was in force when the user connected Reassign — a connection outlives it. The
common case: a user signs up, takes the no-card trial, connects during it, and
the trial lapses. The connection keeps working, the account reads `free`, and
calls that succeeded last month are now refused.

So don't infer a plan from what worked earlier in the conversation, and don't
treat a `permission` refusal as a bug or a transient failure. It's the account
speaking, and it can start speaking at any point.

## The windows

| | anonymous | free | trial / pro |
|---|---|---|---|
| Plan **ahead** to | tomorrow | 5 days out | no limit |
| Edit **back** to | yesterday | yesterday | no limit |
| Repeating events | ✗ | ✗ | ✓ |
| Backlog (`manage_backlog`) | ✗ | ✗ | ✓ |
| Focus intervals | ✗ | ✗ | ✓ |
| AI breakdown (`/microtasks`) | ✗ | ✗ | ✓ |

Microtasks written through `write_events`' `checklist` op are **free** — it's
only Reassign's own AI breakdown that's gated. That seam matters: for a free
user, propose the steps yourself and write them with the op.

**What's checked, and what isn't:**

- The check runs on the **resolved landing day**, not the day named in the op.
  A `shift` that walks an event past the horizon a day at a time is caught, and
  a `schedule` searching a window is judged on where it actually lands.
- Both write paths are gated. There's no getting at a day through `schedule`
  that `write_events` refuses, or the reverse.
- Exempt: `delete` and `clear` (a capped plan must still be able to remove
  something that sits beyond its window — otherwise a lapsed trial's events are
  stranded), `reflect` (which has its own, stricter past-day rule — see
  reflection.md), and `checklist` (annotating a block that already exists).
- Editing a **series** the user already owns isn't a past-day edit just because
  the series was created long ago. Renaming or re-timing a live weekly standup
  is allowed on any plan; the anchor date it expands from isn't where the edit
  lands.

**Recurrence is the surprising one.** These all count as asking for the feature
and are refused below Pro:

- `recurrence` on a `create` or `update`, and on `schedule`.
- `recurrenceEnd` on its own — it rewrites an existing rule's end date.
- `recurrenceEnd: "none"`, which makes an existing repeat open-ended.

`recurrence: "none"` does not — stopping a repeat is always allowed.

## The refusal codes

| code | what it means | what fixes it |
|---|---|---|
| `permission` | the account's plan doesn't include this | **upgrading** |
| `scope` | the connection was never granted this capability | re-connecting |
| `read_only` | the event lives on a calendar the user doesn't own | changing it where it lives |
| `conflict` | the time is already taken | a different slot |
| `not_found` | no such event, area, activity type or day | re-read, then retry |
| `ambiguous` | the reference matched more than one thing | narrow it, or ask |
| `validation` | the arguments are wrong, contradictory, or incomplete | fix them |
| `internal` | Reassign failed, not you | a retry may genuinely work |

The code rides alongside the message: per-op inside a batch result, and once for
a call rejected as a whole. Read it rather than the sentence — the message is
prose meant to be relayed, and it changes.

**The three authorization codes are not interchangeable.** They look alike and
have nothing in common but the shape of the failure:

- `permission` — the account. Upgrading fixes it. This is the only one where an
  upgrade prompt belongs.
- `scope` — the connection. Upgrading does nothing; the user has to re-connect
  and grant the capability.
- `read_only` — the resource. Neither upgrading nor re-connecting touches it.
  The event belongs to a calendar the user doesn't own, so it has to change
  where it lives.

Offering Pro to someone who already pays and merely touched a colleague's
calendar event is the expensive mistake here. Don't retry any of the three —
nothing about the call will differ on a second attempt.

`validation` and `permission` are also worth keeping apart on the same surface:
asking to reflect on *today* is `validation` (no plan allows it — a day isn't
reviewable until it's done), while asking about a day beyond a capped plan's
reach is `permission`. Only the second is an upgrade conversation.

## Handling a refusal well

1. **Relay the message.** It's written to be read to the user, and it names the
   boundary — "your plan currently ends 2026-08-12" is more useful than
   "that failed".
2. **Offer the version that fits.** A repeat refused → offer the one-off. A day
   beyond the horizon → offer the furthest day that works. A batch that
   straddles the horizon → place what fits and say what didn't.
3. **Don't retry, and don't work around.** Re-sending the same call, splitting
   it into smaller ops, or trying the other write path all hit the same gate.
4. **Batch semantics still apply.** `write_events` is atomic by default, so one
   refused op takes the whole batch down. `partial: true` lets the rest land —
   worth reaching for when a single day out of a week is the problem.
