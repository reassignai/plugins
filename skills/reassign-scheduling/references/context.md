# Search, weather, and energy

## Find events and Inbox items

Use `find_event {query}` when you know a name but need an id. It returns
`events`, `inbox`, `inboxMatchedCount`, `nextInboxOffset`, `ambiguous`, and
`timezone`. Search is case- and accent-insensitive on both collections.

- **Events** match fuzzily and return best match first. The default window is
  the past week through the next 30 days; `from`/`to` change that window.
  Each hit adds a name-match `score` from 0 to 1 (1 exact, 0.9 prefix, 0.75
  substring). Scores below 0.34 are excluded. This measures name similarity;
  it does not establish that an event is the user's intended target.
  `score` is output-only; leave it out when building a write from a search hit.
  `timeOfDay` filters event starts. A recurring series returns one occurrence:
  the best match (including a renamed occurrence), then nearest to today on a
  tie. Copy its returned id when editing that occurrence.
- **Inbox items** match when their name contains the query. They come in tray
  order, up to 50 per page, with the same fields as `get_schedule.backlog`.
  They have no `score`.
  `inboxMatchedCount` is the total number of matches. Follow a non-null
  `nextInboxOffset` as `inboxOffset`, keeping the query and filters, until the
  requested scope is covered. Restart pagination after an Inbox write.
  This offset pages only `inbox`; the same event results appear on each page.
- **Filters have different scope.** `areaId` and `activityTypeId` filter both
  collections. `from`, `to`, and `timeOfDay` filter only events: an Inbox match
  may be planned for any day or have no planned date. For Inbox items planned
  for a specific day, use `get_schedule` with `includeBacklog:true` and
  `backlogPlannedOn`, or inspect the search results' planned dates yourself.
- **Choose the target.** `ambiguous:true` reports a tie between distinct events;
  two occurrences of one series are not ambiguous. It does not describe Inbox
  matches. Resolve multiple plausible items or an event/Inbox name collision
  from the user's intent, and ask when that leaves the target unclear.
- **Route the write.** Edit an `events` result with `write_events` and remove it
  with `delete_events`. Edit, remove, or place an `inbox` result with
  `manage_inbox`; placement uses `{op:"schedule", id, start}`. Keep its item id
  so placement lifts the existing intention off the tray.

## Read weather and energy for one day

Both reports are optional fields of `get_schedule`. Set `from` and `to` to
the same ISO date. Use `includeWeather:true`, `includeEnergy:true`, or both.
Each true flag on a multi-day range is an input validation failure. For a
week plan, read the week's schedule, then request reports for individual days
where they affect placement. `includeLookups:false` can keep those follow-up
reads smaller.

The reports are prose strings: `weather` and `energy`. Schedule events and
free slots remain structured, using the top-level `timezone`.

### Weather

With neither weather option set, `get_schedule` includes a one-line headline
when a saved or timezone-guessed city is available. It describes the requested
single day, or today when today is in a multi-day range; other ranges omit it.
`show_day` also includes a headline. That is enough for a quick glance.

- Request `includeWeather:true` for an outdoor or weather-sensitive plan
  (a run, commute, picnic, gardening), or an explicit weather question. It
  replaces the headline with the full forecast: temperature range, conditions,
  rain window, daylight, and a part-of-day breakdown.
- Omit `weatherLocation` to use the user's city; set a city/place name to ask
  about somewhere else. `weatherLocation` requires `includeWeather:true`.
  For example, `get_schedule {from:"2026-10-03", to:"2026-10-03",
  includeWeather:true, weatherLocation:"London"}` reads October 3 in London.
- With a location override, the forecast date and times are local to that
  place, and the report labels its timezone. The returned schedule still uses
  the user's timezone. Convert a forecast window to that timezone before
  writing event times, including any date change across midnight.
- Relay a missing-location or unavailable-forecast response instead of
  inventing conditions. A guessed city is approximate; keep that qualification.
- Place outdoor work in a dry, daylight window. If an existing block is in
  forecast rain, offer a move. Pair daylight with the user's energy peak when
  useful (adhd-methods.md §Chronotype / energy placement). Act on a
  weather/mood preference only when the user has stated it.

### Energy

`includeEnergy:true` adds the user's forecast energy report: peak/dip windows,
today's current level and its drivers, and calibration state. It uses logged
sleep, tracked caffeine/intakes, and the energy levels the user logs. Use it
when alertness affects placement or the user asks about their energy.

- The date is the same `from`/`to` day. A future day forecasts from habitual
  sleep; a past day uses actual logged sleep where recorded. Energy is still
  modeled, not measured; do not present it as a record of how the day felt.
- At least one logged night of sleep is needed. With none, the report asks
  the user to log sleep; relay that response without fabricating a curve.
- Respect stated energy and capacity. Use forecast peaks for demanding work
  and dips for admin or errands. If demanding work already sits in a dip,
  offer a move rather than silently changing it.
- Reading the report does not enable a dial layer. `show_day` paints energy
  only when the user has enabled that layer (off by default);
  `includeEnergy:true` reads it regardless of that display setting.
- The app can include a menstrual-cycle rhythm in its energy layer. That term
  is absent from MCP reports: cycle data stays out of AI surfaces. A difference
  from the in-app curve can be intentional. Never ask for, infer, or record
  cycle data through a tool.
