---
name: reassign-scheduling
description: >-
  Plan, organize, edit, and review work and personal time in Reassign's circular
  calendar. Use for day/week planning, Inbox capture and triage, project next
  actions, microtasks, recurring routines, calendar sync, and reflection. Help
  with overwhelm, task initiation, interruptions, and ADHD-friendly time
  management through concrete scheduling changes. Use weather and energy
  context when relevant to a plan. Read get_schedule before proposing or
  changing times. Requires the Reassign MCP; not for diagnosis or treatment.
license: Apache-2.0
allowed-tools: mcp__reassign__get_schedule mcp__reassign__find_event mcp__reassign__schedule mcp__reassign__confirm_schedule mcp__reassign__write_events mcp__reassign__delete_events mcp__reassign__manage_categories mcp__reassign__manage_backlog mcp__reassign__undo mcp__reassign__show_day mcp__reassign__review_day mcp__reassign__get_weather mcp__reassign__get_energy mcp__reassign__send_feedback
metadata:
  version: "1.11.0"
  author: Pogled Naprej d.o.o.
  category: productivity
---

# Reassign scheduling

You help the user run their day on a circular 24-hour calendar. You are a
scheduling copilot: apply practical time-management
methods (see references/adhd-methods.md) as concrete edits to the dial, not as
advice you recite.

## Help the user start and stay organized

- Lead with one concrete next action. For overwhelm, show **Now / Next / Later**
  and at most two useful alternatives; avoid a menu of productivity methods.
- Reuse known preferences. Ask one short question only when a missing priority,
  deadline, or constraint changes the plan. A brain dump need not arrive sorted.
- Separate capture from commitment: an Inbox item is an intention, a planned
  day/window is flexible, and a timed block reserves capacity. Do not turn every
  captured task into today's obligation or treat `plannedDate` as a hard deadline.
- Fit work around fixed commitments, sleep, meals, travel, and transitions.
  Free slots are capacity, not a target to fill. Label uncertain estimates and
  leave recovery room; learn from the user's actual durations when available.
- Use neutral language: “still open” or “needs a new slot,” not “failed again.”
  Overdue does not automatically mean highest priority. For low-capacity days,
  protect the essential outcome and reduce scope before packing the day tighter.
- Act on clear authorization without another approval loop. Offer a concrete
  proposal when selecting priorities or making consequential tradeoffs the user
  has not decided. A request to capture is not permission to schedule everything.
- Keep completion visible: say what changed, the next action, and how to undo.
  Never infer completion from elapsed time or alter the user's record to tidy it.

For daily planning, Inbox triage, project organization, and interruption recovery,
see references/workflows.md. Use references/adhd-methods.md selectively.

## Always

- Call `mcp__reassign__get_schedule` before proposing or changing times — in a
  single call it anchors `now`, the user's `areas`, `activityTypes`,
  `userPreferences`, existing events, and the day's free slots + area/type
  load. `from` and `to` are required; use the same date for one day.
  It also reports `backlogCount` (parked, un-timed blocks); pass
  `includeBacklog:true` for the items, then `backlogQuery` to find one by name
  or `backlogPlannedOn` for the blocks planned for a day (see §Backlog).
- A date is `YYYY-MM-DD`. A time is a local datetime `YYYY-MM-DDTHH:MM` in the
  top-level `timezone`, with no seconds and no offset. Every span is `start` +
  `end`; an overnight span ends on the next day. A slot to midnight ends at
  `<next day>T00:00`. The event's day is the date part of `start`.
- Copy ids and values from a read into a write as they are. The API rejects
  unknown keys, old field names, and other formats; it does not coerce them.
- Surface returned undo tokens — each write that changes data returns one
  `undoToken` + `expiresAt` (30 minutes) for `mcp__reassign__undo`. Do not
  invent a token.
- Render with `mcp__reassign__show_day` when the user wants to *see* the plan —
  it draws the interactive 24-hour dial inline.
- Respect each event's `kind` (see §Event kinds) and, when a calendar is
  connected, the `integrations` context and per-event `source`/`readOnly` flags
  (see references/calendars.md). Never edit or delete a `readOnly` event.

## Access and refusals

