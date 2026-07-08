# Reviewing a past day (reflection & adherence)

Reassign isn't only forward-looking. A **past** day can be *reflected*: the user
(or you, on their behalf) records what actually happened against the plan —
which events they kept, skipped, or changed, and the real times — and freezes a
per-day **adherence** snapshot. That snapshot is what "how did yesterday go?",
the weekly review, and the stats all read from. This is the read + write surface
over that model.

The rule of thumb: **read** the reflection blocks to talk about a day,
**mark** events to record how they went, then **confirm** the day to freeze it.
Only a past day is reviewable, and only within the user's editable window.

## Reading: `review` and `reflect` blocks

Both ride the normal read tools — no separate fetch.

- **Per-day `review` block** (on `get_schedule`, one per requested day): present
  **only once the day has been confirmed**. Carries `reviewed` (true),
  `reviewedAt`, and `adherence` — how closely actuals matched the plan, rounded,
  with per-area / per-activity-type breakdowns. It's read off the **frozen**
  snapshot written at confirm time, not a live recompute, so it's stable. An
  unreviewed day has no `review` block.
- **Per-event `reflect` block** (on each event in `get_schedule` / `find_event`):
  present **only when that event has been touched** by a mark. Carries `state`
  (the reflect status) and, when recorded, `actualStart` / `actualEnd` (+ hour
  forms and `actualDurationMinutes`). Cross-midnight actuals read past `24:00`
  like planned times, and the spill onto the following morning is mapped for you.
  An untouched event carries no `reflect` key.
- **`show_day`** appends a one-line adherence gloss for a reviewed day, so the
  rendered dial reads the same story.

So to answer "how did yesterday go?", pull the day with `get_schedule` and read
its `review` block plus each event's `reflect` state — don't reconstruct
adherence yourself.

## Marking: the `reflect` op on `write_events`

Record how a past event went with an op on the normal batch write — it rides the
same atomic plan→apply→undo path as `create`/`update`/`move`/`shift`, so marks
batch together and return an `undoToken`.

```
{ op: "reflect", id, status, actualStart?, actualEnd?, actualEndNextDay? }
```

- `status` — one of:
  - **`kept`** — happened as planned.
  - **`skipped`** — didn't happen.
  - **`changed`** — happened but differently. Pass `actualStart` / `actualEnd`
    (`"HH:MM"`, 24-hour) to record the real time; omit them to log it as changed
    with no exact time. Set `actualEndNextDay: true` if the real end crossed
    midnight.
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
  `seriesId@YYYY-MM-DD`) targets that single occurrence's exception child, never
  the base series — so reflecting Tuesday's standup doesn't touch every standup.
- **Todoist-linked tasks mirror completion.** When the reflected event is linked
  to a Todoist task, the mark drives the task's lifecycle in the *same* atomic
  batch (one `undoToken`): **`kept` closes** the task, **`skipped` reopens** it.
  `changed` and `added` never touch the task. Task links are always one-offs, so
  this only applies to single events, never a recurring series. Nothing extra to
  call — reflect as usual and the task stays in sync (see
  references/calendars.md §Providers).
- **No conflict check.** A reflect op records the past; it never claims a slot,
  so it won't conflict with anything.

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

## The editable-past window (entitlement)

Reflection is bounded by the user's plan, the same window that governs editing
the past:

- **Free / guest** — yesterday only.
- **Pro** — deeper history.

A `reflect` mark **or** a `review_day` confirm/discard on a day **outside** that
window — including today or a future day, which simply aren't reviewable yet — is
**rejected with a clear message** (often an upgrade prompt for the deeper-past
case). Relay that message to the user; don't retry the call or try to work around
it.

## Putting it together — record a day

1. `get_schedule` for the day (a past date). Read the plan, and any existing
   `review`/`reflect` blocks if it was partly reviewed before.
2. For each event the user reports on, send a `write_events` `reflect` op with
   the right `status` (+ actual times for `changed`/`added`). Batch them in one
   call.
3. `mcp__reassign__review_day { date, action: "confirm" }` to freeze the day's
   adherence snapshot.
4. Surface the `undoToken`. To summarize, read the now-present `review` block
   (adherence by area/type) and name one win + one concrete adjustment for the
   days ahead — turn the adjustment into a real edit when you can (see
   references/workflows.md §Weekly review).

If the user wants to wipe a day's reflection and start over, that's
`review_day { date, action: "discard" }`.
