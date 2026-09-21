# Extended workflows

Multi-step scenarios that go beyond the single-block flows in SKILL.md. Every
one starts with `mcp__reassign__get_schedule` to anchor `now`, the user's areas
and activity types, `userPreferences`, and the day's load. Use `write_events` for event edits, `delete_events` for removals, and
`manage_backlog` for parked intentions (≤50 ops per call, atomic unless
`partial:true`). Surface returned undo tokens and respect existing authorization.

## A manageable day plan

1. Read today's schedule and the Inbox if relevant, following pagination for a
   complete sweep. Keep the tool data out of the reply unless it helps a decision.
2. Protect fixed commitments and essential personal time. Use known priorities;
   if unclear, ask one question: “What would make today feel handled?” Avoid
   requiring the user to rank the entire Inbox.
3. Choose one essential outcome and a small optional list that fits remaining
   capacity. A planned date is not a hard deadline; verify consequences before
   promoting every overdue item. Keep blocked work untimed and name what it needs.
4. Present **Now / Next / Later**: one concrete starting action, the next
   commitment, and work safely left in the Inbox. Explain any consequential
   tradeoff. Execute within existing authorization; otherwise get the user's
   choice before moving commitments or placing proposed work.
5. Reserve only the work that fits, with transitions and room for interruptions.
   End with the next start/action and returned undo tokens. Offer the dial if
   visual orientation would help.

## Inbox triage and project organization

1. Accept a brain dump as-is. Capture without demanding categories or invented
   dates. Keep the user's wording unless asked to organize or clarify it.
2. Read existing items before merging or replacing them. For a large Inbox,
   process pages internally but present a small group at a time. Do not declare
   a complete triage while `nextBacklogOffset` still points to unread items.
3. Separate actionable work, ideas for later, and work waiting on someone or
   something. Use notes for dependencies or a waiting reason; MCP has no
   project/dependency/status tool. A planned date can represent a follow-up
   intention, but must not be described as an automatic reminder.
4. For a project, record the desired outcome and identify its next unblocked
   action. Keep same-sitting steps in `steps`/`checklist`; use distinct blocks
   only for work that needs distinct time. Avoid duplicating the project and
   all its steps as competing bookings. Reuse areas/types by their existing meaning.
5. Offer keep, clarify, plan, or remove only as needed. Do not prune merely
   because an item is old. Stop at the requested scope; an organized next action
   can be enough without redesigning the user's whole system.

## Restart after an interruption or an overrun

1. Re-read the current day: the live focus block may have changed its end.
   Orient with the current time and the next fixed commitment, without blame.
2. Preserve what the user says is done. Do not mark a missed block skipped or
   clear the day merely because its planned time passed.
3. Offer one small restart and, if needed, one alternative. Protect the next
   fixed commitment; shrink the remaining scope or park it instead of pushing
   every later event into the evening. Confirm a tradeoff not already authorized.
4. For unfinished work, preserve the next action. Park eligible unreviewed
   one-offs, or capture only the remainder of partly completed/reviewed work.
   Keep existing completion history; avoid duplicate captures on retries.
5. Apply the chosen changes, surface undo, and finish with what to do now.
   A reset is complete when the next step is usable, not when every open item
   has a new date.

## Weekly review

1. `get_schedule` with `from`+`to` spanning the past week (add `compact:true` so
   a 7-day pull stays readable).
2. Summarize planned time **by area** using area/type load, and actuals from
   recorded reflection. A planned block alone is not evidence it happened.
   Name one win and one concrete adjustment. Where blocks
   carry microtasks, their `checklist` `done`/`total` is finer evidence than the
   reflect state alone. A repeatedly half-finished block is a reason to adjust
   the plan, not evidence of poor discipline. Consider interruptions, unclear scope, or
   a dependency before suggesting a smaller next step or a different duration.
3. Turn the adjustment into an edit now: e.g. move a recurring deep-work block
   out of a trough (write_events `move`/`update`), or protect a slipping Q2
   block as recurring (see adhd-methods.md §eisenhower--q2-protection).
4. Schedule next week's review as a recurring anchor if one doesn't exist
   (`recurrence: "weekly"`) if the user wants that routine.

## Multi-day project chunking

1. `get_schedule` across the project's date range to see real free slots.
2. Decompose the project into next-actions (adhd-methods.md §chunking) — each a
   concrete event, the first small enough to start in under five minutes.
3. Place chunks into peak windows across the days in **one batch**: a single
   `write_events` call with several `create` ops. Atomic by default, so either
   the whole plan lands or nothing does — fix any rejected op and resend rather
   than leaving a half-placed project. Park work that does not fit available
   capacity with a planned day/window instead of cramming it into the dial.
4. Allow transitions and uncertainty (adhd-methods.md §Transition buffers).
   Label estimated durations; preserve explicit user constraints.
5. `show_day` on the first project day so the user can see the plan land;
   surface the `undoToken`.

## Recurring-block setup

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
   `defaultKind`/`defaultArea`/`defaultType` and account `aiClassify`/`aiRules`
   in `integrations`. Fixed kind policies are not exposed by MCP, so describe
   the visible facts without claiming a definite cause. Refer to the app
   calendar settings to inspect/change policy (calendars.md §Import policies).
   Set `syncTo` only for an explicitly requested destination resolved from
   the calendar list.

## Working the backlog (parked blocks)

The tray holds *un-timed*
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
2. **Plan the day from the tray.** Read `get_schedule` with
   `includeBacklog:true`; follow `nextBacklogOffset` with the same filters for
   a complete sweep. Items carry their planned day/window and `overdue` flag.
   Match parked blocks to `freeSlots` —
   inspect planned-for-that-day and overdue blocks, then prioritize by actual
   deadlines, importance, dependencies, and available capacity,
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
SKILL.md §Microtasks for the op contract; microtasks work on any event kind.

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
   step 3) rather than letting them disappear.

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