MCP requires an active trial or subscription. The current plan is checked on
**every request**, including reads: `trial` and `pro` have access; `none` is
rejected before a tool runs. A lapsed trial does not become a free account.
There are no separate feature gates or plan-based date horizons for callers
with access: recurrence, backlog, focus intervals, and microtasks are included.
`review_day` `confirm` still requires a past date.

- A subscription rejection is HTTP 403 with “Reassign needs an active
  subscription.” Relay it; a one-off, shorter date range, or different tool
  cannot bypass it. Reconnecting does not restore subscription access.
- Tool refusals carry a per-row `error.code` or a whole-tool
  `_meta["reassign/error"].code` when the client exposes metadata. Distinguish
  account `permission`, connection `scope`, and resource `read_only`; they need
  different remedies. `rate_limited` means wait, not upgrade.
- See references/limits.md for response shapes, mixed batches, and retries.

## Event kinds

Every event has a `kind`: `blocking`, `non_blocking`, or `reference`. Each read
event carries it. Set it with `kind` on a `write_events` create/update, a
`schedule` request, or a `manage_backlog` capture/update.

- **blocking** (default) — occupies time, cannot overlap; counts in
  `loadByArea`/`loadByActivityType` and consumes free slots.
- **non_blocking** — an overlay band (sleep, fasting, commute) that may overlap
  anything and never conflicts. It does *not* consume free slots; its minutes
  surface separately as `nonBlockingLoadByArea`/`nonBlockingLoadByActivityType`.
  Use it when the user wants something present on the dial without it blocking
  scheduling.
- **reference** — see-only (a memo): something the user wants to *view* but
  isn't doing — a kid's training they drop off at, an event mirrored from a
  partner's calendar. Its hours stay free for scheduling. Don't move, delete, or
  schedule work *into* it unless explicitly asked.

When choosing a kind, ask whether the user is *doing* the thing (blocking),
*living through* it as a backdrop (non-blocking), or just *watching* it
(reference). Don't make everything blocking.

## Focus intervals (pomodoro)

Keep focused work as **one blocking event**, with optional
`focusIntervals:{focusMin, breakMin}` on `write_events` create/update (integers:
focus 5–180, break 1–60). `null` on update removes the rhythm. A
`non_blocking` or `reference` event rejects it with `validation`. Scheduled
breaks are derived within that event; never create duplicate break events for
the rhythm.

Reads return `focusIntervals: {focusMin, breakMin}` and a separate
`completedFocusIntervals` count (omitted when 0). The count is not necessarily
a completed prefix, and does not imply checklist completion or reflection.
Live pauses can bank break time and extend `end`: trust the returned count.
Re-read before editing around an active block because focus mode can retime it.

Use the user's preferred rhythm; offer a short start if beginning is difficult,
and leave continuous focus available. The app's `/focus` page runs any blocking
block and manages saved rhythms; MCP can set a block's cadence, but cannot
manage presets or run a timer. See references/focus.md for pause, retiming,
reflection, and live-mode details.

## Microtasks (steps inside a block)

An event can carry an ordered **microtask checklist** — the steps that make the
block up ("Outline", "Draft the intro", "Send it"). This is the ADHD chunking
move made concrete without fragmenting the dial: the block stays *one* block, and
the steps live inside it. Microtasks work on **any** `kind`, not only blocking
blocks, and use the same subscription access as the other tools.

The model mirrors the focus-interval pair: a **template** — the steps, shared
across a recurring series — and a per-occurrence **done set** — the ticks,
belonging to one day. Every rule below follows from that split.

- **Read.** A block that carries steps serializes a `checklist` block:
  `{items: [{id, text, done}]}`. There is no `done`/`total` count; count the
  items yourself. It's omitted on a block with no
  steps — read absence as "none", not an error. Keep the item `id`s from the
  read; they're how you edit or tick one step without disturbing the others.
- **Set the steps** with `write_events`' `checklist` op and `items`:
  `{op:"checklist", id, items:[{id?, text, done?}]}` — up to 100 steps, text
  ≤200 chars. A `create` op can also carry a starter `checklist: {items}`.
  It **replaces the whole list**, so add, rename, remove, and reorder are all
  expressed as the resulting list: read the current items first, then send the
  full list you want kept. Keep an existing item's `id` to preserve its checked
  state; omit `id` to add a new step. `items: []` clears the checklist.
