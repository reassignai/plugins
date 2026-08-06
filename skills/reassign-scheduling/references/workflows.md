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
   load. Name one win and one concrete adjustment — not a lecture. Where blocks
   carry microtasks, their `checklist` `done`/`total` is finer evidence than the
   reflect state alone — a repeatedly half-finished block is a sizing problem,
   not a discipline one, and the fix is a shorter block or fewer steps.
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
   than leaving a half-placed project. A project reaching past a capped plan's
   horizon (5 days for free, SKILL.md §Plan limits) takes the whole batch down
   with it: place what fits, and offer to park the rest as parked blocks with
   planned days — except that backlog is Pro too, so for a free user the honest
   answer is a shorter horizon, not a workaround.
4. Buffer between unlike chunks (adhd-methods.md §transition-buffers); inflate
   vague estimates 25–50% before committing.
5. `show_day` on the first project day so the user can see the plan land;
   surface the `undoToken`.

## Recurring-block setup

Repeating events are **Pro** (SKILL.md §Plan limits). A free or guest user's
`recurrence` is refused with `errorCode: "permission"` — offer the block as a
one-off and relay the upgrade message rather than retrying without the field.

1. `get_schedule` to confirm the slot is genuinely free on the cadence you want.
2. Create the block with `write_events` `create` plus `recurrence` — a preset
   (`daily`, `weekdays`, `weekly`, `biweekly`, `monthly`, `yearly`) or a raw
   RRULE. The RRULE form is what covers the cadences the presets don't:
   specific weekdays (`"FREQ=WEEKLY;BYDAY=MO,WE,FR"`) or the nth weekday of a
   month (`"FREQ=MONTHLY;BYDAY=2TU"` — every second Tuesday of the month). Add
   `recurrenceEnd` (`"YYYY-MM-DD"`, inclusive) for a fixed end, or omit for
   open-ended.
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

## Working a connected calendar (sync)

See references/calendars.md for the full surface. The flow:

1. `get_schedule` — if `integrations` is present, a calendar (e.g. Google) is
   connected. Read `sources[].status`, `defaultSyncCalendarId`, and each event's
   `source`/`calendar`/`readOnly` before touching anything.
2. Editing/creating an owned linked event (or one under the default sync
   calendar) via `write_events`/`schedule`, or deleting via `delete_events`,
   **propagates to the provider automatically** — no separate sync step. Surface
   the `undoToken` as usual.
