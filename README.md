# Icon

## v0.4.1 — group member list controls

- In **Groups > Edit group > Spells in group**, each member has a 24x24 spell texture beside its name and Spell ID.
- Left-click the icon or name to open that spell's settings; right-click the member row to open the same spell actions used in the main Spells list (including Move to group and Unlock group position).
- Drag the `::` grip on the left over another visible row, then release to reorder the group without changing any spell settings. No up/down arrows or inline Edit buttons. Reordering is confined to the current group list page; if released outside a row, order is unchanged.


Standalone aura and proc icon tracker by Hooch for **WoW TBC Classic Anniversary (Interface 20506)**.

## Installation

1. Extract the ZIP into your addon development directory so `Icon.toc` is at `C:\Users\GAME\Documents\Icon\Icon.toc` (or install into `World of Warcraft\_anniversary_\Interface\AddOns\Icon\`).
2. If you already use a directory junction from WoW's `AddOns\Icon` to the Documents folder, leave it in place. Replace the six addon files in Documents, **not** the junction.
3. Launch the game or `/reload`, then use `/icon`.

**Development settings:** v0.4.0 keeps the v0.2.0 SavedVariables schema: your current tracked spells, icon settings, and groups remain in place. Numeric names such as `1` are displayed as `Group 1` when possible. Use `/icon reset` only if you explicitly want to erase everything.

## v0.4.0 — per-spell actions and group Add spell

- `/icon` > **Spells**: add a numeric Spell ID as Buff, Debuff or Proc; choose `player`, `target`, `focus` or `pet`, and caster Any or Mine where applicable. Click a tracked spell to open its **individual** settings.
- Each solo icon has its own position, icon size, Border, Cooldown Count, Show stacks / charges and Lock position. There is **no spacing setting for solo icons**.
- `/icon` > **Groups**: create a group with an optional name. A blank name becomes `Group 1`, `Group 2`, etc. A group row shows only its chosen icon, name, and spell count. Left-click the row to edit; right-click to open its context menu.
- A new group displays a **question-mark placeholder**, not an automatic preset. The group context menu is text-only: **Edit group**, **Add spell**, **Start/Stop test**, **Unlock/Lock position**, **Rename**, and **Add Group Icon**. Rename changes only the name. Add Group Icon accepts just a **numeric Custom Icon ID**; leave it blank and Save to restore the question mark. Custom group icons appear only in the settings list, not as tracked combat icons. Existing custom group Icon IDs are kept; the former automatic rune placeholder changes to the question mark.
- Group preview affects only the selected group; all other groups and solo icons continue their normal tracking. The global **Start test** button is present only on the Spells list; `/icon test` is still available. Only one group preview runs at once. The Groups list omits Orientation and Layout labels.
- The **Spells** list has full-row actions: left-click to edit; right-click for **Edit spell**, **Move to group**, **Start/Stop test**, **Unlock/Lock position**, **Disable/Enable spell**, and **Delete spell**. Deletion requires confirmation. A grouped spell's position action locks or unlocks its group. The old inline On/X buttons are gone.
- **Group > Add spell** has **Existing spells** (multi-select Solo icons or spells from other groups, then move selected records without copying) and **New spell** (create by Spell ID / Type / Unit / Caster / Proc trigger). A new spell is assigned immediately to that group; the window stays open for more IDs and shows recent additions with an Edit button. **Done** returns to the group editor.
- A single-spell preview affects only that spell; the rest continue normal tracking. A disabled spell may also be previewed. Group, single-spell and global previews are mutually exclusive.
- In each spell's settings, click **Group: Solo** to cycle between Solo and your groups. You may move a spell into or out of any group at any time.
- A group has its own position, Lock position, Orientation (Horizontal/Vertical), Layout (Compact/Fixed), Alignment, Spacing, and size mode (Individual/Uniform). Individual keeps each member's size; Uniform temporarily overrides them with the group's size. Removing a group detaches its spells and keeps their personal settings.
- **Compact** places only active icons next to each other. **Fixed** reserves an invisible slot for each *enabled* member, even when inactive. Drag the member-list grips to reorder spells on the current page. Drag any visible icon to move the entire unlocked group. An empty unlocked group has a draggable handle.
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
- `/icon reset` — **erase all tracked spells, groups and settings**, restoring a blank v0.4.1 configuration.