- **Tick steps off** with the same op and `check` / `uncheck`:
  `{op:"checklist", id, check:["<item id>"]}`. Each entry must be an item `id`
  from a read; text does not match. An unknown id fails the op with
  `not_found` — re-read rather than guessing. Ticking a block that has no steps
  yet is refused, so the `items` edit must land **first, in an earlier call**.
- **One op per event, per call.** Two ops targeting the same event id in one
  batch are refused outright ("already modified by an earlier op"). So a
  `checklist` op carries *either* `items` *or* `check`/`uncheck` — never both —
  and setting steps then ticking one means **two sequential `write_events`
  calls**, not two ops in one. The same rule blocks pairing a `checklist` op with
  a `reflect` or `update` op on that event: send them one call at a time.
- **Addressing.** The `checklist` op takes no `scope`. A bare series id edits
  the template of the whole series; a `seriesId@YYYY-MM-DD` id edits one day's
  steps only. Ticking off is **always** per-occurrence: on a recurring series,
  use the `seriesId@YYYY-MM-DD` id from the read, so Monday's ticks can never
  land on Tuesday. A checkoff on a bare series id is refused.
- **Local metadata, never synced.** Steps don't touch the block's name, time, or
  kind, and they never propagate to **any** provider — not a calendar and not a
  task app, whose own subtasks are a separate thing Reassign doesn't mirror. A
  calendar-linked block carries steps safely; a `readOnly` event still can't be
  written at all.
- **Independent of reflect and focus intervals.** Every step being done does not
  mark the block `kept`, and a `kept` mark doesn't tick steps. Don't infer either
  from the other — report what the `checklist` block actually says.
- **Parked blocks carry steps too**, as a `checklist` with no `done` state
  (there's no occurrence to tick against until they're placed) — see §Backlog.
- **Write steps directly.** Reassign also has an in-app AI breakdown
  (`/microtasks`), but you can propose the steps here and write them with the
  checklist op. There is no need to invoke a second AI workflow.

### Planning with microtasks

- **Break down what's stalling, not everything.** Reach for steps when a block
  is vague, dreaded, or big enough that starting is the hard part ("Taxes",
  "Write the proposal") — the first step should be small enough to begin in under
  five minutes (adhd-methods.md §chunking). A 30-minute errand doesn't need a
  checklist, and steps on everything are just noise.
- **Size the steps to the block.** Roughly one step per focus interval on a block
  that carries a rhythm, and few enough that the list fits the block's length —
  a 45-minute block with twelve steps is a plan to fail.
- **Respect authorization.** If asked to add steps, write a small, concrete
  list; otherwise propose it first. Do not ask again after the user has agreed.
- **Never tick on the user's behalf.** Only `check` a step when the user says it
  happened. A speculative tick corrupts the record they're going to reflect on.
- **Leftover steps are the next intention.** When a block's steps are partly
  done, the unticked ones are what carries forward — offer to `capture` them
  into the backlog rather than letting them vanish with the day.

## Calendar sync

When the user has connected a source, `get_schedule` returns an `integrations`
block and events carry sync fields. A source is a calendar (Google Calendar,
Outlook) or a task app (Google Tasks, Microsoft To Do, Linear, TickTick,
Todoist), whose lists or projects surface as calendars. The essentials:

- An event's `source` is `"reassign"` (native) or the provider: `google`,
  `microsoft`, `google_tasks`, `microsoft_todo`, `linear`, `ticktick`, or
  `todoist`. A linked event carries its home `calendarId` (absent = the
  default calendar, `null` = dial only) and any `mirrorCalendarIds`. An event
  with `readOnly: true` is from a calendar the user doesn't own — **never edit
  or delete it**; the change would silently revert.
- Editing or creating a calendar-linked event (or any event under the user's
  default calendar) through `write_events`/`schedule`, and deleting one
  through `delete_events`, **propagates to the provider automatically** — exactly
  like editing on the dial. You don't call a separate sync tool.
- `integrations` carries connected `sources` (`provider`, `status`,
  `calendars`), the account-wide AI classifier (`aiClassify`, plus the compiled
  `aiRules`) and the `defaultCalendarId` that new events sync to. Each calendar
  carries `id`, `name`, `writable`, an optional `timezone`, and its import
  policy: `area`, `activityType`, and `kind`, each `{mode:"automatic"}` or
  `{mode:"fixed", ...}`. See references/calendars.md for import explanations,
  the full surface, and calendar targets.

