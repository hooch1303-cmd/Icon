# Icon

Standalone aura and proc icon tracker by Hooch for **WoW TBC Classic Anniversary (Interface 20506)**.

## Installation

1. Extract the ZIP so the directory is `World of Warcraft/_anniversary_/Interface/AddOns/Icon/`.
2. The `.toc` must be at `.../AddOns/Icon/Icon.toc` (not `Icon/Icon/Icon.toc`).
3. Launch or reload the game (`/reload`). Use `/icon` to open options.

## v0.1.0

- Add tracked spells by numeric Spell ID from `/icon` > Spells. Choose Buff, Debuff or Proc; unit `player`, `target`, `focus` or `pet`; caster Any or Mine.
- Buff and Debuff scan the selected unit's auras. Proc > Aura scans either Buff or Debuff, selected in the form.
- Proc > Overpower listens for **your attack being dodged**, then shows a roughly five-second window **only while the dodging enemy is your target**.
- Proc > Counterattack listens for **you parrying an attack**, then shows a roughly five-second window.
- In-game ability rank may differ from the configured ID. For auras, the name is used as fallback when the exact aura ID isn't present.
- Active icons compact to the left. Duration uses native Blizzard cooldown swipe; stacks/charges appear in the corner. Cooldown Count avoids doubling Blizzard text when OmniCC is loaded.
- Options: icon size, spacing, border, countdown numbers, position lock and visual reset (does not erase tracked spells).
- `/icon test` previews configured icons; if there are no configured spells, it shows three demo icons without saving them. Unlock position in Settings to move the icons.

**Limitations:** The combat-log windows are estimates, not checks for stance, resources, cooldown or actual ability usability. Execute/health conditions, tracking enemies outside target/focus, arena/party units and actual ability cooldowns are **not implemented**. The addon cannot infer an arbitrary proc's trigger solely from its Spell ID; use Proc > Aura for aura procs and the two explicit built-in combat triggers for Overpower and Counterattack. In-game verification is still required.

## Commands

`/icon` — options  
`/icon test` — toggle preview  
`/icon lock` / `/icon unlock` — position lock  
`/icon reset` — reset *visual settings only*
