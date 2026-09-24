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

`mcp__reassign__manage_categories` takes `areas` and/or `activityTypes`, each an
array of ops:

- Area: `{op:"create", name, color?}` / `{op:"update", id, name?, color?,
  order?}` / `{op:"delete", id, reassignTo?}`. Omit `color` to let Reassign
  auto-pick.
- Activity type: same shape but `pattern` instead of `color`.

The batch is **atomic by default** — if any op is invalid, nothing is written;
pass `partial:true` for best-effort. The response has two row arrays, `areas`
and `activityTypes`, each indexed on its own input array. A create or update
row is the `created`/`updated` object `{id, name, color | pattern}`; a delete
row lists `deletedIds` (plus `movedEvents` after a reassign). A name that
matches an existing area/type (case- and whitespace-insensitive) is rejected:
reuse the existing id.

**Create first, then reference.** You cannot attach an event to an area that
doesn't exist yet. Sequence:

1. `manage_categories` to create the area (and any new activity type), capture
   the returned ids.
2. `write_events` referencing those ids by `areaId` / `activityTypeId`. There
   is no reference by name; look up an existing id in the `areas` and
   `activityTypes` lists of `get_schedule`.

## Editing globals forks them

Some areas/types are shared global defaults. Editing one **forks it into the
user's own copy**, so the returned id may differ from the one you passed — each
result reports the effective id (and `forkedFrom`). Always read the id back from
the response rather than assuming it's unchanged.

## Deleting safely

You can delete only the user's own (non-global) entries. If events still use the
entry, the delete fails unless you pass `reassignTo` — another entry's id — to
move those events first. Each call that writes returns one `undoToken`
(30-min window) that reverses the whole call. So the
safe delete is: pick a destination area/type, `delete` with `reassignTo` set,
confirm the moved count, surface the `undoToken`.

## Practical mapping

- Keep areas few and high-contrast in color — they're the day's coarse legend.
- Use activity types to distinguish *modes* within an area (deep `dots` vs
  meetings `hatch_r` vs admin `horizontal`) so peak/trough placement
  (adhd-methods.md §chronotype--energy-placement) is visible on the dial.
- When a user describes a new kind of work, decide first: is it a new **life
  area** (new color) or a new **mode** of an existing area (new pattern)? Don't
  spawn a new area for what is really a new activity type.
