# Extended workflows

Multi-step scenarios that go beyond the single-block flows in SKILL.md. Every
one starts with `mcp__reassign__get_schedule` to anchor `now`, the user's areas
and activity types, `userPreferences`, and the day's load. All edits flow
through `write_events` (create/update/move/shift/clear ops, ≤50 per call, atomic
unless `partial:true`); every removal and most writes return an `undoToken` —
surface it.

## Weekly review

1. `get_schedule` with `from`+`to` spanning the past week (add `compact:true` so
   a 7-day pull stays readable).
2. Summarize where time actually went **by area**, using each day's area/type
   load. Name one win and one concrete adjustment — not a lecture.
3. Turn the adjustment into an edit now: e.g. move a recurring deep-work block
   out of a trough (write_events `move`/`update`), or protect a slipping Q2
   block as recurring (see adhd-methods.md §eisenhower--q2-protection).
4. Schedule next week's review as a recurring anchor if one doesn't exist
   (`recurrence: "weekly"`), per the Zeigarnik shutdown pattern.

## Multi-day project chunking

1. `get_schedule` across the project's date range to see real free slots.
2. Decompose the project into next-actions (adhd-methods.md §chunking) — each a
   concrete event, the first small enough to start in under five minutes.
3. Place chunks into peak windows across the days in **one batch**: a single
   `write_events` call with several `create` ops. Atomic by default, so either
   the whole plan lands or nothing does — fix any rejected op and resend rather
   than leaving a half-placed project.
4. Buffer between unlike chunks (adhd-methods.md §transition-buffers); inflate
   vague estimates 25–50% before committing.
5. `show_day` on the first project day so the user can see the plan land;
   surface the `undoToken`.

## Recurring-block setup

1. `get_schedule` to confirm the slot is genuinely free on the cadence you want.
2. Create the block with `write_events` `create` plus `recurrence` — a preset
   (`daily`, `weekdays`, `weekly`, `biweekly`, `monthly`, `yearly`) or a raw
   RRULE (e.g. `"FREQ=WEEKLY;BYDAY=MO,WE,FR"`). Add `recurrenceEnd`
   (`"YYYY-MM-DD"`, inclusive) for a fixed end, or omit for open-ended.
3. Editing one instance of a recurring event? Set `scope`:
   - `this` — only this occurrence (needs the occurrence date),
   - `future` — this and all later occurrences,
   - `all` — the entire series (the default).
   Be explicit about scope when moving or updating, so the user isn't surprised
   that "just today" rippled across the series.
4. To stop a series repeating, `update` it with `recurrence: "none"`.

## Bulk reshuffle of a crowded day

1. `get_schedule` for the day; identify what's mis-placed against energy/load.
2. One `write_events` call mixing `move` (to a new time), `shift` (nudge by a
   delta), and `update` (rename / re-area / re-type) ops — batched so the day
   re-flows atomically.
3. Re-insert buffers that the reshuffle collapsed.
4. Clear anything obsolete with `delete_events` (`clear` a day or `date`..`to`
   range; `delete` by id). Reversible → `undoToken`.
5. `show_day`; surface the `undoToken`.

## Find-and-fix an event without an id

1. `find_event` by name (scope with `from`/`to`, `areaId`, `activityTypeId`,
   `timeOfDay`). If it returns `ambiguous`, present the candidates and let the
   user pick rather than guessing.
2. Apply the change with `write_events` using the resolved id.
