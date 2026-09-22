local ADDON_NAME, ns = ...

local VALID_UNITS = { player = true, target = true, focus = true, pet = true }
local VALID_TYPES = { BUFF = true, DEBUFF = true, PROC = true }
local VALID_TRIGGERS = { AURA = true, OVERPOWER = true, COUNTERATTACK = true }

function ns.SpellInfo(spellID)
    if type(spellID) ~= "number" then return nil end
    local name, _, icon
    if GetSpellInfo then name, _, icon = GetSpellInfo(spellID) end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    if not name and C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    end
    return name, icon
end

function ns.NormalizeEntry(entry)
    if type(entry) ~= "table" then return nil end
    local spellID = tonumber(entry.spellID)
    if not spellID or spellID < 1 or spellID ~= math.floor(spellID) then return nil end
    local kind = VALID_TYPES[entry.kind] and entry.kind or "BUFF"
    local trigger = kind == "PROC" and (VALID_TRIGGERS[entry.trigger] and entry.trigger or "AURA") or "AURA"
    local unit = VALID_UNITS[entry.unit] and entry.unit or "player"
    local auraKind = (kind == "DEBUFF" or (kind == "PROC" and entry.auraKind == "DEBUFF")) and "DEBUFF" or "BUFF"
    return {
        spellID = spellID, kind = kind, trigger = trigger, unit = unit,
        auraKind = auraKind, caster = entry.caster == "MINE" and "MINE" or "ANY",
        enabled = entry.enabled ~= false, groupId = nil,
        point = "CENTER", relativePoint = "CENTER", x = 0, y = -140,
        size = 36, showCountdown = true, showBorder = true,
        showStacks = true, locked = true,
    }
end

local function IsMine(source)
    if not source then return false end
    if source == "player" or source == "pet" then return true end
    return UnitIsUnit and (UnitIsUnit(source, "player") or UnitIsUnit(source, "pet")) or false
end

local function Scan(unit, filter)
    local result = {}
    if not UnitExists(unit) or not UnitAura then return result end
    for i = 1, 40 do
        -- TBC Classic: name, icon, count, dispelType, duration, expirationTime,
        -- source, isStealable, nameplateShowPersonal, spellId, ...
        local name, icon, count, _, duration, expirationTime, source, _, _, spellID = UnitAura(unit, i, filter)
        if not name then break end
        result[#result + 1] = {
            name = name, icon = icon, count = count, duration = duration,
            expirationTime = expirationTime, source = source, spellID = spellID,
        }
    end
    return result
end

local function FindAura(entry, cache, now)
    local filter = entry.auraKind == "DEBUFF" and "HARMFUL" or "HELPFUL"
    local key = entry.unit .. ":" .. filter
    if not cache[key] then cache[key] = Scan(entry.unit, filter) end
    local expectedName = ns.SpellInfo(entry.spellID)
    local fallback
    for _, aura in ipairs(cache[key]) do
        if (entry.caster == "ANY" or IsMine(aura.source))
            and (not aura.expirationTime or aura.expirationTime == 0 or aura.expirationTime > now) then
            if aura.spellID == entry.spellID then return aura end
            -- Ranks of the same named spell may have a different ID.
            if not fallback and expectedName and aura.name == expectedName then fallback = aura end
        end
    end
    return fallback
end

local function AuraDisplay(entry, aura)
    if not aura then return nil end
    local duration = tonumber(aura.duration) or 0
    local expires = tonumber(aura.expirationTime) or 0
    local name, texture = ns.SpellInfo(entry.spellID)
    return {
        entry = entry, name = aura.name or name, icon = aura.icon or texture,
        count = tonumber(aura.count) or 0,
        start = duration > 0 and expires > 0 and (expires - duration) or 0,
        duration = duration > 0 and expires > 0 and duration or 0,
        expires = expires > 0 and expires or nil,
    }
end

