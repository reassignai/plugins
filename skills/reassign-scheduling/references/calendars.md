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
  - Every task app: a `manage_inbox` `update` of `plannedDate` or
    `plannedUntil` writes back to the task app.
  - A recurring task: the date is provider-owned. An update of it is refused
    with `read_only` (not an access problem; do not offer an upgrade). The
    user changes the date in the task app.
- **Place and remove keep the task.** Scheduling or moving a linked slot never
  changes the provider due date. Removing a linked slot returns the task to
  the Inbox with its due date unchanged.
- **TickTick limits.** The TickTick API cannot reopen a task, so a `skipped`
  mark does not reopen it; the user reopens it in TickTick. A recurring
  TickTick task cannot lose its dates from Reassign: complete it or change its
  schedule in TickTick. Completed TickTick history cannot change the current
  task.
- **Linear limits.** Reassign cannot delete a Linear issue. A team can map
  estimate points to hours. The user sets this in the app, and the Inbox
  duration then follows the estimate. `get_schedule` does not show it.

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
- `aiRuleWarnings` (optional) — up to 20 `{code, field, name}` entries for
  explicit taxonomy references in `aiRules` that cannot resolve against the
  user's visible categories. `code` is `missing_taxonomy_reference` or
  `ambiguous_taxonomy_reference`; `field` is `area` or `activityType`. Use the
  warning to explain a missing or unclear category and help the user resolve
  it. The warnings do not rewrite rules or categories. They check explicit
  quoted/labeled references and `set Area to …` clauses; no warnings does not
  certify arbitrary prose rules. Omitted with `includeLookups:false`.
- `defaultCalendarId` (optional) — the calendar new dial events publish to
  by default. Absent if the user has not set one, or if it is no longer
  writable. The read does not check the source `status`. A write treats a
  default on a source that is not `connected` as no default. This also applies
  to the home rule of series copies (§Calendar targets).
  It is also the default Source of a new Inbox item: a task list default
  creates each new capture as a task (SKILL.md §Inbox Source).
- `sources[]` — one per connected account: `provider`, `status`
  (`connected` is the only one that syncs; also `disconnected`, `error`,
  `pending`, `revoked`), `account` (the account name at the provider, often an
  email), and `calendars[]`. Use `account` to tell apart two calendars with the
  same name. On `revoked`, the user must reconnect the account in the app.
  MCP cannot reconnect it.
- Each calendar: `id`, `name`, `writable`, an optional `timezone` (the
  provider zone of the calendar, information only: every span uses the
  top-level `timezone`), and the import policy (below). A writable calendar of
  a calendar source (not a task list) also has `copyStyle`: the default style
  of copies on it (§Copy styles). With `copyStyle: "busy"`, `busyCopyTitle`
  gives the copy title. A `null` title means "Busy". A valid `calendarId` is
  `writable` **and** on a `connected` source. The `writable` flag does not
  check the source `status`. A write to a calendar on a source that is not
  connected fails with `read_only`.

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
the mirror setting, the default copy style, or the busy title. Direct the user
to the calendar settings in the app. Do not invent other policy fields; the
exposed compiled guidance is `aiRules`.

## Per-event sync fields

On each event in `get_schedule` / `find_event`:

- `source` — `"reassign"` for a native event, else the provider key.
- `calendarId` — the home calendar. Absent means the default calendar; `null`
  means the event is on the dial only. `mirrorCalendarIds` lists the one-way
  copy calendars, omitted when none. `mirrorStyles` maps a copy calendar id to
  its copy style (`full`, `private` or `busy`), omitted when none. These ids do
  not by themselves prove that remote delivery has finished. Look up a
  calendar's name in `integrations`. Changed recurring occurrences inherit the
  series' calendar, mirrors, and copy styles unless the occurrence has its own
  calendar.
- `readOnly: true` — the event is from a calendar the user **does not own**.
  **Never edit, move, or delete it** via `write_events`/`delete_events`.
  `update`, `shift`, and `delete` refuse it, and `clear` skips it. A
  `checklist` op, and a `reflect` mark on a past day, are allowed. Surface it
  as context and direct the user to the owning calendar. For a local event
  that the user can edit, see `calendarId: null` in §Calendar targets.
- `meeting {url, label}` and `location {text, url?}` — present when the
  provider gives them.
- `warning` — a start time that a DST change skips.

## Sync happens automatically on write

There is **no separate sync tool**. When the user has a calendar connected:

- Creating or editing a calendar-linked event — or any event created under the
  `defaultCalendarId` — via `write_events` **pushes the change
  to the provider**, exactly like editing on the dial.
- Deleting a linked event via `delete_events` removes it from the provider too.
- This includes recurring series: whole-series, one-occurrence, and
  `scope:"future"` edits propagate the matching change to the provider's series.
- On a date with two occurrences of one imported series, `seriesId@YYYY-MM-DD`
  is refused. Use the `id` of the changed occurrence from a read.

So plan and edit normally — don't warn the user about "also updating the
provider" unless it matters; do confirm before destructive edits as usual, and
surface the `undoToken`.