3. **Never** edit, move, or delete a `readOnly` event (a calendar the user
   doesn't own — including a mirrored copy); the change reverts. Surface it as
   context only.
4. To explain an imported event's classification, point at the calendar's
   `defaultKind`/`defaultArea`/`defaultType`/`instructions` or the account
   `aiClassify`/`aiContext` in `integrations`. Don't set `syncTo` yourself —
   it's the dial picker's job (calendars.md §syncTo).

## Working the backlog (parked blocks)

Backlog is a **Pro feature** (see SKILL.md §Backlog). The tray holds *un-timed*
intentions; the write surface is `manage_backlog`, the read path is
`get_schedule` (`backlogCount` → `includeBacklog:true`/`backlogQuery`/
`backlogPlannedOn`). A parked block may carry a planned day or window — see
SKILL.md §Backlog.

1. **Capture without cramming.** The user rattles off tasks with no clear time,
   or the day's already full → `manage_backlog` `capture` ops (one batch, up to
   50) instead of forcing blocks onto the dial. Attach `durationHours` and
   area/type where known so a later placement sizes and classifies itself. A
   day named without a time ("sometime Friday") → capture with a planned
   day/window, not an invented start time (SKILL.md §Backlog). When the user
   spells a parked intention out in pieces ("call the garage, get a quote, book
   it in"), that's one block with `steps`, not three parked blocks — and the
   steps ride along when it's later placed. Capturing something the user found
   on a **page** is the one case that takes `sourceUrl` and `enrich` (SKILL.md
   §Captured from a page): pass the address so they get a clickable source chip,
   and let `enrich` name it, since a paragraph of page text is not an intention.
   Neither field belongs on a task they simply told you about.
2. **Plan the day from the tray.** On "plan my day" / filling free slots: one
   `get_schedule` read with `includeBacklog:true` — every item carries its
   planned day/window and `overdue` flag. Match parked blocks to `freeSlots` —
   planned-for-that-day and `overdue: true` blocks first, then oldest/biggest,
   demanding work into an energy peak, admin into the dip. Propose the
   placements; on yes, place each with a `schedule` op (`id`+`date`+`start`;
   add `recurrence` to repeat). Placing lifts it off the tray; revert one by
   parking it back (step 3).
3. **Park what slips.** Reviewing a day, a block was skipped or unfinished →
   offer to `park` it (`eventId`) back to the tray so the intention carries
   forward. Park only accepts a native/owned-calendar one-off that hasn't been
   reviewed; a recurring, sleep, reviewed, or not-owned event is refused with a
   reason — edit it on the dial instead. `schedule` and `park` are inverses, so
   an accidental placement or park is undone by its opposite. **Park before you
   mark:** an event carrying a reflect status is refused ("Reviewed events can't
   be parked"), so parking has to happen before the `reflect` op, not after. For
   a block that was *partly* done, `capture` its unticked steps as a new parked
   block's `steps` instead of parking the whole thing — and wherever `park` is
   refused (a reflected block, a recurring one, sleep, a non-owned calendar
   event), that capture is the only way to carry the remainder forward.
4. **Re-plan overdue blocks.** An `overdue: true` block outlived its planned
   window — offer to place it, re-plan it, or return it to Someday per
   SKILL.md §Backlog (a task-app-linked block's dates are provider-owned;
   see references/calendars.md).
5. **Prune.** Drop a dead intention with `remove` (reversible → `undoToken`);
   edit one in place with `update`.

## Breaking a block into microtasks

The user is stuck on a block, or asks what a big one actually involves. See
SKILL.md §Microtasks for the op contract; microtasks are **free** and work on any
event kind — only carrying leftovers into the backlog (step 5) hits the Pro gate.

1. `find_event` or `get_schedule` to resolve the block and — critically — read
   its existing `checklist`. An `items` edit **replaces the whole list**, so
   sending one built from memory silently deletes steps you didn't echo.
2. Propose the steps in chat first. Size them to the block: the first small
   enough to start in under five minutes (adhd-methods.md §chunking), roughly one
   per focus interval where the block carries a rhythm, and few enough to fit its
   length. Don't break down a block that isn't stalling.
3. On yes, one `write_events` op:
   `{op:"checklist", id, items:[{text}, …]}`. Preserve the `id` of any existing
   step you're keeping so its checked state survives. On a recurring block,
   decide scope explicitly and *say which you used*: `scope:"all"` (the default —
   every occurrence) or `scope:"this"` + `occurrenceDate` for one day. Surface the
   `undoToken`.
4. As the user works, tick steps in a **separate call**:
   `{op:"checklist", id, check:[…]}` — item ids or exact texts, always for one
   occurrence, and only when they say it happened. This can't be batched with
   step 3: two ops on the same event id in one `write_events` call are refused,
   and a checkoff on a block whose steps don't exist *yet* is refused too. Read
   the block back between the two if you need the new item ids — or just address
   the steps by their exact text.
5. When the block's day is reviewed, the unticked steps are the leftover
   intention — offer to `capture` them into the backlog (§Working the backlog,
   step 3) rather than letting them disappear. Backlog is **Pro**, so a free user
   gets an upgrade message here even though the microtasks themselves were free;
   relay it and leave the steps on the block.

For a **parked** block, the same idea uses `manage_backlog`'s `steps` (plain
strings, replaces the list) — there's no occurrence to tick against until it's
scheduled, and the steps carry over when it is.

## Reference & non-blocking events

1. The user wants something *visible but not blocking* — a partner's event they
   need to see (use `kind: "reference"`), or a backdrop like sleep/fasting/commute
   (`kind: "non-blocking"`). See references/calendars.md §Event kinds.
2. Create it with `write_events` `create` plus `kind`. A reference event keeps
   its hours free; a non-blocking band may overlap real work without conflict.
3. When scheduling work, treat both as free time — but don't schedule *into* a
   reference event unless the user asks, and respect a non-blocking band's intent
   (e.g. don't pile deep work over a "sleep" overlay just because it's allowed).
