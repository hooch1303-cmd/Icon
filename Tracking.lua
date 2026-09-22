local _, ns = ...

-- Candidate Spell IDs from the Spell React section of HoochUI/Modules/ActionBars.lua.
-- The allowed-list matters: usability of an ordinary spell is NOT a proc.
-- All IDs are independent: no automatic matching of ranks by spell name.
ns.reactiveSpells = {
    -- Warrior: Overpower
    [7384] = true, [7887] = true, [11584] = true, [11585] = true,
    -- Warrior: Revenge
    [6572] = true, [6574] = true, [7379] = true, [11600] = true,
    [11601] = true, [25288] = true, [25269] = true, [30357] = true,
    -- Warrior: Execute
    [5308] = true, [20658] = true, [20660] = true, [20661] = true,
    [20662] = true, [25234] = true, [25236] = true,
    -- Warrior: Victory Rush
    [34428] = true,
    -- Hunter: Mongoose Bite
    [1495] = true, [14269] = true, [14270] = true, [14271] = true, [36916] = true,
    -- Hunter: Counterattack
    [19306] = true, [20909] = true, [20910] = true, [27067] = true,
    -- Hunter: Kill Command
    [34026] = true,
    -- Rogue: Riposte
    [14251] = true,
    -- Paladin: Hammer of Wrath
    [24275] = true, [24274] = true, [24239] = true, [27180] = true,
}


-- Overpower is a short, target-specific reaction after OUR attack was dodged.
-- Its usability depends on Battle Stance and learned rank; combat-log tracking
-- works even when the player is currently in Defensive/Berserker Stance.
local OVERPOWER_IDS = { [7384] = true, [7887] = true, [11584] = true, [11585] = true }
local OVERPOWER_WINDOW = 5 -- seconds; keep provisional until confirmed in game
local overpowerExpiresAt, overpowerTargetGUID

function ns.IsOverpower(spellID)
    return OVERPOWER_IDS[spellID] == true
end

function ns.ClearOverpower()
    overpowerExpiresAt, overpowerTargetGUID = nil, nil
end

-- Returns true only when a combat-log event changes the tracked window.
function ns.HandleReactiveCombatLog()
    if not CombatLogGetCurrentEventInfo or not UnitGUID then return false end
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if not sourceGUID or sourceGUID ~= UnitGUID("player") then return false end

    if subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" then
        -- SWING_MISSED: 12th argument is missType.
        -- SPELL_MISSED: spellID/name/school precede missType (15th argument).
        local missType = subevent == "SWING_MISSED"
            and select(12, CombatLogGetCurrentEventInfo())
            or select(15, CombatLogGetCurrentEventInfo())
        if missType == "DODGE" and destGUID then
            overpowerExpiresAt = GetTime() + OVERPOWER_WINDOW
            overpowerTargetGUID = destGUID
            return true
        end
    elseif subevent == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        if OVERPOWER_IDS[spellID] then
            ns.ClearOverpower()
            return true
        end
    end
    return false
end

function ns.GetOverpowerWindow()
    local now = GetTime()
    local remaining = overpowerExpiresAt and (overpowerExpiresAt - now) or 0
    local targetGUID = UnitGUID and UnitGUID("target")
    return remaining > 0 and targetGUID ~= nil and targetGUID == overpowerTargetGUID,
        math.max(0, remaining), targetGUID ~= nil and targetGUID == overpowerTargetGUID
end

function ns.GetSpellInfo(spellID)
    local name, icon
    if GetSpellInfo then name, _, icon = GetSpellInfo(spellID) end
    if C_Spell then
        if not name and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID) end
        if not icon and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spellID) end
    end
    return name, icon
end

-- API results are separated for diagnostic visibility. The candidate predicate
-- is a first-pass experiment, NOT proof of a proc for every supported spell.
-- In particular, some spells can report usable without a valid target.
function ns.ReadSpellReact(spellID)
    local result = {
        active = false, supported = ns.reactiveSpells[spellID] == true,
        known = nil, usable = false, noPower = false,
        overlay = false, usableAPI = false, overlayAPI = false,
    }
    if not result.supported then return result end

    if IsSpellKnown then
        result.known = IsSpellKnown(spellID) == true
    elseif C_SpellBook and C_SpellBook.IsSpellKnown then
        result.known = C_SpellBook.IsSpellKnown(spellID) == true
    end

    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        result.overlayAPI = true
        result.overlay = C_SpellActivationOverlay.IsSpellOverlayed(spellID) == true
    end

    local usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then
        result.usableAPI = true
        usable, noPower = C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        result.usableAPI = true
        usable, noPower = IsUsableSpell(spellID)
    end

    result.usable = not not usable
    result.noPower = not not noPower
    -- An unknown spell must not become active because of a surprising API response.
    -- nil known means the knowledge API isn't available: leave it to usability.
    if OVERPOWER_IDS[spellID] then
        -- Do not gate a tracked rank on IsSpellKnown: users often track rank 1
        -- while having a higher rank trained. Do not gate on stance/energy either.
        -- The dodge window is the proc signal, rather than spell usability.
        result.active, result.remaining, result.targetMatch = ns.GetOverpowerWindow()
    else
        result.active = result.known ~= false and
            (result.overlay or result.usable or result.noPower) or false
    end
    return result
end