## Calendar targets — set them only on request

A created or edited event already follows the user's default calendar. Set a
target only when the user names a calendar, and resolve its id from
`integrations.sources[].calendars[]` first. A calendar id needs Reassign Pro
(the trial includes it) and is whole-series only.

- `calendarId` on `create`: omit it for the default calendar; `null` keeps the
  event on the dial only. A one-off with `calendarId: null` may still carry
  `mirrorCalendarIds`.
- `calendarId` on `update`: a calendar id moves the event to that calendar.
  Omit it to keep the current home.
- `calendarId: null` on `update` unlinks the whole series (a bare id, no
  `scope`). It deletes the home link and every mirror copy, and keeps the dial
  block. The same op may also carry `start`, `end`, `name`, `notes`, `areaId`,
  `activityTypeId`, and `kind`; the server applies them first, in one
  transaction. `mirrorCalendarIds`, `mirrorStyles`, `recurrence`,
  `recurrenceEnd`, `sourceUrl`, and `focusIntervals` with `calendarId: null`
  are a `validation` error. On an event that is already dial-only, the server
  ignores `calendarId: null`, and the other fields apply as a normal `update`.
  Send `mirrorCalendarIds: []` to remove its copies.
- When the read shows no `calendarId` and no copies, `calendarId: null` fails
  with `validation` ("nothing to unlink"). Omit it.
- `calendarId: null` also works on a `readOnly` event. The owner's event gets
  no delete and does not change. The provider deletes the copies of the event.
  The dial keeps a local event that the user can edit. It no longer gets the
  owner's changes. Send it only when the user asks for a local event.
- `mirrorCalendarIds` **replaces** the copy set; `[]` clears it. It must not
  contain the home `calendarId`. The server checks only the ids that the op
  adds: each must be a connected, writable calendar that is not a task list.
  An id already on the event may stay, also when its calendar is read-only or
  disconnected now. An op that adds no copy id, no new or changed copy style,
  and no new `calendarId` needs no Pro plan.
- Errors of a calendar target: an unknown calendar id is `not_found`. A
  read-only, disconnected, or gone calendar is `read_only`. These are
  `validation`: a task list as a copy, a repeated copy id, or the home id in
  the copies. A `mirrorStyles` key that is not a copy is also `validation`.
  Without Pro, an op that needs Pro fails with `permission`.
- Copies of a series need a home calendar. These ops fail with `validation`:
  - a `create` with `recurrence`, `calendarId: null`, and a nonempty
    `mirrorCalendarIds`;
  - an `update` that adds `recurrence` to a dial-only event with copies;
  - an `update` that adds copies to a dial-only series.

  The `create` case always fails. The two `update` cases pass when the event
  was on a calendar before and the user then unlinked it. A read does not show
  this, so send the op. On the error "Copies of a series need a home
  calendar", set a `calendarId` or remove the copies.

  An omitted `calendarId` on `create`, or an absent home on `update`, means the
  default calendar. It counts as no home when the user has no default calendar.
  To fix the error, set a `calendarId` or remove the copies.
- A `scope:"future"` edit of a dial-only series gives the new series no
  copies. The earlier part keeps its copies. A tail that the edit makes a
  one-off with `recurrence:null` keeps its copies. Re-read the range after the
  edit.

## Copy styles

A copy style sets how much a mirror copy shows. Set `mirrorStyles` when the
user asks to change a copy's privacy or details, including restoring `full`
details or returning to the calendar's default style.

| Style | Copy title | Copy notes | At the provider |
|---|---|---|---|
| `full` | the event title | the event notes | a normal event |
| `private` | the event title | the event notes | a private event |
| `busy` | the copy calendar's saved busy title, or "Busy" when unset | none | a private event with no reminders |

For `private` and `busy` copies, a `blocking` event shows as busy; a
`non_blocking` or `reference` event shows as free. This free/busy rule does
not apply to `full` copies.

`integrations` exposes `busyCopyTitle` only when the calendar's default
`copyStyle` is `busy`. If an event overrides a `full` or `private` calendar
to `busy`, its saved busy title still applies but is not exposed by MCP.
Do not infer "Busy" from an omitted `busyCopyTitle`.

- `mirrorStyles` on `create` or `update` maps a copy calendar id to a style.
  On `update`, it **replaces** the map; `{}` clears all event overrides. Read
  the current map and preserve other entries when changing just one copy.
  It is whole-series only.
- Each key must be in the `mirrorCalendarIds` that the op leaves on the
  event, else the op fails with `validation`. On `update` without
  `mirrorCalendarIds`, the current copy set counts.
- A copy without an entry inherits its calendar's saved copy style (default
  `full`), exposed as `copyStyle` in `integrations` for writable calendars.
  Removing an entry restores that default; to show full details on a calendar
  whose default is `busy` or `private`, set that copy's entry to `full` explicitly.
- A new or changed style needs Reassign Pro. A removed style needs no Pro plan.
- A style changes only the copy. The home event keeps all its details.

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