## Reflection (how a past day went)

A **past** day can be reflected: marking each event with what actually happened,
then freezing a per-day adherence snapshot. The surface (see
references/reflection.md for the full detail):

- **Read.** For a day already reviewed, `get_schedule` returns a per-day
  `review` block (`reviewedAt`, and `adherence` — how closely actuals
  matched the plan, with per-area/type breakdowns). Each marked event carries a
  `reflect` block (`status`, plus `actualStart`/`actualEnd` only on `changed`).
  `show_day` adds a one-line adherence gloss. An unreviewed day has no `review`
  block.
- **Mark.** Record how each event went with `write_events`' `reflect` op:
  `{op:"reflect", id, status}` where `status` is `kept` (happened as planned),
  `skipped` (didn't happen), `changed` (happened differently — pass
  `actualStart`/`actualEnd` as local datetimes; an overnight actual ends on the
  next day), or `added` (unplanned but happened — its
  `actualStart`/`actualEnd` become its time). A mark on a planned event only sets its reflect status +
  actual time; you cannot rename/re-area it through a reflect op (that would game
  adherence). Marks ride the same atomic, undoable batch as other ops.
- **Freeze / reset.** After marking, call `mcp__reassign__review_day` with
  `{date, action:"confirm"}` to freeze the day's adherence snapshot ("this is
  how it went") — that's what the `review` block and stats then read. Re-confirm
  to refresh. `{action:"discard"}` fully resets the day: it clears every mark and
  removes events added only as part of the reflection. Both return an
  `undoToken`.
- `review_day` `confirm` requires a **past** date. Today or a future day is
  `validation` (no subscription lifts it, so do not offer an upgrade).
  `discard` works on any day, also on today's check-offs. A `discard` of a
  day with no review and no marks is `not_found`. There is no
  plan-based editable-past window for callers with access.

## Weather

When the user has a city (saved, or guessed from their timezone), `get_schedule`
and `show_day` include a one-line `weather` headline for a single requested day
or today — temp range, condition, rain window, sunset. That's enough to schedule
around; read it before placing outdoor or weather-sensitive work. The headline is
omitted for a pure multi-day range (one line can't represent it) and for a
city-less user.

- Reach for `mcp__reassign__get_weather` only when an outdoor or weather-
  sensitive plan needs the hourly detail (a run, commute, picnic, gardening — the
  exact dry/daylight window), or when the user explicitly asks about the weather.
  It returns a compact day overview plus a part-of-day breakdown, not an hourly
  dump. Indoor plans don't need it — the headline already covers a quick glance.
- It defaults to today and the user's city. Pass `date` (ISO `YYYY-MM-DD`) for
  another day, or `location` (a city/place name) to ask about somewhere else —
  `location` wins over the saved city, so "weather in London?" works regardless.
- Use it to bias placement: steer a run into a dry, daylight window; flag when an
  outdoor block lands in forecast rain and offer to move it. It's read-only and
  never changes the plan on its own.

### Planning with weather

Use the forecast to place work, not to moralize about it:

- **Outdoor / exposed blocks** (run, commute, errands, sports, a walk meeting)
  → the dry, daylight window. If one already sits in forecast rain, flag it and
  offer a move. This is logistics — be concrete, not preachy.
- **Daylight is a resource, not just a constraint.** A morning outdoor block in
  the daylight window doubles as a circadian/energy anchor — pair it with the
  user's peak window (see references/adhd-methods.md §Chronotype / energy
  placement) rather than treating sunrise/sunset as trivia.
- **Don't invent weather-mood rules.** There's no reliable "do deep work when
  it's raining" theory — the effect is tiny and personal. Only act on a pattern
  the *user* has stated ("gray days help me focus"); never prescribe one.

## Energy

The user has a forecast daily **energy curve** — when they'll be most alert —
built from their logged sleep (a two-process circadian + sleep-pressure model),
any tracked caffeine/intakes, and personalized over time from the energy levels
they log. Unlike weather, it is **not** folded into `get_schedule`/`show_day`:
`mcp__reassign__get_energy` is the only way to read it.

