local _, ns = ...

-- Candidate Spell IDs from the Spell React section of HoochUI/Modules/ActionBars.lua.
-- The allowed-list matters: usability of an ordinary spell is NOT a proc.
-- Rank groups are used only to establish whether the player knows the ability.
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


-- Knowing ANY rank makes this Spell React eligible. The selected rank only
-- determines the picture and stored ID, not whether the ability is learned.
local REACT_RANKS = {
    OVERPOWER = { 7384, 7887, 11584, 11585 },
    REVENGE = { 6572, 6574, 7379, 11600, 11601, 25288, 25269, 30357 },
    EXECUTE = { 5308, 20658, 20660, 20661, 20662, 25234, 25236 },
    VICTORY_RUSH = { 34428 },
    MONGOOSE_BITE = { 1495, 14269, 14270, 14271, 36916 },
    COUNTERATTACK = { 19306, 20909, 20910, 27067 },
    KILL_COMMAND = { 34026 },
    RIPOSTE = { 14251 },
    HAMMER_OF_WRATH = { 24275, 24274, 24239, 27180 },
}
local reactGroupByID, knownGroups = {}, nil
for group, ids in pairs(REACT_RANKS) do
    for _, id in ipairs(ids) do reactGroupByID[id] = group end
end

function ns.RefreshKnownReacts()
    knownGroups = {}
    for group, ids in pairs(REACT_RANKS) do
        local known = false
        for _, id in ipairs(ids) do
            if (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
                or (IsSpellKnown and IsSpellKnown(id)) then
                known = true
                break
            end
        end
        knownGroups[group] = known
    end
end

function ns.IsReactKnown(spellID)
    if not knownGroups then ns.RefreshKnownReacts() end
    local group = reactGroupByID[spellID]
    return group ~= nil and knownGroups[group] == true
end


-- Overpower is a short, target-specific reaction after OUR attack was dodged.
-- Its usability depends on Battle Stance and learned rank; combat-log tracking
-- works even when the player is currently in Defensive/Berserker Stance.
local OVERPOWER_IDS = { [7384] = true, [7887] = true, [11584] = true, [11585] = true }
local OVERPOWER_WINDOW = 5 -- seconds; keep provisional until confirmed in game
local overpowerExpiresAt, overpowerTargetGUID
local REVENGE_IDS = { [6572] = true, [6574] = true, [7379] = true, [11600] = true,
    [11601] = true, [25288] = true, [25269] = true, [30357] = true }
local EXECUTE_IDS = { [5308] = true, [20658] = true, [20660] = true,
    [20661] = true, [20662] = true, [25234] = true, [25236] = true }
local VICTORY_RUSH_ID, VICTORIOUS_AURA_ID = 34428, 32216
local REVENGE_WINDOW, VICTORY_WINDOW = 5, 20
local revengeExpiresAt, victoryExpiresAt

function ns.IsRevenge(spellID) return REVENGE_IDS[spellID] == true end
function ns.IsVictoryRush(spellID) return spellID == VICTORY_RUSH_ID end

function ns.IsOverpower(spellID)
    return OVERPOWER_IDS[spellID] == true
end

function ns.ClearOverpower()
    overpowerExpiresAt, overpowerTargetGUID = nil, nil
end

function ns.ClearReactiveWindows()
    ns.ClearOverpower()
    revengeExpiresAt, victoryExpiresAt = nil, nil
end

-- All combat-log offsets below are from CombatLogGetCurrentEventInfo().
-- A block can also be partial damage, so _DAMAGE's blocked amount is checked.
function ns.HandleReactiveCombatLog()
    if not CombatLogGetCurrentEventInfo or not UnitGUID then return false end
    local playerGUID = UnitGUID("player")
    if not playerGUID then return false end
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    local now = GetTime()

    -- The server's Victorious aura is authoritative for eligible kills. Do not
    -- infer eligibility from PARTY_KILL (grey mobs must not start the window).
    if destGUID == playerGUID and
        (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH"
            or subevent == "SPELL_AURA_REMOVED") and
        select(12, CombatLogGetCurrentEventInfo()) == VICTORIOUS_AURA_ID then
        victoryExpiresAt = subevent ~= "SPELL_AURA_REMOVED" and (now + VICTORY_WINDOW) or nil
        return true
    end

    if sourceGUID == playerGUID then
        if (subevent == "SWING_MISSED" or subevent == "SPELL_MISSED") and destGUID then
            local missType = subevent == "SWING_MISSED"
                and select(12, CombatLogGetCurrentEventInfo())
                or select(15, CombatLogGetCurrentEventInfo())
            if missType == "DODGE" then
                overpowerExpiresAt = now + OVERPOWER_WINDOW
                overpowerTargetGUID = destGUID
                return true
            end
        elseif subevent == "SPELL_CAST_SUCCESS" then
            local spellID = select(12, CombatLogGetCurrentEventInfo())
            if OVERPOWER_IDS[spellID] then
                ns.ClearOverpower()
                return true
            elseif REVENGE_IDS[spellID] then
                revengeExpiresAt = nil
                return true
            elseif spellID == VICTORY_RUSH_ID then
                victoryExpiresAt = nil
                return true
            end
        end
    elseif destGUID == playerGUID then
        if subevent == "SWING_MISSED" or subevent == "SPELL_MISSED"
            or subevent == "RANGE_MISSED" then
            local missType = subevent == "SWING_MISSED"
                and select(12, CombatLogGetCurrentEventInfo())
                or select(15, CombatLogGetCurrentEventInfo())
            if missType == "DODGE" or missType == "PARRY" or missType == "BLOCK" then
                revengeExpiresAt = now + REVENGE_WINDOW
                return true
            end
        elseif subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE"
            or subevent == "RANGE_DAMAGE" then
            local blocked = subevent == "SWING_DAMAGE"
                and select(16, CombatLogGetCurrentEventInfo())
                or select(19, CombatLogGetCurrentEventInfo())
            if type(blocked) == "number" and blocked > 0 then
                revengeExpiresAt = now + REVENGE_WINDOW
                return true
            end
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

function ns.GetRevengeWindow()
    return math.max(0, (revengeExpiresAt or 0) - GetTime())
end

local function VictoriousAuraActive()
    if not UnitAura or not UnitExists or not UnitExists("player") then return false end
    for index = 1, 40 do
        local name, _, _, _, _, _, _, _, _, auraID = UnitAura("player", index, "HELPFUL")
        if not name then break end
        if auraID == VICTORIOUS_AURA_ID then return true end
    end
    return false
end

function ns.GetVictoryRushState()
    local aura = VictoriousAuraActive()
    local remaining = math.max(0, (victoryExpiresAt or 0) - GetTime())
    -- Aura wins over estimated time. CLEU fallback handles clients that do not
    -- expose Victorious via UnitAura; it is cleared on use/removal/death.
    return aura or remaining > 0, remaining, aura
end

local function ExecuteCondition()
    if not UnitExists or not UnitExists("target") then return false end
    if not UnitCanAttack or not UnitCanAttack("player", "target") then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return false end
    if not UnitHealth or not UnitHealthMax then return false end
    local hp, maxHP = UnitHealth("target"), UnitHealthMax("target")
    return type(hp) == "number" and type(maxHP) == "number"
        and maxHP > 0 and hp > 0 and hp <= maxHP * 0.20
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

-- Only the Spell React type uses knowledge of any rank. Other tracker types
-- (Buff / Debuff / Cooldown) are not affected by this prototype's predicate.
function ns.ReadSpellReact(spellID)
    local result = {
        active = false, supported = ns.reactiveSpells[spellID] == true,
        known = false, usable = false, noPower = false,
        overlay = false, usableAPI = false, overlayAPI = false,
    }
    if not result.supported then return result end
    result.known = ns.IsReactKnown(spellID)
    if not result.known then return result end

    if OVERPOWER_IDS[spellID] then
        result.active, result.remaining, result.targetMatch = ns.GetOverpowerWindow()
    elseif REVENGE_IDS[spellID] then
        result.remaining = ns.GetRevengeWindow()
        result.active = result.remaining > 0
    elseif EXECUTE_IDS[spellID] then
        result.active = ExecuteCondition()
    elseif spellID == VICTORY_RUSH_ID then
        result.active, result.remaining, result.victoriousAura = ns.GetVictoryRushState()
    else
        -- Other candidate reactions retain the provisional usability mechanism
        -- until each receives an independently validated game-specific trigger.
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
        result.active = result.overlay or result.usable or result.noPower
    end
    return result
end
