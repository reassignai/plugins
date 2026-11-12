# Moments (trackers)

A **moment** is one entry in a tracker of the user. A tracker is a thing that
the user counts or rates: a daily check-off, glasses of water, a mood rating.
The user makes the trackers in the app. Two tools use them: `get_moments` reads
and `log_moment` adds one entry. Cycle data is not part of these tools.

## Read: `get_moments`

`get_moments` is read-only. All inputs are optional.

| Input | Meaning |
|---|---|
| `from`, `to` | ISO dates (`YYYY-MM-DD`), inclusive. Send both or neither. Neither means today. |
| `trackerId` | Keeps one tracker. |

The result has `now`, `timezone`, `trackers` and `entries`. A time is a local
datetime `YYYY-MM-DDTHH:MM` in `timezone`, as in the other tools. You do not
need a `get_schedule` call first.

- **`trackers[]`** is `{id, name, scale, unit?, ratingMin?, ratingMax?,
  target?, lastEntry?}`. `scale` is `tally`, `rating` or `quantity`.
- **`lastEntry`** is `{id, time, value, note?}`. It is the most recent entry of
  the tracker in all time, not only in the range. It is absent when the user
  never logged the tracker. Read absence as "never logged", not as an error.
- **`entries[]`** is `{id, trackerId, time, value, note?}` for the range, oldest
  first. An empty list means no entry in the range.

### Answer a question

- **"When did I last log X?"** Call `get_moments` with no range. Find the
  tracker by `name`. Give the `time` of its `lastEntry`, and the `value` when it
  helps. Compare that time with `now` for "how long ago".
- **"How many today?" / "this week?"** Call `get_moments` with the range, and
  `trackerId` when you have it. Count or sum the `entries` yourself. Compare
  the result with `target` only when the tracker has one.
- **Match the tracker by name.** If no tracker matches, tell the user and list
  the tracker names. If several match, ask which one. Never invent a tracker
  and never guess between two.
- Report what the data shows. Do not explain a value or a gap as a sign of
  health or illness (see "Guardrail").

## Write: `log_moment`

`log_moment` adds one entry. It changes nothing else.

| Input | Meaning |
|---|---|
| `trackerId` | Required. Copy the `id` from a `get_moments` read. |
| `time` | Optional local datetime. Default: now. |
| `value` | Optional. Default: the default value of the tracker. A rating must be from `ratingMin` to `ratingMax`. |
| `note` | Optional text, 1000 characters at most. |

The result is `{created: {id, trackerId, time, value, note?}}`.

- **Resolve first.** Call `get_moments` before `log_moment`, and take the
  `trackerId` from that read. Do not build an id and do not use a name as an id.
- **Log only what the user asked.** One request gives one entry. Do not log an
  entry because an event ended or because a routine is due.
- **Use the time that the user gave.** "At 8 this morning" becomes that local
  time on the date of `now`. With no time, omit `time`.
- **Use the value that the user gave.** With no value, omit `value`. For a
  rating outside the bounds, ask the user; do not clamp it.
- **No undo.** The result has no `undoToken`, so there is nothing to give to
  `undo_changes`. Tell the user that a wrong entry is removed in the app.
  When the request is not clear (which tracker, which value), ask before you
  log.
- **After an uncertain result,** read `get_moments` before a retry, so that
  you do not log the entry twice.

## Not available through MCP

MCP cannot change or delete an entry. It cannot create, rename or delete a
tracker, and it cannot change a target. The user does these in the app. Say so;
do not use an event or an Inbox item as a substitute.

## Guardrail

Tracker data is the record of the user, not medical information. Do not
interpret it as a symptom, a trend of a condition, or proof that a treatment
works. Do not give advice on medication, doses, or timing, also when a tracker
has the name of a medicine. The clinical rule of SKILL.md §What not to do
applies here without change.
