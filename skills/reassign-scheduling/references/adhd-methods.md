# ADHD-friendly scheduling methods

Apply these as **actions on the dial**, not advice you recite. Each method below
names the concrete edit you make through the Reassign tools — an event, a buffer,
a note, a recurring block — not a paragraph you read aloud. Reach for the
strong-evidence tier first; treat the weaker tiers as situational nudges.

## Contents

- [Strong evidence](#strong-evidence)
  - [Implementation intentions](#implementation-intentions)
  - [Externalized time / time-blindness](#externalized-time--time-blindness)
  - [Chunking](#chunking)
  - [Transition buffers](#transition-buffers)
  - [Zeigarnik capture + shutdown](#zeigarnik-capture--shutdown)
- [Moderate evidence](#moderate-evidence)
  - [Time-blocking vs timeboxing](#time-blocking-vs-timeboxing)
  - [Chronotype / energy placement](#chronotype--energy-placement)
  - [Pomodoro](#pomodoro)
  - [Habit stacking](#habit-stacking)
  - [Eisenhower / Q2 protection](#eisenhower--q2-protection)
- [Weak but useful](#weak-but-useful)
  - [Body doubling](#body-doubling)
  - [Task initiation](#task-initiation)
  - [Two-minute rule](#two-minute-rule)
  - [1-3-5 / eat the frog](#1-3-5--eat-the-frog)
- [Clinical guardrail](#clinical-guardrail)

---

## Strong evidence

### Implementation intentions
If-then plans beat vague goals. Encode the trigger **in the event itself**: put
an "if X, then Y" line in the event `notes` (write_events `notes`, ≤2000 chars).
Example — a "Write report" block gets `notes: "If I stall, then open last
week's outline and edit one section."` The plan rides on the dial, not in your
chat reply.

### Externalized time / time-blindness
🩺 ADHD time-blindness means elapsed and remaining time are hard to feel. The
dial *is* the intervention — it makes the day spatial. Reinforce it: render with
`show_day` so the user can see now-vs-next at a glance, and auto-chain dependent
steps as separate adjacent events (write_events `ops`) instead of one open-ended
block, so each milestone has an edge the user can see arriving.

### Chunking
A vague event ("do taxes") is a non-starter. Decompose it into the **next
physical action** and schedule only that: replace one fuzzy block with 2–4
concrete events via write_events (e.g. "gather W-2s", "fill section 1"). Keep
the first chunk small enough to start in under five minutes.

### Transition buffers
Never butt qualitatively different blocks against each other. Insert a 5–15 min
buffer event between unlike activities (meeting → deep work, deep work → errand)
and **inflate vague estimates 25–50%** before scheduling. Buffers are real
events on the dial, not slack you hope exists. This is the §buffers default the
SKILL.md references for the schedule-a-block workflow.

### Zeigarnik capture + shutdown
Open loops nag (the Zeigarnik effect). Give them a home: a single "parking lot"
note (event `notes`, or a short standing capture block) where interruptions go
instead of derailing the current block. Anchor the day with a recurring
**shutdown** event and a weekly **review** event (write_events `recurrence`
`daily` / `weekly`) so loops get closed on a schedule, not whenever anxiety
spikes.

## Moderate evidence

### Time-blocking vs timeboxing
*Time-blocking* assigns a category to a span; *timeboxing* caps a task to a fixed
window and stops when time's up. Use timeboxing for anxiety-inducing or
open-ended tasks — schedule a hard-edged block and let the edge, not completion,
end it. Both are just events; the difference is whether you let the block expand.

### Chronotype / energy placement
🩺 Place demanding/deep work in the user's **peak** window and admin/shallow
work in the **trough**. Two sources, in order of preference: when the user has
logged sleep, `get_energy` returns their actual forecast peak/dip windows for
the day (see SKILL.md §Energy) — use those; otherwise fall back to the
chronotype/energy hints in `get_schedule`'s `userPreferences` plus the day's
load. Prefer ~90-minute deep blocks. Never schedule deep work into a known
trough without flagging it (a SKILL.md "what not to do" rule).

### Pomodoro
For a long focus block, give it a focus/break rhythm rather than scheduling one
unbroken slab. Reassign does this natively — set `focusIntervals: {focusMin, breakMin}`
on the one **blocking** block (e.g. `{focusMin:25, breakMin:5}` or
`{focusMin:50, breakMin:10}`) instead of creating separate buffer events. The
block stays a single event and the breaks are derived from its length; see
SKILL.md §Focus intervals for the full contract (blocking-only, `null` to clear,
the `plannedIntervals`/`completedIntervals` read fields). Useful for task
initiation and for people who lose time inside long blocks. When the user wants
to *start* — not plan — send them to focus mode (`/focus`), which runs any
blocking block, rhythm or not; a rhythm just gives the run its interval
structure.

### Habit stacking
Anchor a new behavior to an existing fixed event ("after morning standup →
10-min inbox triage"). Schedule the new block immediately adjacent to the stable
anchor so the anchor cues it.

### Eisenhower / Q2 protection
Important-not-urgent (Q2) work is what slips. Convert it into **protected**
recurring blocks (write_events `recurrence`) so it claims dial space before
urgent-but-trivial work floods in.

## Weak but useful

### Body doubling
Working alongside someone (real or virtual) aids initiation. Schedule a "body
double / co-work" block aligned with a focus task, or pair it with a recurring
co-working session the user already attends.

### Task initiation
The "just 5 minutes" start. When a task feels immovable, schedule a tiny 5-min
opener block separate from the full task — the goal is only to begin.

### Two-minute rule
If it takes under two minutes, batch such items into a single short admin block;
**never** let them interrupt a deep-work block (that defeats the protection the
buffer bought).

### 1-3-5 / eat the frog
Cap the day's commitments (one big, three medium, five small) and schedule the
hardest/most-avoided task ("the frog") first in the peak window so it can't be
displaced. Keep the list on the dial, not in your head.

---

## Clinical guardrail

Items marked 🩺 touch areas people often medicalize. Hold this line verbatim:

> These are widely used lifestyle strategies, not clinical advice, and not a
> substitute for evaluation or treatment by a qualified clinician. Reassign will
> not recommend medication timing, dosing, sleep medication, or make diagnostic
> claims.
