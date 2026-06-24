# Tournament Feature — Rules & User Flows

This document is the single authoritative reference for the tournament event type: data model, enums, user flows, provider API, and invariants every future Claude session must know.

---

## Concepts

A **Tournament** event contains one or more **Divisions** (draws). Each division:
- has its own **Format** (Round Robin, Knockout, Pools → Playoffs, Custom)
- has its own **Scoring Config** (sport, points to win, best-of, etc.)
- holds a list of **Entrants** (individuals or teams)
- generates a bracket of **Matches** (each made of **Games**)

**Courts** are a shared resource across the whole event; matches are assigned to courts via a per-court queue.

---

## Data Model

### Enums

| Enum | Values | Notes |
|---|---|---|
| `Discipline` | `singles`, `doubles`, `mixed` | Determines `teamSize` (1 or 2 players per entrant) |
| `EntrantKind` | `individual`, `team` | Individual = 1–2 players. Team = ranked roster of N players that play ties. |
| `DivisionFormat` | `roundRobin`, `singleElimination`, `poolsPlayoff`, `custom` | Stored as snake_case DB value |
| `DivisionStatus` | `setup`, `registration`, `seeded`, `inProgress`, `completed` | Division lifecycle |
| `EntrantStatus` | `registered`, `checkedIn`, `withdrawn` | |
| `MatchStatus` | `pending`, `scheduled`, `inProgress`, `completed`, `bye`, `walkover` | |
| `BracketType` | `pool`, `winners` | Pool matches (pools format) vs elimination bracket |
| `CourtStatus` | `available`, `inUse`, `closed` | |
| `ScoringSystem` | `rally`, `sideOut` | Rally = every rally scores; side-out = server scores |
| `PairingRule` | `sameRank`, `manual` | Team ties only: how players are paired per sub-match |

### Free-form fields

`sport` and `skillLevel` are free-form strings — organizers can enter any value. Built-in quick-pick presets:
- Sport presets: `Badminton`, `Pickleball` (trigger scoring defaults on selection)
- Skill presets: `A B C D E Open 3.0 3.5 4.0`

### ScoringConfig

Stored as JSONB on `tournament_divisions.scoring_config`.

| Field | Type | Default | Notes |
|---|---|---|---|
| `sport` | String | `'Custom'` | Free-form label |
| `system` | `ScoringSystem` | `rally` | |
| `pointsToWin` | int | 21 | |
| `winByTwo` | bool | true | |
| `cap` | int? | null | Badminton: 30; null = uncapped |
| `bestOf` | int | 3 | Games per match; `gamesToWin = bestOf ~/ 2 + 1` |

Sport presets via `ScoringConfig.defaultFor(sport)`:
- **Badminton**: rally, 21, win-by-2, cap 30, best of 3
- **Pickleball**: side-out, 11, win-by-2, no cap, best of 3
- **Other**: rally, 21, win-by-2, no cap, best of 3

### TournamentDivision

Key computed properties:
- `bracketGenerated` → `bracketGeneratedAt != null`
- `registrationOpen` → bracket not generated AND status not `completed`
- `isPoolsPlayoff` → `format == poolsPlayoff`

Denormalized counts maintained by DB triggers: `entrantCount`, `matchCount`, `completedMatchCount`.

### TournamentEntrant

| Field | Condition |
|---|---|
| `player2Name` set | doubles/mixed entrant |
| `players` non-empty | team-kind entrant (has full ranked roster) |
| `seed` | set at bracket generation |
| `poolId` | set for pools format (which pool this entrant is in) |

Computed: `isDoubles`, `isTeam`, `isWithdrawn`.

### TournamentMatch

- `bracketType`: `pool` (round-robin pool phase) or `winners` (elimination bracket)
- `nextMatchId` / `nextMatchSlot`: winner advancement wiring
- `games`: list of `MatchGame` (game-by-game scores)
- `isTie` + `submatches`: team-vs-team tie (each sub-match is a player-vs-player game)
- `scheduledOrder`: per-court queue position

