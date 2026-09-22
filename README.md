# Icon 1.0 — Spell React prototype

Standalone experimental Spell React tracker for WoW TBC Classic Anniversary (Interface 20506).

## Install

**Back up your existing Icon directory and SavedVariables.** Extract the `Icon` folder into `_anniversary_/Interface/AddOns/`, replacing the *folder* from the 0.5.3 pilot (the two builds have the same add-on name and cannot run together). `/reload` after installing. The pilot's `IconDB` is never modified; the prototype uses `IconDBv1`.

## Commands

- `/icon add 25236` — track Execute (change the ID for your actual learned rank)
- `/icon add 7384` — track Overpower (change the ID for your actual learned rank)
- `/icon list` — list tracked entries and whether they are active
- `/icon remove 25236` — remove an entry
- `/icon unlock` — show inactive icons at 45% alpha and drag the row anywhere
- `/icon lock` — hide inactive icons
- `/icon test` — toggle preview of all tracked icons
- `/icon debug 25236` — print actual spell API results to chat

## Scope

No external libraries. No dependencies on action-bar buttons, action slots or macros. Displays independent spell icons only when the selected candidate ID reports an active condition, or when the row is unlocked/tested. Detection uses `C_Spell.IsSpellUsable(spellID)` (fallback `IsUsableSpell`) and, when supported, `C_SpellActivationOverlay.IsSpellOverlayed(spellID)`. Insufficient power also counts as eligible, mirroring HoochUI's tested action-slot logic. No countdown, glow, grouping, editor, or other tracker types in this initial build.

**Important:** Direct spell usability is not a universal proc detector. Some spells can be reported usable without a valid target, and low-resource or other conditions may behave differently than action-slot usability. The allowlist limits misleading results from ordinary spells but does not solve every special case. Test Execute and Overpower in the actual client with `/icon debug <ID>` before relying on them. The client may return different results than HoochUI's action-slot API, which is intentionally not used here. This build is not yet verified in WoW.

## Structure

- `Tracking.lua` — candidate IDs, metadata lookup, Spell ID reactive predicate.
- `Database.lua` — standalone `IconDBv1` store and tracked-entry commands.
- `Display.lua` — lightweight independent movable icon row.
- `Core.lua` — initialization, events, refresh, diagnostics, slash commands.

## Alpha 2 — Overpower reaction fix

Overpower uses the player's own `SWING_MISSED` / `SPELL_MISSED` combat log event
with `DODGE` as a ~5 second, target-specific window. The icon is visible even
outside Battle Stance, and does not require the exact tracked rank to be learned.
It expires automatically or clears upon a successful Overpower cast, death or
entering the world. Execute and the other candidate spells retain the alpha 1
spell-usability detection for comparison.

Use `/icon debug 7384` to view `dodgeWindow` and `targetMatch`.
This is a combat-log hypothesis to validate in the live TBC Anniversary client.
