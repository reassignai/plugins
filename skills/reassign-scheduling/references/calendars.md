# Connected calendars, sync, and event kinds

Reassign is dial-first, but a user can connect an external source and get
**two-way sync**: imported events appear on the dial, and edits to linked events
flow back to the provider. Most of this is automatic — your job is to read the
context, respect ownership, and pick the right event `kind`.

## Providers

Seven providers can be connected. `get_schedule`'s per-event `source` and each
`integrations.sources[].provider` carry the key:

| `provider` | What it is | Notes |
|---|---|---|
| `google` | Google Calendar | full two-way calendar sync |
| `microsoft` | Outlook Calendar | full two-way calendar sync |
| `todoist` | Todoist (task app) | projects surface as calendars |
| `google_tasks` | Google Tasks (task app) | lists surface as calendars |
| `microsoft_todo` | Microsoft To Do (task app) | lists surface as calendars |
| `linear` | Linear (task app) | only issues assigned to the user, in the selected teams |
| `ticktick` | TickTick (task app) | lists surface as calendars |

The rules below are provider-agnostic. Task apps share these behaviors:

- **A task-linked event is a one-off.** Reassign does not translate a local
  recurrence into a provider series. The exact time and duration live only in
  Reassign; a task app stores a date.
- **Task completion.** A reflect mark on a task-linked event mirrors to the
  task's lifecycle: `kept` completes the task, `skipped` reopens it. See
  references/reflection.md.
- **Dated tasks land in the Inbox**, not on the dial. Undated tasks are
  imported only when the user turns that on for the list or team. The due date
  becomes the item's `plannedDate` (a due + later deadline becomes its
  `plannedDate`…`plannedUntil` window).
- **Title, notes, due date, and completion sync both ways**, with these
  differences for the planned date of an Inbox item:
  - Google Tasks, Microsoft To Do, Linear: a `manage_backlog` `update` of
    `plannedDate` writes back to the task app. These apps keep one due date,
    so a `plannedUntil` window is a `validation` error.
  - Todoist, TickTick: the date is provider-owned. An update of it is refused
    with `permission` (not an access problem; do not offer an upgrade). The
    user changes the date in the task app.
- **Place and remove keep the task.** Scheduling or moving a linked slot never
  changes the provider due date. Removing a linked slot returns the task to
  the Inbox with its due date unchanged.
- **TickTick limits.** The TickTick API cannot reopen a task, so a `skipped`
  mark does not reopen it; the user reopens it in TickTick. A recurring
  TickTick task cannot lose its dates from Reassign: complete it or change its
  schedule in TickTick. Completed TickTick history cannot change the current
  task.

## Event kinds (the third axis)

Area = colour, activity type = texture (see taxonomy.md). `kind` is orthogonal
to both: it decides whether an event *occupies time*.

| kind | Occupies time? | On the dial | Use for |
|---|---|---|---|
| `blocking` (default) | yes — can't overlap, eats free slots | full ring wedge | actual work/commitments the user is *doing* |
| `non_blocking` | no — may overlap anything | slim inner band | backdrops the user *lives through*: sleep, fasting, commute |
| `reference` | no — hours stay free | slim outer band | things the user only *watches*: a partner's event, a kid's training drop-off |

- Every read event carries `kind`: `"blocking"`, `"non_blocking"`, or
  `"reference"`. Set it with the `kind` field on a `write_events` create or
  update. An all-day calendar event always syncs as `reference`; a change of
  its kind is refused with `read_only`.
- Non-blocking minutes are kept out of `loadByArea`/`loadByActivityType` and the
  free-slot math; when present they surface separately as
  `nonBlockingLoadByArea` / `nonBlockingLoadByActivityType`. So "where did my
  time go" still accounts for a day of mostly sleep/fasting, without those bands
  pretending to block work.
- **reference** is see-only: never move, delete, or schedule work *into* it
  unless the user explicitly asks. Treat it as information, not a commitment.

## The `integrations` context

`get_schedule` includes `integrations` when the account has source records,
including disconnected sources. Its absence means no sources are configured;
check each source's `status` before describing sync as active. Shape:

- `aiClassify` (bool) — whether the AI classifier runs over imported events.
  When off, AI exclusion/classification does not run; provider facts and the
  fixed per-calendar values still apply.
- `aiRules` (string, optional) — the compiled "AI memory layer": the user's raw
  guidance (account-wide context + every per-calendar instruction) already
  compiled into one contradiction-free ruleset that the classifier reads. Absent
  when nothing has been compiled yet.
- `defaultCalendarId` (optional) — the calendar new dial events publish to
  by default. Absent if the user hasn't set one (or it's no longer writable).
- `sources[]` — one per connected account: `provider`, `status`
  (`connected` is the only one that syncs; also `disconnected`, `error`,
  `pending`, `revoked`), and `calendars[]`. A connected app does not get the
  `account` name; only the Reassign apps and a Personal Access Token get it.