### TieConfig (team-kind divisions)

| Field | Default | Notes |
|---|---|---|
| `submatchCount` | 3 | Player vs player games per tie |
| `pairingRule` | `sameRank` | `sameRank`: rank i vs rank i; `manual`: organizer assigns |
| `winThreshold` | 2 | Sub-match wins needed to take the tie |

### Builder-only Models (not persisted)

**`BracketSegmentConfig`** — one lane in the bracket builder UI:
- `localId`: client UUID
- `name`, `format`, `scoringConfig`, `poolCount`, `advancePerPool`
- `entrants: List<DraftEntrant>`

**`DraftEntrant`** — an entrant typed in the builder pool (not yet in DB):
- `localId`, `teamName`, `player1Name`, `player2Name?`

### Court

Shared across the event. `sortOrder` controls display order.

---

## Division Status Lifecycle

```
setup → registration → seeded → in_progress → completed
                   ↑ (pools_playoff only)
```

- `setup`: just created, not yet open
- `registration`: entrants can join
- `seeded`: bracket generated (pool-phase complete, waiting to seed playoffs — pools_playoff only)
- `in_progress`: matches are being played
- `completed`: all matches done

`registrationOpen` is true for `setup` and `registration` before bracket generation.

---

## User Flows

### Organizer: Set Up Divisions

Two paths from the Divisions tab:

#### Path 1 — Add Single Division

1. Tap **Add Division** FAB (or the inline button on first-run hint)
2. Optionally pick a built-in or saved **template** to prefill all fields
3. Fill in: Name (optional, auto-generated from discipline + skill), Sport, Entrants (individual/team), Discipline (singles/doubles/mixed), Skill level, Format
4. For **Pools → Playoffs**: set pool count + advance per pool
5. For **Team** entrant kind: set roster size, sub-match count, win threshold, pairing rule
6. Edit scoring rules (points to win, cap, best of, system, win-by-2)
7. **Add Division** → calls `EventProvider.createDivision()`
8. Optionally **Save as template** for reuse

#### Path 2 — Build Structure (multi-division bracket builder)

Entry points:
- First-run hint → **Build Structure** FilledButton
- When divisions exist → small tree-icon FAB (top of FAB stack)

`BracketBuilderScreen` flow:
1. Set shared config: sport, discipline, entrant kind, skill level
2. **Step 1 — Entrant Pool**: type entrant names and tap **Add to pool**
   - Singles/teams: `Name / team name` field (hint: `e.g. Team Alpha`)
   - Doubles: `Player 1 name` (hint: `e.g. John Smith`) + `Player 2 name`
3. **Step 2 — Division Lanes**: two lanes pre-created (Division A + Division B)
   - Long-press drag chips from pool → lane (or tap chip to select, then tap lane to assign)
   - Tap format chip on a lane to open template/format picker
   - Edit lane name inline
   - Add lanes with **Add Division Lane**; delete lanes with the trash icon
4. Tap **Generate All** in AppBar
   - Validation: each lane needs a name and ≥ 2 entrants
   - Calls `EventProvider.createDivisionBundle()` which loops: `createDivision` → `registerEntrant` per entrant → `generateBracket`
5. On success, navigator pops back to the Divisions tab

Instructions banner:
- Collapsed by default; tap the title row to expand
- Auto-collapses when the first entrant is added to the pool
- "?" help button in AppBar opens the same steps in a dialog

Layout:
- Wide (≥ 700 px): pool panel (240 px) left | lanes area right
- Narrow (phone): vertical `CustomScrollView` — shared config card → pool card → lane cards → Add Division Lane button

### Organizer: Register Entrants

1. Go to **Entrants** tab → select a division from the picker
2. If registration is closed (bracket already generated), a warning banner appears; the Add Team FAB is hidden
3. Tap **Add Team** FAB

For **individual** entrants:
- Enter Player 1 name (with member-picker icon to link to an event member)
- For doubles: enter Player 2 name
- Team name is optional (defaults to `Player1 / Player2` for doubles, `Player1` for singles)

