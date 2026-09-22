# Icon

Standalone aura and proc icon tracker by Hooch for **WoW TBC Classic Anniversary (Interface 20506)**.

## Installation

1. Extract the ZIP into your addon development directory so `Icon.toc` is at `C:\Users\GAME\Documents\Icon\Icon.toc` (or install into `World of Warcraft\_anniversary_\Interface\AddOns\Icon\`).
2. If you already use a directory junction from WoW's `AddOns\Icon` to the Documents folder, leave it in place. Replace the six addon files in Documents, **not** the junction.
3. Launch the game or `/reload`, then use `/icon`.

**Development settings reset:** v0.2.0 deliberately uses a new SavedVariables schema. Existing v0.1.0 settings and tracked spells are discarded once when v0.2.0 loads. Re-add Blood Fury, Bloodrage and any other desired spells. Back up your old `IconDB` separately if you want to keep it for reference.

## v0.2.0 — solo icons and groups

- `/icon` > **Spells**: add a numeric Spell ID as Buff, Debuff or Proc; choose `player`, `target`, `focus` or `pet`, and caster Any or Mine where applicable. Click a tracked spell to open its **individual** settings.
- Each solo icon has its own position, icon size, Border, Cooldown Count, Show stacks / charges and Lock position. There is **no spacing setting for solo icons**.
- `/icon` > **Groups**: create a named group. In each spell's settings, click **Group: Solo** to cycle between Solo and your groups. You may move a spell into or out of any group at any time.
- A group has its own position, Lock position, Orientation (Horizontal/Vertical), Layout (Compact/Fixed), Alignment, Spacing, and size mode (Individual/Uniform). Individual keeps each member's size; Uniform temporarily overrides them with the group's size. Removing a group detaches its spells and keeps their personal settings.
- **Compact** places only active icons next to each other. **Fixed** reserves an invisible slot for each *enabled* member, even when inactive. Move members with the `^` and `v` buttons in group settings. Drag any visible icon to move the entire unlocked group. An empty unlocked group has a draggable handle.
- Duration uses Blizzard's native cooldown swipe. Cooldown Count supports Blizzard or OmniCC without duplicate countdowns. Stacks and charges can be hidden individually.
- `/icon test` previews configured icons even when their effects are not active. If there are no tracked spells, three temporary standalone demo icons appear.

## Tracking behavior and limitations

- Buff and Debuff scan the selected unit's auras. Proc > Aura scans a matching Buff or Debuff.
- Proc > Overpower listens for **your attack being dodged**. It shows an approximate five-second window only while the dodging enemy is your current target.
- Proc > Counterattack listens for **you parrying an attack** and shows an approximate five-second window.
- Ability ranks may have different Spell IDs; aura tracking uses the spell name as fallback if an exact ID isn't found. An arbitrary proc's trigger cannot be deduced from its ID alone.
- Combat-log windows are estimates, not checks of stance, resources, cooldowns or actual castability. Execute, arena/party units, and ability cooldown tracking are **not implemented**. In-game verification is still required.

## Commands

- `/icon` — open options.
- `/icon test` — toggle preview.
- `/icon lock` / `/icon unlock` — lock/unlock all solo icons and groups.
- `/icon reset` — **erase all tracked spells, groups and settings**, restoring a blank v0.2.0 configuration.
