# Areas, activity types, and projects

The dial has two orthogonal classification axes for *what* an event is — plus a
third, an event's **`kind`** (`blocking` / `non_blocking` / `reference`), for whether
it occupies time. Kind is covered in references/calendars.md §Event kinds; this
doc is the colour + texture axes, plus projects (§Projects). Get area, type,
and kind right and the day reads at a glance; get them wrong and every block
looks the same.

- **Areas** = colour-coded categories / groups (work, health, family, errands).
  Each area has a name (≤60 chars) and a hex **color** — exactly lowercase
  `#rrggbb`; another format is a `validation` error. An event belongs to
  one area; the area's color fills its arc on the dial.
- **Activity types** = tags rendered as **fill patterns** layered on the area
  color (e.g. deep work vs meetings vs admin, all inside "Work"). Each has a name
  (≤60 chars) and a `pattern`. Valid patterns:
  `solid`, `hatch_r`, `hatch_l`, `cross`, `horizontal`, `vertical`, `grid`,
  `dots`, `waves`, `chevron`.

So **area = what color, activity type = what texture.** Color answers "which part
of my life," pattern answers "what mode of work."

## Creating them with `manage_categories`

`manage_categories` takes `areas`, `activityTypes`, and/or `projects`, each an
array of max 50 ops (projects: §Projects):

- Area: `{op:"create", name, color?}` / `{op:"update", id, name?, color?,
  order?}` / `{op:"delete", id, reassignTo?: id | null}`. Omit `color` to let
  Reassign auto-pick.
- Activity type: same shape but `pattern` instead of `color`.

The batch is **atomic by default** — if any op is invalid, nothing is written;
set `partial:true` for best-effort. A call with no op fails with `validation`
"Provide at least one area, activity-type or project op." The response has the
row arrays `areas` and `activityTypes`, and `projects` when the call sent
project ops (§Projects). Each array is indexed on its own input array. A create
or update row is the `created`/`updated` object `{id, name, color | pattern}`.
A delete row lists `deletedIds`. The first id is the id that you sent. When a
shared default has a user copy, a delete of either one lists both ids
(§Deleting safely).
When `reassignTo` is an id, the row also has `movedEvents`, the number of moved
events. A `create` or a rename into a name that an entry of the same kind
already has fails with `conflict`. The match ignores case, accents, and extra
spaces. The message gives the id of the existing entry: reuse it, or pick a
different name. A project name has a different rule (§Projects).

**Create first, then reference.** You cannot attach an event to an area that
doesn't exist yet. Sequence:

1. `manage_categories` to create the area (and any new activity type), capture
   the returned ids.
2. `write_events` referencing those ids by `areaId` / `activityTypeId`. There
   is no reference by name; look up an existing id in the `areas` and
   `activityTypes` lists of `get_schedule`.

## Manual choices and AI classification

Native event creates preserve the caller's `kind`, including default
`blocking`, and explicit non-null `areaId` / `activityTypeId` choices. Missing
categories may still be filled asynchronously. On create, `null` for either
category is equivalent to omission and remains eligible for AI filling.
For a native event (no calendar), the AI always picks an area and an activity
type for an unset field; it has no "none" answer. So a create with no area
usually gets one. To keep a category empty, clear it with `null` on an update
after the create. Inbox items keep the "none" answer.

On a native event update, explicit choices stay manual, even when reselecting
the current AI value. `areaId:null` / `activityTypeId:null` preserves deliberate
emptiness, even when already empty. Omitted fields retain their existing
ownership; a successful undo restores prior ownership. Inbox category updates
also preserve explicit clears.

`classification_pending` means the write queued classification for eligible
fields, not permission to overwrite these manual choices. Re-read when the
resulting categories matter; do not fill a deliberately cleared category just
to make the plan look complete.

## Editing globals forks them

Some areas/types are shared global defaults. Editing one **forks it into the
user's own copy**, so the returned id may differ from the one you passed — each
result reports the effective id (and `forkedFrom`). Always read the id back from
the response rather than assuming it's unchanged. The fork also takes the
links of the user's events, Inbox items, trackers, and (for an area) projects.
A write that still sends the global id in `areaId` or `activityTypeId` links
to the fork of the user.
This applies to `write_events`, `manage_inbox`, and `reassignTo`.

## Deleting safely

You can delete the user's own entries and the shared defaults. A delete of a
shared default, or of the user's copy of it, hides the default for this user
only. A hidden entry is not in the `areas` and `activityTypes` of
`get_schedule`. An event write that names it fails with `not_found`.

If a live event, an Inbox item, an active tracker, a calendar default, or (for
an area) a live project uses the entry, a delete without `reassignTo` fails
with `validation`. The error
has `usage` (`{events, inboxItems, trackers, calendars, projects?}`) and
`reassignTargets` (`[{id, name}]`). For a shared default or its copy, the counts
cover both ids; deleted events and archived trackers are excluded. An archived
project does not count in `projects`. Show the counts and ask where the items
go if the user has not already specified that choice. `reassignTo: "<id>"`
moves the links (and the projects of an area), and `reassignTo: null` clears
them (the projects then have no area).
Include the user's choice in the first delete when it is already known.
An entry with no live links needs no `reassignTo`.

