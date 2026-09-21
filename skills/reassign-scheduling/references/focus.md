# Focus intervals and live focus

A **blocking** event can carry a focus/break rhythm — the Reassign-native
pomodoro. It stays **one event** (it selects, drags, recurs, and syncs as a
single block). Scheduled breaks are derived from its cadence; live pauses
record additional break spans on that same block. Neither creates separate
events. Set the rhythm on the one block instead of separate buffer events.

- **Set / change.** Pass `focusIntervals: {focusMin, breakMin}` on a
  `write_events` `create` or `update` — integers, `focusMin` 5–180, `breakMin`
  1–60 (e.g. `{focusMin:25, breakMin:5}` or `{focusMin:50, breakMin:10}`). The
  breaks fall *between* the focus intervals and the block always ends on a focus;
  the planned cadence excludes time banked in live pauses, so you never list
  individual intervals. On `update`,
  `focusIntervals: null` removes an existing rhythm (a `create` can't clear what
  isn't there yet). When a recurring series is forked or split, the rhythm
  carries onto the new rows.
- **Blocking only.** A non-blocking or reference block silently ignores the field
  — it's not an error, but the write echo just omits `focusIntervals`. Set a
  rhythm only where the user is *doing* focused work.
- **Read.** A blocking block that carries a rhythm serializes a `focusIntervals`
  block — `{focusMin, breakMin, plannedIntervals, completedIntervals?}`.
  `plannedIntervals` is derived from the cadence span after subtracting banked
  pause time, so a pause can extend `end` without adding a planned interval.
  `completedIntervals` appears only when completions have been tracked. It's a **count, not a prefix** — the user marks intervals
  individually, so `completedIntervals: 2` on a 4-interval block means two are
  done, not necessarily the first two. Omitted on any block without a rhythm.
- **Running a block (focus mode).** The user runs a block on the `/focus` page,
  where the dial travels under a pinned now-marker and the current block is
  named. That's where intervals get checked off, and it's what puts
  `completedIntervals` in your reads. Focus mode works on **any** blocking
  block — a block with no rhythm is simply one focus segment — so "let's focus
  on this" doesn't require setting `focusIntervals` first. Point the user there
  rather than narrating a timer yourself.
- **Marks and reflection are independent.** Marking intervals never writes a
  reflect `status`, and a reflect mark never back-fills intervals. Don't infer
  one from the other: a block with `completedIntervals` may carry no `reflect`
  block, and a `kept` event may show no completed intervals. (One overlap worth
  knowing: for up to 30 minutes past a block's end, focus mode offers an
  "As planned" verb that records `kept` — so a `reflect` state can appear
  without the user having gone through a review flow.)
- **Live focus can change real events.** Starting, pausing, continuing, or
  finishing focus can change the block's timing and recorded actuals; recurring
  work can produce a day-specific exception. The app also offers planned-block
  retiming controls. Re-read the day before scheduling around active work, and
  do not infer the whole session state from `focusIntervals` alone. A saved
  block's end can include banked pauses or a bounded live focus reservation.
  Use the app's current controls for the session rather than reproducing them
  as guessed MCP edits. Returned reflect/checklist fields remain authoritative.
- **Pauses and saved rhythms.** Live focus mode can pause/resume and bank break
  time, growing the real block. Read the server's interval counts rather than
  calculating them from `start`/`end`. The app also saves custom rhythms to the
  account; MCP writes explicit `{focusMin, breakMin}` on events and has no tool
  for managing those saved presets. See adhd-methods.md §Pomodoro.