- Each calendar: `id`, `name`, `writable` (only a writable calendar is a valid
  `calendarId`), an optional `timezone` (a fallback when the user has no
  selected zone), and the import policy (below).

Use the visible facts to explain where new events sync (`defaultCalendarId`)
or why a source is not importing (`status` ≠ connected). A source entry alone
does not establish that sync is active.

## Import policies

Each calendar has one policy for each of three values of an imported event:

```json
{
  "area": { "mode": "fixed", "areaId": "a1" },
  "activityType": { "mode": "automatic" },
  "kind": { "mode": "fixed", "kind": "non_blocking" }
}
```

- `area`: `{mode:"automatic"}` or `{mode:"fixed", areaId}`.
- `activityType`: `{mode:"automatic"}`, `{mode:"fixed", activityTypeId}`, or
  `{mode:"none"}`.
- `kind`: `{mode:"automatic"}` or `{mode:"fixed", kind}`.
- `automatic` means that the AI classifier picks the value. A fixed value
  always wins and the AI is not asked.

Use these fields to explain an imported event's area, type, or kind. All-day
events stay references for all policies. A policy change in the app can
re-apply to existing events in a bounded, atomic run; do not simulate it by
rewriting every event from chat, and do not assume that a change rewrote all
historical occurrences. MCP cannot change a policy, the per-calendar AI rules,
or the mirror setting: direct the user to the calendar settings in the app. Do
not invent other policy fields; the exposed compiled guidance is `aiRules`.

## Per-event sync fields

On each event in `get_schedule` / `find_event`:

- `source` — `"reassign"` for a native event, else the provider key.
- `calendarId` — the home calendar. Absent means the default calendar; `null`
  means the event is on the dial only. `mirrorCalendarIds` lists the one-way
  copy calendars, omitted when none. These ids do not by themselves prove that
  remote delivery has finished. Look up a calendar's name in `integrations`.
- `readOnly: true` — the event is from a calendar the user **doesn't own**.
  **Never edit, move, or delete it** via `write_events`/`delete_events`: the
  provider owns the truth, so the change silently reverts. Surface it as context
  only.
- `meeting {url, label}` and `location {text, url?}` — present when the
  provider gives them.
- `warning` — a start time that a DST change skips.

## Sync happens automatically on write

There is **no separate sync tool**. When the user has a calendar connected:

- Creating or editing a calendar-linked event — or any event created under the
  `defaultCalendarId` — via `write_events` or `schedule` **pushes the change
  to the provider**, exactly like editing on the dial.
- Deleting a linked event via `delete_events` removes it from the provider too.
- This includes recurring series: whole-series, one-occurrence, and
  `scope:"future"` edits propagate the matching change to the provider's series.

So plan and edit normally — don't warn the user about "also updating the
provider" unless it matters; do confirm before destructive edits as usual, and
surface the `undoToken`.

## Calendar targets — set them only on request

A created or edited event already follows the user's default calendar. Set a
target only when the user names a calendar, and resolve its id from
`integrations.sources[].calendars[]` first. A calendar id needs Reassign Pro
(the trial includes it) and is whole-series only.

- `calendarId` on `create`: omit it for the default calendar; `null` keeps the
  event on the dial only.
- `calendarId` on `update`: a calendar id moves the event to that calendar.
  Omit it to keep the current home.
- `calendarId: null` on `update` unlinks the whole series (a bare id, no
  `scope`). It deletes the home link and every mirror copy, and keeps the dial
  block. The same op may also carry `start`, `end`, `name`, `notes`, `areaId`,
  `activityTypeId`, and `kind`; the server applies them first, in one
  transaction. `mirrorCalendarIds`, `recurrence`, `recurrenceEnd`, `sourceUrl`,
  and `focusIntervals` with `calendarId: null` are a `validation` error. On an
  event that is already dial-only, `calendarId: null` changes nothing; send
  `mirrorCalendarIds: []` to remove its copies.
- `mirrorCalendarIds` **replaces** the copy set; `[]` clears it. It must not
  contain the home `calendarId`. The server checks only the ids that the op
  adds: each must be a connected, writable calendar that is not a task list.
  An id already on the event may stay, also when its calendar is read-only or
  disconnected now. An op that adds no id needs no Pro plan.

## Mirroring / moving between calendars

A connected event can be **mirrored** across calendars (it appears on more than
one), and the user can **move** an event from one calendar to another. From the
skill's side this reduces to the rules above:

- A mirrored copy you don't own reads as `readOnly` — leave it. An owned event
  lists its copies in `mirrorCalendarIds`; editing it propagates to every copy,
  so you needn't touch the copies.
- A calendar can also mirror its imported events on its own. The app sets this
  per calendar: off, always, or an AI choice. A task list never mirrors and is
  never a mirror target. MCP does not show or change this setting.
- Move an owned event between the user's own calendars with `calendarId` on
  `update`, only after you confirm the destination id from `integrations`.

When in doubt about a connected-calendar action, read `integrations` first and
explain what you see rather than guessing — ownership and provider state decide
what's safe to touch.