When an undo receipt is recorded, its `undoToken` (30-minute window) reverses
the whole call (references/limits.md). The undo brings back the entry or the
hidden default. It also restores each link that the delete moved or cleared.
Surface the `undoToken`.

## Projects

A project is a named goal, optionally under one area. It has no colour (the
dial uses the area colour), no shared default, no fork, and no `reassignTo`.
Link an event or an Inbox item with `projectId` on write_events or manage_inbox.
Find the ids in the get_schedule `projects` lookup.

The `projects` ops run after the area and type ops of the same call, in the
same transaction:

- `{op:"create", name (1-60), areaId?, id?}`. A new project has no default list.
- `{op:"update", id, name?, areaId? (null = no area), publishCalendarId? (null
  = off), order?, archived?}`. An update with no field fails with `validation`
  "Provide a new name, areaId, order, archived and/or publishCalendarId to
  update."
- `{op:"delete", id}`.
- `{op:"split", id, linkId}` and `{op:"relink", id, linkId}` (below).

A `projects` row array comes back only when the call sent project ops:

| Op | Row |
|---|---|
| create | `created {id, name, areaId, publishCalendarId}` |
| update | `updated {id, name, areaId, archived, publishCalendarId}` |
| delete | `{deletedIds}` |
| split | `split {id, name, areaId, fromId, linkId, movedItems}` |
| relink | `relinked {id, fromId, linkId, movedItems, noop?}` |

`noop:true` on a relink means no change and no undo receipt.

**Name.** A project name is unique among all live projects of the user, in any
area. The match ignores case and extra spaces, but NOT accents. A clash fails
with `conflict` "A project named <Name> exists in <Area>." (`No area` for no
area; a concurrent write gives "A project named <Name> exists."). The message has
no id: find the project in get_schedule `projects`. An archived project holds
no name, so an unarchive into a taken name gets the same `conflict`.

**Archive.** `archived:true` keeps the links of the project. The project stays
in get_schedule `projects` with `archived: true`, and new links to it fail.
`archived:false` restores it.

**Delete.** A delete clears the project link on its Inbox items and events.
They keep their area. A delete of a project that a synced task list feeds
fails with `conflict` "Link the task list to a different project first." A
delete of a project that a Linear project feeds fails with `conflict` "Link
the Linear project to a different project first, or archive this project."
Offer an archive instead.

**Default list.** `publishCalendarId` sets the task list for a new Inbox item
of the project, when the item names no list. It must be a live, writable task
list that feeds the project and can take a new item. Else the op fails with
`not_found` "Task list not found, not writable, or not a list of this
project." A malformed id fails with `not_found` "Task list not found or not
writable."

**Split and relink.** `split` moves one task list or Linear project
(`linkId`) that feeds `id` to a new project "{list name} ({Provider})" in the
same area (" 2" on a taken name). Its Inbox items move too, and later syncs
keep it there. A wrong `linkId` fails with `not_found` "Task list or Linear
project not found, or it does not feed this project." `relink` points one
Linear project (`linkId`) at the live project `id`, with its Inbox items. A
task list changes its project in its list settings in the app. A `linkId`
that is not a Linear project fails with `not_found`.

**Feed links are not visible.** MCP reads do not show which list or Linear
project feeds a project. get_schedule `projects` has no `publishCalendarId`,
and `integrations` calendars have no `projectId`. No MCP read lists Linear
project ids. A task-list id is in `integrations.sources[].calendars[]`. Use
split, relink, and `publishCalendarId` only with a list or project that the
user names. For a Linear relink with no known id, send the user to the app.
The default list of a project shows only in a create or update row.

**Undo.** The same `undoToken` also reverses the project ops of the call. It
removes a created project, restores a changed or deleted project and its
links, and reverses a split or a relink. In the undo result, an undone create
or split counts in `removed`; the other project steps count in `restored`. A
project undo fails with `stale` when the state changed since:

- an event, an Inbox item, a calendar, or a Linear project now links a
  project that the write created;
- a split or relinked link now feeds another project, or the old project is
  gone or archived;
- another live project now holds the restored name.

A rename of the relink target does not make the relink undo stale. A gone
parent area restores as no area.

The tool description of manage_categories omits `publishCalendarId`, and the
`archived` field text says that an archived project "leaves the lookups".
Follow the behaviour above: the update accepts `publishCalendarId`, and the
lookup keeps an archived project.

### Links on events and Inbox items

- **Area follow.** The main rule is in SKILL.md §Projects and priority. A
  linked project with no area keeps the current area of the row. This rule
  also applies to an occurrence id and to `scope:"future"`. The Inbox AI does
  not fill the area of an item that has a project.
- **Forks and moves.** An occurrence fork inherits the series project and
  priority; `shift` keeps them. An unlink op (`calendarId:null`) may carry both.
- **Undo.** One undo restores the project, the priority, and an area that the
  project set.

## Practical mapping

- Keep areas few and high-contrast in color — they're the day's coarse legend.
- Use activity types to distinguish *modes* within an area (deep `dots` vs
  meetings `hatch_r` vs admin `horizontal`) so peak/trough placement
  (adhd-methods.md §chronotype--energy-placement) is visible on the dial.
- When a user describes a new kind of work, decide first: is it a new **life
  area** (new color) or a new **mode** of an existing area (new pattern)? Don't
  spawn a new area for what is really a new activity type.
