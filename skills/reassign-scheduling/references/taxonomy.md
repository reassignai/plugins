# Areas and activity types

The dial has two orthogonal classification axes for *what* an event is — plus a
third, an event's **`kind`** (`blocking` / `non_blocking` / `reference`), for whether
it occupies time. Kind is covered in references/calendars.md §Event kinds; this
doc is the colour + texture axes. Get all three right and the day reads at a
glance; get them wrong and every block looks the same.

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

`manage_categories` takes `areas` and/or `activityTypes`, each an
array of ops:

- Area: `{op:"create", name, color?}` / `{op:"update", id, name?, color?,
  order?}` / `{op:"delete", id, reassignTo?: id | null}`. Omit `color` to let
  Reassign auto-pick.
- Activity type: same shape but `pattern` instead of `color`.

The batch is **atomic by default** — if any op is invalid, nothing is written;
set `partial:true` for best-effort. The response has two row arrays, `areas`
and `activityTypes`, each indexed on its own input array. A create or update
row is the `created`/`updated` object `{id, name, color | pattern}`. A delete
row lists `deletedIds`. The first id is the id that you sent. When a shared
default has a user copy, deleting either one lists both ids (§Deleting safely).
When `reassignTo` is an id, the row also has `movedEvents`, the number of moved
events. A `create` or a rename into a name that an entry of the same kind
already has fails with `conflict`. The match ignores case, accents, and extra
spaces. The message gives the id of the existing entry: reuse it, or pick a
different name.

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
links of the user's events, Inbox items, and trackers. A write that still sends
the global id in `areaId` or `activityTypeId` links to the fork of the user.
This applies to `write_events`, `manage_inbox`, and `reassignTo`.

## Deleting safely

You can delete the user's own entries and the shared defaults. A delete of a
shared default, or of the user's copy of it, hides the default for this user
only. A hidden entry is not in the `areas` and `activityTypes` of
`get_schedule`. An event write that names it fails with `not_found`.

If a live event, an Inbox item, an active tracker, or a calendar default uses
the entry, a delete without `reassignTo` fails with `validation`. The error
has `usage` (`{events, inboxItems, trackers, calendars}`) and `reassignTargets`
(`[{id, name}]`). For a shared default or its copy, the counts cover both ids;
deleted events and archived trackers are excluded. Show the counts and ask
where the items go if the user has not already specified that choice.
`reassignTo: "<id>"` moves the links, and `reassignTo: null` clears them.
Include the user's choice in the first delete when it is already known.
An entry with no live links needs no `reassignTo`.

When an undo receipt is recorded, its `undoToken` (30-minute window) reverses
the whole call (references/limits.md). The undo brings back the entry or the
hidden default. It also restores each link that the delete moved or cleared.
Surface the `undoToken`.

## Practical mapping

- Keep areas few and high-contrast in color — they're the day's coarse legend.
- Use activity types to distinguish *modes* within an area (deep `dots` vs
  meetings `hatch_r` vs admin `horizontal`) so peak/trough placement
  (adhd-methods.md §chronotype--energy-placement) is visible on the dial.
- When a user describes a new kind of work, decide first: is it a new **life
  area** (new color) or a new **mode** of an existing area (new pattern)? Don't
  spawn a new area for what is really a new activity type.
