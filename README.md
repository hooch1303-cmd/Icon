# Icon

Standalone icon tracker by Hooch for **WoW TBC Classic Anniversary (Interface 20506)**.

## Install / update

Extract the ZIP with `Icon.toc` at `C:\Users\GAME\Documents\Icon\Icon.toc`, or install it into your WoW `_anniversary_\Interface\AddOns\Icon` directory. If you use a directory junction, replace the files in **Documents**; keep the junction in place. Then enter `/reload` and `/icon`.

## v0.5.3 — Unified icon editor

- One editor for Solo and Group icons: editable Spell ID (Enter / Apply ID), Type, Unit/Caster or Cooldown Display mode, and a real Group dropdown.
- The header's live preview stays visible even when the tracked effect is inactive. It immediately reflects the spell texture, custom border, icon size and alpha.
- Icon alpha (0–100%) affects the whole in-game icon, including its border and countdown, and is saved per icon. The border texture uses its original color without Buff/Debuff/Cooldown tinting.
- Uniform-sized groups keep determining the rendered size; the personal icon size remains editable and saved for later Solo / Individual mode.
- Enable/Disable, individual Test, group/solo position lock and removal are available from the same editor. Glow is deliberately deferred.
- To change a Spell ID, a valid known spell must be supplied. Duplicate tracking rules are rejected and the existing entry/group/position/appearance are kept.

## v0.5.2 — Cooldown display modes

Add a learned player ability with **Type: Cooldown**. Each new entry defaults to **On Cooldown**. Open the spell's individual settings to choose **Display mode**:

| Display mode | Ability ready | Ability recovering |
| --- | --- | --- |
| **On Cooldown** | Hidden | Visible with native cooldown swipe and optional numeric countdown |
| **Ready** | Visible without a timer | Hidden |
| **Always** | Visible without a timer | Visible with native cooldown swipe and optional numeric countdown |

- **Display mode is only in the individual spell settings**, not either Add spell form. Unit and Caster are hidden for Cooldown because this version reads the **player's** own spell cooldown.
- A spell's **Cooldown Count** option controls its numeric timer (Blizzard or OmniCC). Swipe remains visible when the spell is recovering. For Ready, countdown is not applicable.
- Matching global-cooldown-only responses are ignored; the addon refreshes on spell-cooldown events and when cooldowns expire. Existing Cooldown display modes and Buff/Debuff/group settings are kept; no reset is needed.
- This version does not separately model charge-based cooldowns or the estimated cooldowns of other players. Actual API behavior must be checked in WoW, especially for spells with unusual short cooldowns or modifiers.

## Interface

- **Spells**: add Spell ID as Buff, Debuff or Cooldown. Left-click a tracked spell to edit; right-click for Edit, Move to group, Start/Stop test, Unlock/Lock, Disable/Enable and Delete. Deletion requires confirmation.
- **Buff / Debuff**: choose player, target, focus or pet and Caster Any/Mine. Aura durations, stacks and charges use the native icon UI.
- **Groups**: create an optionally named group, assign or move existing spells, or add new spells directly to that group. Group actions are on right-click. The group's optional Icon ID affects only its options-list icon.
- **Inside a group**: click/right-click members for spell actions; drag the `::` grip to reorder on the current page. Layout supports Horizontal/Vertical, Compact/Fixed, alignment, spacing and individual/uniform icon sizes.
- Per-icon settings: size, border, cooldown count, stacks (for auras) and solo position. An unlocked group moves as one unit. Deleting a group returns its spells to Solo.
- Reactive / old Proc tracking is **not** implemented; it will be redesigned separately.

## Commands

- `/icon` — open options.
- `/icon test` — toggle global preview.
- `/icon lock` / `/icon unlock` — lock/unlock all solo icons and groups.
- `/icon reset` — erase all tracked spells, groups and settings.

**Development build:** Not yet verified in a live WoW client. Back up SavedVariables before trying a development version if your existing setup matters.