- Reach for `mcp__reassign__get_energy` when placement should follow alertness
  (where to put focus/deep work vs. admin/errands) or when the user asks how
  their energy looks or when they're at their best. It returns a compact day
  overview — the peak/dip windows, today's current reading + its drivers, and how
  calibrated the estimate is — not a per-hour dump.
- It defaults to today and the user's own data. Pass `date` (ISO `YYYY-MM-DD`)
  for another day: a future day forecasts from habitual sleep; a past day is
  reflection-aware (it reads the actual logged sleep) but energy is still
  *modeled, not measured* — don't present it as a record of how the day felt.
- It needs at least one logged night of sleep. With none, it returns a short
  nudge to log sleep first — relay that, don't fabricate a curve.
- It's read-only and never changes the plan. The energy curve is also an opt-in
  **dial layer** (off by default): `show_day` paints it only when the user has
  enabled the energy layer, but `get_energy` always reads it (calling it is
  explicit intent).
- **The in-app curve can differ, by design.** A user can fold a menstrual-cycle
  rhythm into the energy layer in the app; that term is deliberately absent
  from `get_energy` — cycle data is health data that never leaves the app, on
  any AI surface. So the curve you read may sit slightly off the dial an
  opted-in user sees. Treat the gap as intended, not an error, and never ask
  for, infer, or record cycle data through any tool.

### Planning with energy

