## v0.5.1 — Classic dropdown fix

- Give each Blizzard UIDropDownMenuTemplate a unique global frame name. Classic uses the name to enable/disable the control; anonymous dropdowns caused a Lua error when opening `/icon`.
- No settings reset is required. Reload after replacing the addon files.

# Icon

Standalone icon tracker by Hooch for **WoW TBC Classic Anniversary (Interface 20506)**.

## v0.5.0 — Dropdowns and Cooldown

- The Type menu offers **Buff, Debuff, Cooldown**. Old Proc / Overpower / Counterattack combat-log tracking has been removed; Reactive will be redesigned in a separate update.
- Type, Unit and Caster use Blizzard dropdown menus in the main Spells form, group > Add spell > New spell, and individual spell settings.
- **Cooldown** tracks a *known player ability* via the spell cooldown API. Unit and Caster do not apply to it and are disabled. Its individual **Display mode** defaults to **Ready**: show the icon when the ability is off cooldown and hide it while recovering. **On Cooldown** reverses visibility and shows a native cooldown swipe with optional Blizzard / OmniCC numbers.
- Matching GCD-only cooldowns are ignored. Short cooldowns are also suppressed when the GCD API is unavailable to prevent GCD flicker; in-game verification is recommended for unusual short-cooldown spells.
- In a group, Cooldown icons obey the group's existing Compact or Fixed positioning and retain per-icon size/border/countdown settings.
- Existing Buff, Debuff and group settings remain; obsolete Proc entries are deleted from tracked spells and their groups on first load. **Back up SavedVariables before updating if you wish to preserve the old Proc settings for reference.**

## Installation

Extract the ZIP so `Icon.toc` is at `C:\Users\GAME\Documents\Icon\Icon.toc` (or your WoW `_anniversary_\Interface\AddOns\Icon` directory). If you use a directory junction, update files in the Documents folder; do not replace the junction. Enter `/reload` and then `/icon`.

## Current interface

- **Spells**: add a numeric Spell ID and choose Type, Unit and Caster. Left-click a spell to edit, right-click for actions: Edit spell, Move to group, Start/Stop test, Unlock/Lock position, Disable/Enable and Delete spell. Deleting a spell requires confirmation.
- **Groups**: create a group, optionally name it; right-click for Edit group, Add spell, Start/Stop test, Unlock/Lock position, Rename, and Add/Change Group Icon. Group icon defaults to the question-mark and can be customized by Icon ID.
- **Add spell** inside a group: choose existing Solo or other-group spells (move, don't duplicate) or create new ones directly inside the group. Newly added spells can be edited individually.
- **Inside a group**: 24px spell textures, click / right-click actions and grip-based reorder; group layout includes Horizontal/Vertical, Compact/Fixed, alignment, spacing and individual/uniform size. Deleting a group sends its spells back to Solo.
- Native aura duration swipe; optional Blizzard or OmniCC cooldown count; individual stacks/charges display for auras. Cooldown tracking here does not independently model multi-charge recharge.

## Commands

- `/icon` — toggle options.
- `/icon test` — toggle global preview.
- `/icon lock` / `/icon unlock` — lock/unlock all Solo icons and groups.
- `/icon reset` — erase all tracked spells, groups and settings.

**Note:** Neither this package nor its Lua runtime has been verified on a live TBC Anniversary client; test actual cooldown behavior in-game before relying on it in PvP.