function ns.ReadTracked(now)
    local active, cache = {}, {}
    local earliest
    for _, entry in ipairs(ns.db.tracked) do
        if entry.enabled then
            local result
            if entry.kind == "PROC" and entry.trigger ~= "AURA" then
                local window = ns.procWindows[entry.trigger]
                if window and window.expires > now
                    and (entry.trigger ~= "OVERPOWER" or (UnitExists("target") and UnitGUID("target") == window.targetGUID)) then
                    local name, icon = ns.SpellInfo(entry.spellID)
                    result = {
                        entry = entry, name = name, icon = icon, count = 0,
                        start = window.started, duration = window.duration,
                        expires = window.expires,
                    }
                end
            else
                result = AuraDisplay(entry, FindAura(entry, cache, now))
            end
            if result then
                active[#active + 1] = result
                if result.expires and (not earliest or result.expires < earliest) then
                    earliest = result.expires
                end
            end
        end
    end
    return active, earliest
end

function ns.HasCombatProcs()
    if not ns.db then return false end
    for _, entry in ipairs(ns.db.tracked) do
        if entry.enabled and entry.kind == "PROC" and entry.trigger ~= "AURA" then return true end
    end
    return false
end

function ns.ClearProcWindows()
    ns.procWindows.OVERPOWER = nil
    ns.procWindows.COUNTERATTACK = nil
end

-- WoW combat log has 11 shared fields; SWING_MISSED uses arg 12 for
-- missType, while SPELL_MISSED and RANGE_MISSED use arg 15.
function ns.HandleCombatLog()
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, a12, a13, a14, a15 = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")
    if not playerGUID then return end
    local miss
    if subevent == "SWING_MISSED" then
        miss = a12
    elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
        miss = a15
    elseif subevent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID then
        -- Remove the window when Overpower/Counterattack is actually used.
        local spellName = ns.SpellInfo(a12)
        local changed = false
        if spellName then
            for trigger, window in pairs(ns.procWindows) do
                if window.spellName == spellName then
                    ns.procWindows[trigger] = nil
                    changed = true
                end
            end
        end
        if changed then ns.Refresh() end
        return
    else
        return
    end
    local now = GetTime()
    if miss == "DODGE" and sourceGUID == playerGUID and destGUID then
        ns.procWindows.OVERPOWER = {
            started = now, duration = 5, expires = now + 5,
            targetGUID = destGUID, spellName = ns.SpellInfo(7384),
        }
        ns.Refresh()
    elseif miss == "PARRY" and destGUID == playerGUID then
        ns.procWindows.COUNTERATTACK = {
            started = now, duration = 5, expires = now + 5,
            spellName = ns.SpellInfo(19306),
        }
        ns.Refresh()
    end
end

function ns.ReadPreview(now)
    local entries = {}
    for _, entry in ipairs(ns.db.tracked) do
        if entry.enabled then entries[#entries + 1] = entry end
    end
    if #entries == 0 then
        entries = {
            { id = -1, spellID = 30823, kind = "BUFF", unit = "player", auraKind = "BUFF", size = 36, point = "CENTER", relativePoint = "CENTER", x = -44, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
            { id = -2, spellID = 24398, kind = "BUFF", unit = "player", auraKind = "BUFF", size = 36, point = "CENTER", relativePoint = "CENTER", x = 0, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
            { id = -3, spellID = 1715, kind = "DEBUFF", unit = "target", auraKind = "DEBUFF", size = 36, point = "CENTER", relativePoint = "CENTER", x = 44, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
        }
    end
    local result = {}
    for i, entry in ipairs(entries) do
        local name, icon = ns.SpellInfo(entry.spellID)
        local duration = 15 + i * 8
        result[#result + 1] = {
            entry = entry, name = (name or ("Spell " .. entry.spellID)) .. " (test)",
            icon = icon, count = i == 2 and 3 or 0,
            start = ns.previewStart or now, duration = duration,
            expires = (ns.previewStart or now) + duration,
        }
    end
    return result
end