For **team** entrants:
- Enter team name (required)
- Enter player names in rank order (at least 1 required; more can be added with + Add player)
- Each player name field has a member-picker icon

Remove: tap the × icon next to an entrant in the list (organizer only; only while registration is open).

Error messages are mapped from DB error codes via `friendlyRegisterError()`:
- `duplicate_player_in_team` → "A player can't be entered twice on the same team."
- `player_already_registered` → "That player is already entered in this division."
- `division_full` → "This division is full."
- `registration_closed` → "Registration is closed — the bracket is already generated."
- `second_player_required` → "Doubles needs two players."
- `singles_no_partner` → "Singles takes one player only."

### Organizer: Generate Bracket

From the **Bracket** tab → select a division → **Generate Bracket** button (visible when bracket not yet generated and ≥ 2 entrants registered).

Calls `EventProvider.generateBracket(division)` → Supabase RPC `generate_division_bracket`.

For **pools_playoff** divisions, generation creates the pool phase first. After all pool matches are complete, the organizer taps **Seed Playoffs** to run `EventProvider.seedPlayoffs(division)` which advances the top N entrants per pool into the elimination bracket.

### Scoring a Match

From the **Bracket** tab → tap a match card → score entry sheet.

For **individual** matches:
- Enter game-by-game scores
- Winner is auto-determined per `ScoringConfig` (reach `pointsToWin`, win-by-2, cap)
- Calls `EventProvider.recordMatchScore()`

For **team tie** matches:
- Each sub-match shows the two assigned players
- Enter scores per sub-match; side wins when `gamesToWin` games won
- Tie winner determined when one side reaches `tieConfig.winThreshold` sub-match wins
- `setSubmatchPlayer()` assigns players manually if `pairingRule == manual`
- `recordSubmatchScore()` persists scores

### Courts Management

Organizer → **Courts** tab:
- **Add Court** → dialog, enter name → `EventProvider.addCourt()`
- Each court card shows its queue (first match = on court now; rest = next up)
- Assign a match from the Bracket view → court picker
- Remove from queue: tap – icon on the queue entry → `unassignMatchFromCourt()`
- Reorder queue: drag handles → `reorderCourtQueue()`
- Delete court: trash icon → `deleteCourt()`

Double-booking warning: if a player appears on two courts simultaneously, an orange banner appears at the top of the Courts tab. Detection via `EventProvider.doubleBookedEntrantIds()`.

### Custom Format (Manual Bracket)

When `format == custom`, the bracket generator is skipped. Organizer manually adds rounds/matches:
- `addManualMatch()` → creates a match in a specified round
- `updateManualMatch()` → edits entrant assignments or result
- `deleteManualMatch()`

### Viewing Bracket (All Members)

**Bracket** tab delegates to `TournamentBracketView`. Shows:
- Division picker (if multiple divisions)
- For pools format: tabs per pool + standings table (computed client-side by `computeStandings()`)
- Bracket tree visualization with match cards
- Completed matches show scores; pending show entrant names

---

## Standings Algorithm

`computeStandings(entrants, matches, {poolId})` in `lib/utils/tournament_standings.dart`:

Tiebreakers in order:
1. Wins
2. Head-to-head (direct match result between tied entrants)
3. Game differential (`gamesWon − gamesLost`)
4. Point differential (`pointsFor − pointsAgainst`)

Head-to-head wins are precomputed in O(matches) before the sort so the comparator is O(1).

---

## Templates

Built-in templates (always available):
| ID | Name |
|---|---|
| `builtin:bad_singles_se` | Badminton Singles — Knockout |
| `builtin:bad_doubles_rr` | Badminton Doubles — Round Robin |
| `builtin:bad_doubles_pools` | Badminton Doubles — Pools → Playoffs (4 pools, advance 2) |
| `builtin:pkl_dbl_rr` | Pickleball Doubles — Round Robin |
| `builtin:pkl_dbl_pools` | Pickleball Doubles — Pools → Playoffs (4 pools, advance 2) |
| `builtin:pkl_singles_se` | Pickleball Singles — Knockout |
| `builtin:mixed_rr` | Mixed Doubles — Round Robin |
| `builtin:team_ties_5` | Team Ties — 5 singles (win threshold 3) |
| `builtin:team_ties_3` | Team Ties — 3 singles (win threshold 2) |

