# Icon 1.0 — Spell React prototype

Standalone experimental Spell React tracker for WoW TBC Classic Anniversary (Interface 20506).

## Install

Extract the `Icon` folder into `_anniversary_/Interface/AddOns/`, replacing the previous build, then run `/reload`. The addon uses `IconDB`. An incompatible database is replaced with fresh settings.

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

No external libraries. No dependencies on action-bar buttons, action slots or macros. Displays independent spell icons only when the selected candidate ID reports an active condition, or when the row is unlocked/tested. The four Warrior abilities use their individual reaction conditions, not stance or current usability. Other candidate reactions still use `C_Spell.IsSpellUsable(spellID)` (fallback `IsUsableSpell`) and the optional Blizzard overlay signal. No countdown, glow, grouping, editor, or other tracker types in this initial build.

**Important:** Direct spell usability is not a universal proc detector. Some spells can be reported usable without a valid target, and low-resource or other conditions may behave differently than action-slot usability. The allowlist limits misleading results from ordinary spells but does not solve every special case. Execute and Overpower were observed working in the live client before alpha 3. Revenge, Victory Rush and the new stance-independent behavior still require in-game validation. The client may return different results than HoochUI's action-slot API, which is intentionally not used here.

## Structure

- `Tracking.lua` — candidate IDs, metadata lookup, Spell ID reactive predicate.
- `Database.lua` — standalone `IconDB` store and tracked-entry commands.
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

## Alpha 3 — Learned ranks and stance-independent Warrior reactions

Spell React icons show only when the character knows at least one rank of the
ability. This applies only to Spell React, without a separate class check.
The selected Spell ID remains unchanged; knowledge refreshes on `SPELLS_CHANGED`.

- Execute: a living attackable target at or below 20% health, regardless of stance or rage.
- Overpower: the existing target-specific 5-second dodge window, now also gated
  by knowledge of any Overpower rank.
- Revenge: a 5-second window after you dodge, parry or block an incoming attack;
  partial blocks are included. It is not tied to the attacker's GUID.
- Victory Rush: the `Victorious` effect (32216) via player aura/combat log,
  rather than guessing whether a kill awarded experience or honor.

A successful cast clears its tracked window. Death and world entry clear the
windows; event and 0.2-second safety-net refreshes remain as in alpha 2.
An unlearned entry stays saved, and may still appear in `/icon unlock` or
`/icon test` as a preview; it will not activate on its own.
