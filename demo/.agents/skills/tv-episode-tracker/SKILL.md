---
name: tv-episode-tracker
description: "Track Breaking Bad watch progress in a simple markdown checklist and keep summary stats in sync."
---

# TV Episode Tracker

Track one show in one file with a plain checklist (no tables).

## Canonical File

- `breaking-bad.md`
- Do not keep duplicate tracker files.

## Expected Markdown Shape

```md
# Breaking Bad Watch Tracker

- Total episodes: 62
- Watched: 13
- Remaining: 49
- Progress: 21.0%
- Last watched: S02E06 — Peekaboo
- Next episode: S02E07 — Negro y Azul

## Season 2 (2009)

- [x] S02E06 — Peekaboo (April 12, 2009)
- [ ] S02E07 — Negro y Azul (April 19, 2009)
```

## Episode Input Normalization

Accepted formats:
- `S2E6`
- `s02e06`
- `2x06`

All normalize to `SxxEyy`.

## Commands

### Mark one episode watched

```bash
./.agents/skills/tv-episode-tracker/scripts/tracker.sh \
  --file breaking-bad.md \
  mark --episode S02E06
```

### Mark everything through an episode

```bash
./.agents/skills/tv-episode-tracker/scripts/tracker.sh \
  --file breaking-bad.md \
  mark --episode S02E06 --through
```

### Recompute summary stats

```bash
./.agents/skills/tv-episode-tracker/scripts/tracker.sh \
  --file breaking-bad.md \
  refresh
```

## What Gets Updated

- Episode checklist lines (`- [x] ...`)
- Summary lines:
  - Total episodes
  - Watched
  - Remaining
  - Progress
  - Last watched
  - Next episode

## Pitfalls

- Keep checklist lines in this exact shape:
  - `- [x] S02E06 — Peekaboo (April 12, 2009)`
- Use one canonical file only: `breaking-bad.md`.