User-saved templates are stored in `tournament_templates` table, fetched via `EventProvider.fetchTemplates()` and saved via `saveTemplate(name, config)`. A template's `config` map mirrors the `createDivision` payload.

Selecting a template in the Add Division sheet calls `_applyConfig()` which writes all fields from the config map into the form. Fields remain editable after template application.

---

## Provider API Reference

All methods are on `EventProvider` (`lib/providers/event_provider.dart`).

### Fetch

| Method | Description |
|---|---|
| `fetchTournament(eventId)` | Fetches divisions + courts in one shot |
| `fetchDivisions(eventId)` | Fetch division list for event |
| `fetchEntrants(divisionId)` | Fetch active entrants for division |
| `fetchMatches(divisionId)` | Fetch matches + games for division |
| `fetchCourts(eventId)` | Fetch courts |
| `fetchAllMatchesForEvent(eventId)` | Fetch all matches across all divisions (used by Courts tab) |
| `fetchTemplates()` | Fetch user-saved templates |

### Accessors

| Method | Returns |
|---|---|
| `divisionsFor(eventId)` | `List<TournamentDivision>` |
| `entrantsFor(divisionId)` | `List<TournamentEntrant>` (all, including withdrawn) |
| `activeEntrantsFor(divisionId)` | Excludes withdrawn |
| `matchesFor(divisionId)` | `List<TournamentMatch>` |
| `courtsFor(eventId)` | `List<Court>` sorted by `sortOrder` |
| `entrantById(eventId, id)` | Searches across all divisions for this event |
| `assignedMatchesForCourt(eventId, courtId)` | Queue for one court, sorted by `scheduledOrder` |
| `doubleBookedEntrantIds(eventId)` | Entrant IDs appearing on 2+ courts simultaneously |

### Mutations

| Method | Description |
|---|---|
| `createDivision(...)` | Creates one division via `create_tournament_division` RPC |
| `createDivisionBundle(eventId, segments, ...)` | Creates multiple divisions at once (bracket builder); loops createDivision + registerEntrant + generateBracket per segment |
| `updateDivision(divisionId, ...)` | Updates name, scoringConfig, status, entrantCap |
| `deleteDivision(divisionId, eventId)` | Deletes division and cascades |
| `generateBracket(division)` | Calls `generate_division_bracket` RPC |
| `seedPlayoffs(division)` | Seeds elimination bracket from pool standings (pools format only) |
| `registerEntrant(divisionId, ...)` | Registers an individual/doubles entrant |
| `registerTeam(divisionId, teamName, players)` | Registers a team with ranked roster |
| `withdrawEntrant(entrantId, divisionId)` | Sets status = `withdrawn` |
| `removeEntrant(entrantId, divisionId)` | Hard deletes entrant (organizer only, before bracket) |
| `addManualMatch(...)` | Creates a match in a custom-format division |
| `updateManualMatch(...)` | Edits a custom-format match |
| `deleteManualMatch(matchId, divisionId)` | |
| `recordMatchScore(divisionId, matchId, games, winnerId)` | Persists game scores + winner |
| `recordSubmatchScore(...)` | Persists a team-tie sub-match result |
| `setSubmatchPlayer(...)` | Assigns a player to a sub-match slot |
| `addCourt(eventId, name)` | Creates a court |
| `updateCourt(courtId, eventId, ...)` | Update name or status |
| `deleteCourt(courtId, eventId)` | |
| `assignMatchToCourt(match, courtId, eventId)` | Appends match to court queue |
| `unassignMatchFromCourt(match, eventId)` | Removes from queue |
| `reorderCourtQueue(courtId, matchIds, eventId)` | Reorders the queue |
| `saveTemplate(name, config)` | Saves a user template |
| `deleteTemplate(id)` | |

