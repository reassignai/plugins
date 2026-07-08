# Connected calendars, sync, and event kinds

Reassign is dial-first, but a user can connect an external source and get
**two-way sync**: imported events appear on the dial, and edits to linked events
flow back to the provider. Most of this is automatic — your job is to read the
context, respect ownership, and pick the right event `kind`.

## Providers

Three sources can be connected (`get_schedule`'s per-event `source` and each
`integrations.sources[].provider` carries the key):

| `provider` | What it is | Notes |
|---|---|---|
| `google` | Google Calendar | full two-way calendar sync |
| `microsoft` | Outlook Calendar | full two-way calendar sync |
| `todoist` | Todoist (a **task** source) | projects surface as calendars, tasks as events; two-way (writes back due/duration). Tasks are always **one-offs** — a task-linked event never recurs. |

They behave the same from the skill's side — the rules below are
provider-agnostic. The one Todoist-specific behaviour is task completion:
marking a task-linked event's reflect status mirrors to the task's lifecycle
(`kept` closes it, `skipped` reopens it) — see references/reflection.md.

## Event kinds (the third axis)

Area = colour, activity type = texture (see taxonomy.md). `kind` is orthogonal
to both: it decides whether an event *occupies time*.

| kind | Occupies time? | On the dial | Use for |
|---|---|---|---|
| `blocking` (default) | yes — can't overlap, eats free slots | full ring wedge | actual work/commitments the user is *doing* |
| `non-blocking` | no — may overlap anything | slim inner band | backdrops the user *lives through*: sleep, fasting, commute |
| `reference` | no — hours stay free | slim outer band | things the user only *watches*: a partner's event, a kid's training drop-off |

- `get_schedule` **omits** `kind` for a blocking event and emits
  `"non-blocking"` / `"reference"` otherwise. Set it with the `kind` field on a
  `write_events` create or update.
- Non-blocking minutes are kept out of `loadByArea`/`loadByActivityType` and the
  free-slot math; when present they surface separately as
  `nonBlockingLoadByArea` / `nonBlockingLoadByActivityType`. So "where did my
  time go" still accounts for a day of mostly sleep/fasting, without those bands
  pretending to block work.
- **reference** is see-only: never move, delete, or schedule work *into* it
  unless the user explicitly asks. Treat it as information, not a commitment.

## The `integrations` context

`get_schedule` includes an `integrations` object **only when a calendar is
connected** (a dial-only user's payload stays lean — its absence means "no
calendar linked"). Shape:

- `aiClassify` (bool) — whether the AI classifier runs over imported events.
  When off, it's raw sync: events mirror the provider's busy flag and nothing is
  AI-excluded, but per-calendar `defaultArea`/`defaultType`/`defaultKind` still
  apply.
- `aiRules` (string, optional) — the compiled "AI memory layer": the user's raw
  guidance (account-wide context + every per-calendar instruction) already
  compiled into one contradiction-free ruleset that the classifier reads. Absent
  when nothing has been compiled yet.
- `defaultSyncCalendarId` (optional) — the calendar new dial events publish to
  by default. Absent if the user hasn't set one (or it's stale / no longer
  writable).
- `sources[]` — one per connected provider: `provider`, `account`, `status`
  (`"connected"` is the only one that syncs; also `disconnected`/`revoked`/
  `error`), and `calendars[]`.
- Each calendar: `id`, `name`, `writable` (can we push here), and the
  classification fallbacks used when the AI is unsure — `defaultKind`,
  `defaultArea`/`defaultType` (referencing the top-level taxonomy), and the
  calendar's own `timeZone` (a fallback when the user has no selected zone).

Use it to **explain**, not to micro-manage: why an event imported as
non-blocking (its calendar's `defaultKind`, or the classifier), where a new
event will sync (`defaultSyncCalendarId`), or why a source isn't importing
(`status` ≠ connected).

## Per-event sync fields

On each event in `get_schedule` / `find_event`:

- `source` — `"reassign"` for a native event, else the provider key
  (`"google"` / `"microsoft"` / `"todoist"`). Omitted when it's native.
- `calendar` — the linked calendar's name, when the event came from / syncs to
  one.
- `readOnly: true` — the event is from a calendar the user **doesn't own**.
  **Never edit, move, or delete it** via `write_events`/`delete_events`: the
  provider owns the truth, so the change silently reverts. Surface it as context
  only.
- `mirroredTo` — present on an event the user **owns** that is mirrored to one
  or more other calendars: an array of those calendars' names. It tells you the
  same event already appears elsewhere; an edit here propagates to each mirror.
- `warning` — a sync-health note on the event, when present; relay it if the
  user is confused about an event's state.

## Sync happens automatically on write

There is **no separate sync tool**. When the user has a calendar connected:

- Creating or editing a calendar-linked event — or any event created under the
  `defaultSyncCalendarId` — via `write_events` or `schedule` **pushes the change
  to the provider**, exactly like editing on the dial.
- Deleting a linked event via `delete_events` removes it from the provider too.
- This includes recurring series: edits respect `scope` (`all`/`future`/`this`)
  and propagate the matching change to the provider's series.

So plan and edit normally — don't warn the user about "also updating the
provider" unless it matters; do confirm before destructive edits as usual, and
surface the `undoToken`.

## `syncTo` — leave it alone

`write_events` update accepts a `syncTo` (a calendar id to publish a dial-only
event to). It's wired for the dial widget's "Sync to" picker, where the user
chooses the target. **Don't set it from the skill** — a created or edited event
already follows the user's default sync calendar. Only honour it if the user
names a specific calendar to move/publish an event to and you've confirmed its
id from `integrations.sources[].calendars[]`.

## Mirroring / moving between calendars

A connected event can be **mirrored** across calendars (it appears on more than
one), and the user can **move** an event from one calendar to another. From the
skill's side this reduces to the rules above:

- A mirrored copy you don't own reads as `readOnly` — leave it. An owned event
  that is mirrored elsewhere carries `mirroredTo` (the other calendars' names);
  editing it propagates to every mirror, so you needn't touch the copies.
- Moving an owned event between the user's own calendars is a `syncTo`/dial-
  picker action; from chat, confirm the destination calendar id from
  `integrations` before doing anything, and prefer letting the user pick on the
  dial.

When in doubt about a connected-calendar action, read `integrations` first and
explain what you see rather than guessing — ownership and provider state decide
what's safe to touch.
