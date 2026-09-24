# Reviewing a past day (reflection & adherence)

Reassign isn't only forward-looking. A **past** day can be *reflected*: the user
(or you, on their behalf) records what actually happened against the plan —
which events they kept, skipped, or changed, and the real times — and freezes a
per-day **adherence** snapshot. That snapshot is what "how did yesterday go?",
the weekly review, and the stats all read from. This is the read + write surface
over that model.

The rule of thumb: **read** the reflection blocks to talk about a day,
**mark** events to record how they went, then **confirm** the day to freeze it.
Only a past day can be confirmed with `review_day`; `discard` works on any day.

## Reading: `review` and `reflect` blocks

Both ride the normal read tools — no separate fetch.

- **Per-day `review` block** (on `get_schedule`, one per requested day): present
  **only once the day has been confirmed**. Carries `reviewedAt` and
  `adherence`: `event` and `layer` scores (0 to 1), `plannedMinutes`,
  `unplannedMinutes`, and the `byArea` / `byActivityType` breakdowns (each
  `{areaId | activityTypeId, adherence, plannedMinutes}`). It's read off the **frozen**
  snapshot written at confirm time, not a live recompute, so it's stable. An
  unreviewed day has no `review` block.
- **Per-event `reflect` block** (on each event in `get_schedule` / `find_event`):
  present **only when that event has been touched** by a mark. Carries `status`
  and, only on a `changed` event with recorded times, `actualStart` /
  `actualEnd` (local datetimes; an overnight actual ends on the next day). An
  `added` event has no actual span: its own `start`/`end` is the actual time.
  An untouched event carries no `reflect` key.
- **Per-event `checklist` block** — not a reflection field, but part of the same
  story. A block broken into microtasks carries `{items:[{id,text,done}]}` with
  the **this-occurrence** done state (see SKILL.md §Microtasks), so
  a partly-worked block shows how far the user actually got. It is written
  independently of the reflect mark: a `kept` block may show zero ticked steps,
  and a fully-ticked block may carry no `reflect` state at all. Report both as
  they read; never infer one from the other, and never back-fill a mark from the
  step count.
- **`show_day`** appends a one-line adherence gloss for a reviewed day, so the
  rendered dial reads the same story.

So to answer "how did yesterday go?", pull the day with `get_schedule` and read
its `review` block plus each event's `reflect` status — don't reconstruct
adherence yourself.

## Marking: the `reflect` op on `write_events`

Record how a past event went with an op on the normal batch write — it rides the
same atomic plan→apply→undo path as `create`/`update`/`shift`, so marks
batch together and return an `undoToken`.

```
{ op: "reflect", id, status, actualStart?, actualEnd? }
```

- `status` — one of:
  - **`kept`** — happened as planned.
  - **`skipped`** — didn't happen.
  - **`changed`** — happened but differently. Pass `actualStart` / `actualEnd`
    (local datetimes `"YYYY-MM-DDTHH:MM"`, always as a pair) to record the real
    time; omit both to log it as changed with no exact time. An actual end after
    midnight is on the next day. Actual times equal to the plan store a bare
    `changed`.
  - **`added`** — unplanned but it happened. Its `actualStart` / `actualEnd`
    become the event's time (an `added` row is fully editable, since it never had
    a plan to deviate from).
- **Field-lock.** A mark on a *planned* event may set **only** its reflect status
  and actual time. Name, area, activity type, kind, and recurrence stay
  read-only through the reflect op — re-planning a past event would game its
  adherence. Enforced server-side; a reflect op that tries to rename is rejected.
  (Need to actually fix a past event's metadata? That's a normal `update`, a
  different intent.)
- **Recurring occurrences.** Marking one occurrence of a series (an id like
  `seriesId@YYYY-MM-DD`, copied from the read) targets that single occurrence,
  never the base series — so reflecting Tuesday's standup doesn't touch every
  standup. A `kept` or `skipped` mark takes no actual times.
