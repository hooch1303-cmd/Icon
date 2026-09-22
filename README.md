# Icon 1.0 — Spell React alpha 4

Standalone Spell React tracker for WoW TBC Classic Anniversary (Interface 20506).

## Install

Place the `Icon` folder inside `_anniversary_/Interface/AddOns/` and run `/reload`.
The saved `IconDB` is upgraded from schema 1 to schema 2 **without clearing the tracked Spell IDs**. Existing row positions are used to initialize the independent Solo positions.

## Settings

- `/icon` — toggle the independent settings window.
- **Spells** — add a supported Spell ID, select it, enable/disable, test just that icon, change size (20–100), alpha, border, custom numeric FileDataID, countdown where supported, and Solo lock.
- **Groups** — create/rename/delete groups; choose horizontal/vertical, compact/fixed, individual/uniform sizes, start/center/end alignment, spacing, lock, order members, or return a member to Solo.
- To put an existing Solo spell into a group, first select the destination in **Groups**, return to **Spells**, select that spell, and click `Group: Solo`. A grouped member must return to Solo before switching groups. Deleting a group returns its members to Solo without deleting their individual settings.
- The global lock override unlocks every Solo icon and group. When locked globally, individual lock settings are respected. Unlocking shows small drag handles for otherwise inactive entries, **not** the inactive React textures.
- Test previews only the selected spell, including an inactive/unlearned spell. Closing settings ends the test.
- Compact removes inactive group slots; Fixed reserves their space while hiding their textures. An entirely inactive group disappears when locked.
- Uniform group size overrides the effective size but preserves each member's individual saved size.
- Countdown is available only for locally timed Overpower/Revenge windows; Execute, Victory Rush, and other candidates have no countdown in this release. The 5-second windows are provisional pending in-game validation.
- Delete spell/group requires two clicks of the same button to confirm. Changes are saved immediately; no `/reload` required.

## Diagnostics and commands

- `/icon add 25236` — add a supported Spell React ID (can be learned later).
- `/icon remove 25236`, `/icon list`, `/icon debug 25236` — manage or inspect entries.
- `/icon test [Spell ID]` — toggle a one-icon test (without ID: first tracked spell).
- `/icon lock`, `/icon unlock` — global positioning lock; `/icon help` — show commands.

## Implementation

- `Tracking.lua` — supported react IDs, rank knowledge and proc conditions. **Unmodified from alpha 3.**
- `Database.lua` — schema 2 migration, Solo settings, groups and membership operations.
- `Display.lua` — independent Solo/group roots, positioning, appearance, selective countdown.
- `Options.lua` — dedicated settings window.
- `Core.lua` — events, tracking refresh, slash commands and options dispatch.

Warrior Execute/Overpower/Revenge/Victory Rush behavior is unchanged from alpha 3. Other candidates retain the provisional usability-based predicate; live-client validation is still needed.