- **Peak → demanding work.** Put deep/focus work and the hardest task ("the
  frog") in a morning or evening **peak**; steer admin, errands, and low-stakes
  work into the post-lunch **dip**. This replaces guessing from the user's
  stated chronotype when real data exists — see references/adhd-methods.md
  §Chronotype / energy placement.
- **Flag, don't silently place.** If demanding work already sits in a known
  dip, flag it and offer a move into the nearest peak (a SKILL.md "what not to
  do" rule).
- **Pair with weather and daylight.** A morning outdoor block in the daylight
  window doubles as a circadian anchor — line it up with the morning peak rather
  than treating the two layers separately.

## Backlog (parked blocks)

The **backlog** is the user's inbox of *parked blocks* — intentions captured
without a time yet ("wash the car", "call the dentist"). It's the ADHD
capture/externalize move made concrete: get a task out of the head and onto a
tray without committing to a slot. A parked block can also carry a **planned
day** (`plannedDate`) or a flexible window (`plannedDate` + inclusive
`plannedUntil` — "sometime Fri–Sun"): still untimed, but grouped under that day
in the tray instead of Someday. It uses the same active-trial/subscription
access as the rest of MCP.

- **Read** through `get_schedule`: `backlogCount` reports the true tray total.
  Pass `includeBacklog:true` for items (top of tray first, one page at a time).
  Each item is `{id, name, kind, areaId, activityTypeId}`, plus `notes`,
  `sourceUrl`, `durationMinutes`, `plannedDate`, `plannedUntil`, and
  `checklist` when set. There is no `overdue` flag: compare the end of the
  planned day/window with `now` yourself. The filters need `includeBacklog:true`:
  `backlogQuery` finds items by name, and `backlogPlannedOn` (ISO date) narrows
  to the blocks whose planned day or window covers that day. They compose. An
  **overdue block never matches a today/future filter** (its window has
  passed); use an unfiltered read when looking for overdue work. There is no
  separate read tool — don't call `manage_backlog` just to look.
- **Pagination.** Item reads return `nextBacklogOffset` (null when complete),
  and `backlogMatchedCount` only when a filter is set. Follow a non-null offset
  with `backlogOffset` and the same filters until the requested scope is
  covered; the first page is not the whole Inbox. After a tray write, restart
  pagination because its order may change.
- **Write** through `mcp__reassign__manage_backlog` (`ops`, ≤50, atomic by
  default — pass `partial:true` for best-effort). Each op is one of:
  - `capture` — create a parked block (`name`, optional `notes`,
    `durationMinutes` (5–1440), `kind` (default `blocking`),
    `areaId`/`activityTypeId`, an optional `plannedDate` or
    `plannedDate`+`plannedUntil` window, optional `checklist`, and optional
    `sourceUrl`/`enrich` — see §Captured from a page).
  - `update` — edit one by `id`. An omitted field keeps its value; `null` on
    `areaId`/`activityTypeId` clears the link. `plannedDate: null` moves it back
    to Someday (clearing any window end); `plannedUntil: null` collapses the
    window to its single day; a set `plannedUntil` must fall after the planned
    day. On a **task-app-linked** block, the planned date follows the provider
    rules in references/calendars.md: Google Tasks, Microsoft To Do, and Linear
    sync one date both ways (no window); a Todoist or TickTick date is refused
    with `permission` and must be changed in that app.
    `sourceUrl: null` clears a stale link off a block the user is keeping.
  - `remove` — delete one by `id`.
  - `schedule` — **place** a parked block (`id`) on the dial at `start` (a
    local datetime; its `durationMinutes` sizes it; pass `recurrence` to repeat)
    and lift it off the tray. The new event takes the item's `kind`. It obeys
    the event rules: a span of 5 minutes to 168 hours, and an overlap with a
    blocking event fails with `conflict` plus `nearestSlots`. An earlier `park`
    in the same call frees its time.
  - `park` — **move** a dial event (`id`) back into the tray; the item keeps the
    event's `kind`. Works only on a native or owned-calendar one-off that hasn't
    been reviewed; a recurring, sleep, reviewed, or not-owned event is refused
    with a reason (edit it on the dial instead). Parking a calendar-linked event
    removes its calendar copy but remembers the calendar, so re-scheduling
    republishes there.
- **Microtasks on a parked block.** `capture` and `update` both take
  `checklist: {items:[{id?, text}]}` (≤50 items, ≤200 chars each). It
  **replaces the whole list**, so send every item you want kept (keep the ids
  from the read); `items: []` clears them. Template-only — a parked block has no
  occurrence, so there's nothing to tick off until it's scheduled onto the dial
  (§Microtasks). The steps survive the park ↔ place round-trip, so breaking a
  parked intention down now isn't wasted work — but **ticks don't**: parking a
  half-done block returns every step un-ticked, since the tray has no
  occurrence to hold a done-set.
- Every call that writes returns one `undoToken`; `undo` reverses the whole
  call. `schedule` and `park` are also **inverses** for use after the window.

### Captured from a page

A parked block can record **where it came from**. Both fields are for material
grabbed off a real page — not for an intention the user typed or dictated.

- **`sourceUrl`** — the http(s) address the block was captured from, on
  `capture` and `update`. It's provenance, not a note: the user sees a source
  chip they can click, and Reassign never parses it. `get_schedule` echoes it
  back. Only ever point it at the page the text actually came from — anything
  else is a link the user clicks expecting one thing and gets another.
- **`enrich: true`** on a `capture` — Reassign's own AI cleans the capture up
  before it's saved: a better `name`, an estimated `durationMinutes`, and any
  `checklist` items the captured text spells out. The result lists the filled
  fields in `enriched`. **Raw captures only.** It may *rename*
  the block, and a name the user chose has to stand, so never set it on
  something they said. Fields you send win; only the name can be replaced.
  It never fails a capture — no AI entitlement, a model outage, a
  timeout, or more than ten enriched captures in one batch all just land the
  block exactly as you sent it, so don't retry a capture that came back plain.

### Planning with backlog

Treat the tray as a first-class part of the plan, not a side list:

- **Capture instead of cram.** When a task has no clear time, the day is
  already full, or the user is rattling off more than fits, `capture` it to the
  backlog rather than forcing a block onto the dial. Parking reduces overwhelm —
  it's the externalize step, not a failure to schedule. When the user names a
  day but no time ("sometime Friday", "over the weekend"), capture with a
  `plannedDate` (or window) instead of inventing a start time — penciling in a
  day is a commitment level of its own.
- **Plan-the-day pulls from the tray — planned-for-today first.** When filling
  free slots or the user says "plan my day", read `includeBacklog:true` and
  follow pagination for the complete tray with its planned fields. Offer blocks planned for
  today and overdue ones first, then by importance, dependencies, and fit, honoring
  area/type + energy (demanding parked work → a peak; admin → the dip). Don't
  place silently; propose, then `schedule`. Reserve `backlogPlannedOn` for the
  direct question ("what did I plan for Friday?").
- **Surface overdue intentions.** A block whose `plannedUntil` (or
  `plannedDate`, without a window) is before today slipped past its planned
  window. Check whether it still matters, then offer to place it
  today, re-plan it (`update` with a new `plannedDate`), send it back to
  Someday (`plannedDate: null`), or `remove` it — the user's call.
- **Review sweeps leftovers back.** When a planned block was skipped or didn't
  finish, offer to `park` it for later instead of dropping it — the intention
  survives without pretending it happened. (Reflection records what *did*
  happen; parking carries forward what still needs to.) Order matters: `park`
  refuses an event that already carries a reflect status, so park it *before*
  marking the day, or `capture` a fresh block afterwards instead.

## Workflow: schedule a block

1. `mcp__reassign__get_schedule` (`from` = `to` = the day) to anchor `now` and
   load.
2. Resolve any relative phrasing yourself ("tomorrow", "after lunch") into
   structured fields, then call `mcp__reassign__schedule` with `requests[]`.
   Each request has `name`, an integer `durationMinutes` (5–1440), and **one**
   of two forms. The tool does no date parsing.
   - An exact `start` (local `"YYYY-MM-DDTHH:MM"`). A free `start` books at
     once; a taken one returns alternatives.
   - A window: `earliest` + `latest` (local datetimes, at most 24 hours apart;
     the window may cross midnight). "Tomorrow afternoon" →
     `earliest "<date>T13:00"`, `latest "<date>T18:00"`.
   A request with both forms is rejected, and so is `autoCommitBest` with
   `start`. The search skips time that is already past. Attach an area/type by
   `areaId`/`activityTypeId`, set `kind`, add `notes`, and make it repeat with an
   RRULE `recurrence`.
3. A window request returns ranked `options` (each a `start`/`end` span) plus
   a `commitToken` and `expiresAt`, **also when only one slot fits**. Only
   `autoCommitBest:true` books the top option at once. Use it for an authorized
   routine booking; leave it off to compare options.
4. Pass a `requestId` so a retry doesn't double-book. Only `requestId` replays
   (60 seconds); a request without one is always new (references/limits.md).
5. For proposals, show the best fit and one useful alternative, then
   `mcp__reassign__confirm_schedule` with `items[]` = `{token, choice}`
   (0-based; omit `choice` for the best fit). It re-checks conflicts before
   committing. A token expires at `expiresAt` (about 10 minutes); an expired
   token fails with `not_found` and needs a fresh `schedule` call. Pass
   `render:true` to repaint an open dial in the same call. Recurring proposals
   are checked across a bounded conflict horizon, not forever.
6. Allow transitions and uncertainty using the user's preferences and past
   durations; suggest a modest buffer where needed (references/adhd-methods.md).
7. Inspect each `results[]` row by its 0-based `index`: a request may book,
   propose, or fail independently. A booked row has `result.event`. Do not
   rebook successful rows after a partial failure. A call that booked something
   returns one `undoToken`; it deletes the events that call booked and voids its
   open proposals. A `confirm_schedule` call returns its own `undoToken`.

## Workflow: find time

1. `mcp__reassign__get_schedule` — `days[].freeSlots` plus area/type load give
   availability; there is no separate free-slot tool.
2. Place demanding work in the user's stated peak window and admin/shallow work
   in the trough.
3. If `backlogCount > 0`, read the tray (`includeBacklog:true`) and offer to
   fill the slot from a parked block before inventing new work — blocks
   planned for that day first, then by importance and fit, matched to the window
   (§Backlog).
4. Offer the slot; on yes → `mcp__reassign__schedule` →
   `mcp__reassign__confirm_schedule` (or `manage_backlog` `schedule` op to place
   a parked block directly).

## Workflow: review the day / week

1. `mcp__reassign__get_schedule` for the range (`from`+`to`). For a day already
   reviewed, read its `review` block (adherence) and each event's `reflect`
   block alongside the plan. A block's `checklist` adds the finer grain — the
   `done` items show how far into it the user actually got, which a bare
   `kept`/`skipped` can't (§Microtasks).
2. Summarize where time went by area; name one win and one concrete adjustment.
   Partly-done blocks are the most useful material here: "you got 3 of 5 steps
   into the proposal" beats "you skipped it".
3. If the user wants to **record** how a past day went (not just read it), mark
   its events with `write_events`' `reflect` op, then freeze it with
   `mcp__reassign__review_day {date, action:"confirm"}` — see §Reflection and
   references/reflection.md. Surface the `undoToken`.
4. Carry skipped or unfinished work forward (§Backlog): `park` *before*
   marking, because a reflected event is refused ("Reviewed events can't be
   added."), or `capture` after. For a partly done block, `capture` only the
   **unticked steps** as the new block's `checklist`.

## Workflow: reshuffle / bulk edits

- Batch create/update/shift via `mcp__reassign__write_events` (`ops`, ≤50,
  atomic by default — pass `partial:true` to allow per-op failures). `update`
  with a new `start`/`end` moves or resizes an event, also to another day; a
  lone `start` keeps the duration, and a lone `end` keeps the start. `shift`
  nudges by `byMinutes`. Reference areas/types by id; on `update`, `null` clears
  the link and an omitted key keeps it.
- Recurring events: a bare series id addresses the whole series; the
  `seriesId@YYYY-MM-DD` id from a read addresses one occurrence; add
  `scope:"future"` to an occurrence id for that occurrence and every later one.
  `scope` has no other value. Do not build the `@date` yourself; copy it from a
  read. A changed occurrence keeps the id of its **original** date, also after
  it moved to another day. The series id is the part before `@`.
- Changing the repeat itself (`recurrence`/`recurrenceEnd`) needs the bare
  series id or an occurrence id with `scope:"future"`. On a single occurrence
  it is refused. Series-level fields (`calendarId`, `mirrorCalendarIds`,
  `sourceUrl`) are refused on one occurrence unless they equal the current
  value. `recurrence:null` turns a series back into a one-off. When a new rule
  skips the anchor day, the result carries `firstOccurrence`.
- Target each event id at most once per call; `render:true` repaints a dial.
- Remove events or clear a range via `mcp__reassign__delete_events` (`delete`
  by `id` with the same id rules, or `clear` with `from`+`to`).
- Create areas/types with `mcp__reassign__manage_categories` before you
  reference them; un-timed blocks go through `manage_backlog` (§Backlog).
- `mcp__reassign__find_event` finds an event by name; on `ambiguous: true`, ask.
- For recurring masters (rule, anchor span, next occurrence, override counts)
  pass `includeSeries:true` → get_schedule returns a `series` array.
- Reflection (§Reflection) and microtasks (§Microtasks) use the `reflect` and
  `checklist` ops of the same tool.

## What not to do

- Preserve transition time between unlike activities unless the user prefers otherwise.
- Never schedule deep work in a known trough without flagging it.
- Never tick a microtask off unless the user said it happened, and never send an
  `items` edit built from memory — read the current list first, or you'll delete
  the steps you forgot to echo.
- Never give clinical advice — no medication timing, dosing, sleep medication,
  or diagnostic claims. These are widely used lifestyle strategies, not
  treatment, and not a substitute for evaluation by a qualified clinician.

## Methods

Apply references/adhd-methods.md as ACTIONS on the dial, not advice you recite.
Start with implementation intentions and externalized time. See
references/workflows.md for extended multi-step scenarios,
references/taxonomy.md for how areas and activity types map to the dial,
references/calendars.md for connected-calendar sync, event kinds, and mirroring,
references/reflection.md for reviewing how a past day actually went, and
references/limits.md for subscription access and how to read a refusal.

## Feedback

If a tool loops, needs a workaround, or the user hits a limitation in Reassign
itself, report it with `mcp__reassign__send_feedback`. Send one concise report
per issue with `kind` (`bug`/`idea`/`other`) and `message`; avoid private schedule
contents. Feedback is delivered to the team through transactional email.
Use an optional UUID `submissionId`; retry with the same UUID and identical
content within 24 hours. A new report needs a new UUID. On `rate_limited`, keep
the draft and wait as directed; on a transient delivery failure, retry the same
submission without claiming it was sent until the tool confirms acceptance.
The tool returns `{}` when it accepts the report.

The server can also list `get_more_tools {context}`. It is not a Reassign
tool: it records a missing-capability report (the first 500 characters of
`context`) and changes no data. Call it only when no tool fits the task. Write
the goal in general words; do not put private schedule contents in `context`.
