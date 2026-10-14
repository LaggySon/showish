# Baseball control-center research

## What production systems optimize for

Baseball control rooms split work into two layers:

1. **Pregame and structural data** — team rosters, batting order, positions,
   starting pitchers, and later substitutions.
2. **High-frequency live actions** — ball, strike, foul, ball in play, out,
   hit/error, runs, bases, inning, and last-action correction.

This separation is visible in both dedicated hardware and modern scoring apps.
Daktronics' All Sport 5000 gives the operator dedicated baseball keys and can
automatically clear counts, increment pitch totals, change the at-bat team, and
advance the inning. GameChanger puts lineup/substitution management on team
screens while keeping scoring on a focused live surface.

The scorebug is normally a **consumer** of game-in-progress data, not the source
of truth. Professional systems commonly ingest a scoreboard-controller or stats
feed and map it into a graphics engine. Showish already follows the important
half of that architecture: sport state is persisted once, and connected overlay
scenes receive updates. A later integration can write into the same sport-state
API instead of bypassing the operator model.

## Findings applied to Showish

### One-press live actions

The primary operator surface now records ball, strike, foul, and in-play pitches.
Each pitch increments the active fielding pitcher's pitch count. Ball four and
strike three finish the plate appearance automatically. Dedicated plate-result
actions handle outs, reaching base, walks/HBP, and home runs.

Direct plus/minus controls remain available as correction tools. They should not
be the primary scoring workflow because they require several independent clicks
for one real-world event and can leave the count, pitcher, and batter out of sync.

### Lineups and pitching

Each team has a saved batting order, a selected current batter, per-batter game
hits and at-bats, a current pitcher, and pitch count. The inning half determines
which lineup supplies the batter and which team supplies the pitcher. The lower
two scorebug rows therefore follow game state rather than free-text status.

Pregame setup uses one paste for both clubs rather than separate team, lineup,
and bullpen fields. The importer recognizes `AWAY` and `HOME` team headings,
followed by `TEAM`, `LINEUP`, `STARTING PITCHER`, `BULLPEN`, and `ROSTER`
sections:

```text
AWAY — Team name
TEAM
Name: Harbour Kings
Short name: Kings
Code: HKG
Logo URL: https://example.com/harbour-kings.svg
Primary color: #0f766e
Secondary color: #f8fafc
Record: 18-8
Side label: Away
LINEUP
1. Alex Cruz | SS
2. Morgan Ellis | CF
STARTING PITCHER
Jordan Lee
BULLPEN
Taylor Reed | Warming
Casey Park | Available
ROSTER
Every remaining active player, one per line

HOME — Team name
TEAM
Name: Ridgeline Foxes
Short name: Foxes
Code: RFX
Logo URL: https://example.com/ridgeline-foxes.svg
Primary color: #c2410c
Secondary color: #fff7ed
Record: 16-10
Side label: Home
LINEUP
1. Jamie Fox | 2B
STARTING PITCHER
Riley Stone
BULLPEN
Avery Cole | Ready
ROSTER
Every remaining active player, one per line
```

The team section updates the same identity and branding fields used by every
overlay. Player names repeated across sections are de-duplicated, and the first
26 unique names under each club become that club's active roster. Saving the
paste updates both clubs and replaces both active rosters atomically while
retaining existing game statistics for players whose names still match.

### Guarded automation

Safe, deterministic transitions are automatic:

- every recorded pitch increments the fielding pitcher's total;
- ball four and strike three clear the count and advance the batting order;
- a third out changes sides and clears transient inning state;
- a walk/HBP or generic reach marks first base occupied;
- undo restores the last live-action snapshot.

Runner advancement and run scoring remain explicit. Those depend on the exact
play (force, error, fielder's choice, multiple runners, appeals), so guessing
would be worse than requiring the operator to use the visible score and diamond
controls. A future play-resolution dialog can gather that missing information
before applying one atomic event.

### Error recovery

Live operators need immediate correction. The first implementation keeps a
capped snapshot history for the last 25 live actions and exposes one-step undo.
The longer-term model should store an append-only play log so any past play can
be edited and the derived state replayed, matching mature digital scorebooks.

## Recommended next increments

1. Add bench players and substitutions that preserve a replaced player's batting
   slot and record pitcher appearances.
2. Replace generic “Hit / error” with a short play-resolution flow for single,
   double, triple, error, fielder's choice, and individual runner destinations.
3. Derive runs, hits, errors, batter lines, and line score from an event log.
4. Add pitch-count warning thresholds for youth and tournament broadcasts.
5. Add an external-source adapter (JSON/UDP or vendor connector) that calls the
   same validated transitions, with clear manual/feed source status and takeover.
6. Add operator hotkeys after confirming browser-source focus behavior; retain
   clickable controls as the discoverable fallback.

## Primary sources

- [Daktronics All Sport 5000 operation manual](https://www.daktronics.com/web-documents/customer-service-manuals/ed11976.pdf)
- [Daktronics baseball game-in-progress data](https://www.daktronics.com/blog/how-to-prepare-your-all-sport-for-baseball-games)
- [NewBlue Captivate Sport data integrations](https://newbluefx.com/sport/)
- [GameChanger lineup and substitution workflow](https://help.gc.com/hc/en-us/articles/30714729500301-Manage-Lineups-and-Substitutions)
- [GameChanger quick opponent lineups](https://help.gc.com/hc/en-us/articles/360030865612-Quick-Lineups)
- [GameChanger pitch counts and alerts](https://help.gc.com/hc/en-us/articles/360030865232-Pitch-Counts)
- [GameChanger editing past plays](https://help.gc.com/hc/en-us/articles/360031203911-Editing-Past-Plays)
- [MLB substitutions](https://www.mlb.com/glossary/rules/substitutions)
- [Little League scorekeeping basics](https://www.littleleague.org/university/articles/scorekeeping-101/)