- **Task-linked events mirror completion.** When the reflected event is linked
  to a task in a task app (Todoist, Google Tasks, Microsoft To Do, Linear,
  TickTick), the mark drives the task's lifecycle in the *same* atomic batch
  (one `undoToken`): **`kept` completes** the task, **`skipped` reopens** it.
  TickTick cannot reopen a task, so a `skipped` mark leaves it as it is.
  `changed` and `added` never touch the task. Task links are always one-offs,
  so this only applies to single events. Nothing extra to call — reflect as
  usual (see references/calendars.md §Providers).
- **No conflict check.** A reflect op records the past; it never claims a slot,
  so it won't conflict with anything.
- **A `kept` can arrive without you.** For up to 30 minutes past a block's end,
  Reassign's focus mode offers an "As planned" verb that records `kept` on the
  spot (on a recurring series, on that occurrence only). So an event may already
  carry a `reflect` state before the user sits down to review the day — read the
  block before re-asking how something went. This is independent of focus
  interval check-offs, which never write a status of their own (see SKILL.md
  §Focus intervals).

## Confirming / discarding the day: `review_day`

A whole day's confirm/reset is date-keyed, so it's its own tool rather than a
per-event op. One tool, two actions:

```
mcp__reassign__review_day { date, action: "confirm" | "discard" }
```

- **`action: "confirm"`** — "this is how it went." Freezes a per-day adherence
  snapshot over the day's events onto a day-review row; that row is exactly what
  `get_schedule`'s `review` block and the stats then surface. Re-confirming a day
  refreshes the snapshot (idempotent).
- **`action: "discard"`** — fully resets the day's reflection: deletes the
  day-review row, clears the kept/skipped/changed marks + actual times off the
  day's planned events, and removes events that were `added` only as part of the
  reflection. Use it to start a day's reflection over, or to drop one confirmed
  by mistake.
- Both go through the scoped write path and are **reversible** via the returned
  `undoToken` (the standard 30-minute window via `mcp__reassign__undo`). Because
  `discard` is destructive, confirm intent before discarding a day the user has
  already reviewed.

## Past-day review

`review_day` `confirm` rejects today and future dates with `validation`.
Choose a past date; an upgrade does not change that rule. `discard` works on
any day, also on today's check-offs. A `discard` of a day with no review and
no marks is `not_found`. Callers with active
trial/subscription access have no plan-based historical edit limit. Access
failures happen at the MCP gate (see references/limits.md).

## Putting it together — record a day

1. `get_schedule` for the day (a past date). Read the plan, and any existing
   `review`/`reflect` blocks if it was partly reviewed before — plus each block's
   `checklist`, which often already answers "how far did that get?" before you
   ask.
2. For each event the user reports on, send a `write_events` `reflect` op with
   the right `status` (+ actual times for `changed`/`added`). Batch them in one
   call — one op per event, since two ops on the same id in a batch are refused.
   If the user mentions steps they finished but never ticked, send those
   `checklist` `check` ops (by item id) as a **separate call** for the same
   reason (and on a recurring event, target that single occurrence). Tick before you mark: it
   keeps the option of parking the block open, which a reflect status closes.
3. `mcp__reassign__review_day { date, action: "confirm" }` to freeze the day's
   adherence snapshot.
4. Surface the `undoToken`. To summarize, read the now-present `review` block
   (adherence by area/type) and name one win + one concrete adjustment for the
   days ahead — turn the adjustment into a real edit when you can (see
   references/workflows.md §Weekly review).
5. **Carry the leftovers.** For a block that was skipped, or whose checklist is
   only partly ticked, `capture` its **unticked steps** as a new parked block's
   `checklist` (SKILL.md §Backlog). Use `capture`, not `park`: by this point the
   block carries a reflect status, and `park` refuses a reviewed event — so
   parking the whole block is only an option *before* step 2. Reflection
   records what *did* happen; the capture carries the remainder forward. Don't edit the step
   template to "clean up" a past day — the finished list is the record.

If the user wants to wipe a day's reflection and start over, that's
`review_day { date, action: "discard" }`.