---

## DB Tables

| Table | Key columns |
|---|---|
| `tournament_divisions` | `id`, `event_id`, `name`, `sport`, `discipline`, `skill_level`, `format`, `scoring_config` (jsonb), `tie_config` (jsonb), `entrant_kind`, `roster_size`, `entrant_cap`, `pool_count`, `advance_per_pool`, `status`, `bracket_generated_at`, `bundle_id` (uuid nullable), `entrant_count`, `match_count`, `completed_match_count` |
| `tournament_entrants` | `id`, `division_id`, `team_name`, `player1_user_id`, `player1_name`, `player2_user_id`, `player2_name`, `seed`, `pool_id`, `status`, `registered_at` |
| `tournament_entrant_players` | `id`, `entrant_id`, `user_id`, `name`, `player_rank`, `sort_order` (team-kind rosters) |
| `tournament_matches` | `id`, `division_id`, `bracket_type`, `round_number`, `match_number`, `pool_id`, `entrant1_id`, `entrant2_id`, `winner_entrant_id`, `next_match_id`, `next_match_slot`, `court_id`, `status`, `scheduled_order`, `is_tie` |
| `tournament_match_games` | `id`, `match_id`, `game_number`, `entrant1_score`, `entrant2_score`, `winner_entrant_id` |
| `tournament_tie_submatches` | `id`, `tie_match_id`, `position`, `side1_player_id`, `side2_player_id`, `games` (jsonb), `winner_side`, `status` |
| `tournament_templates` | `id`, `user_id`, `name`, `config` (jsonb) |
| `courts` | `id`, `event_id`, `name`, `status`, `current_match_id`, `sort_order` |

`bundle_id` groups divisions created together by the bracket builder (no FK — just a shared client UUID). Denormalized counts are maintained by DB triggers.

---

## File Map

| File | Role |
|---|---|
| `lib/models/tournament.dart` | All models, enums, `ScoringConfig`, `TieConfig`, `BracketSegmentConfig`, `DraftEntrant` |
| `lib/providers/event_provider.dart` | All mutations and accessors (tournament section ~line 1997+) |
| `lib/widgets/tournament/tournament_tabs.dart` | Divisions, Entrants, Bracket, Courts tabs; `_DivisionFormSheet`, `_EntrantFormSheet`, `_TeamFormSheet`, `_PlayerNameField`, `_MemberPickerSheet` |
| `lib/widgets/tournament/bracket_builder_screen.dart` | Multi-division bracket builder (`BracketBuilderScreen`) |
| `lib/widgets/tournament/tournament_bracket_view.dart` | Bracket visualization widget (used by Bracket tab) |
| `lib/widgets/tournament/tournament_labels.dart` | Display labels for enums (`DivisionFormat.label`, `Discipline.label`, `sportIcon()`) |
| `lib/utils/tournament_standings.dart` | `computeStandings()` — client-side round-robin standings |

---

## Invariants

- **Registration closes when a bracket is generated.** `bracketGeneratedAt != null` → `registrationOpen == false`. The Add Team FAB disappears. The Entrants list becomes read-only for organizers.
- **Bracket builder entrants are fresh (not from DB).** Organizers type names directly in the builder pool. Those become `DraftEntrant` objects and are persisted only when "Generate All" is tapped.
- **Pools → Playoffs requires two generation steps.** First `generateBracket()` creates pool phase. After all pool matches complete, `seedPlayoffs()` creates the elimination bracket. No UI access to playoffs until seeded.
- **Custom format has no auto-generation.** Organizer must add matches manually via `addManualMatch()`.
- **`bundle_id` is informational only.** Divisions sharing a `bundle_id` were created together in the builder. It is never used in RLS or bracket logic.
- **Double-booking detection is client-side only.** `doubleBookedEntrantIds()` scans `assignedMatchesForCourt` in memory. It is a warning, not a hard block.
- **Team ties: winner threshold must be ≤ ceil(submatchCount / 2).** The UI does not enforce this — organizer is responsible.
