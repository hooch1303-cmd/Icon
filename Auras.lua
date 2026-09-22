local ADDON_NAME, ns = ...

local VALID_UNITS = { player = true, target = true, focus = true, pet = true }
local VALID_TYPES = { BUFF = true, DEBUFF = true, COOLDOWN = true }

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

-- A custom file ID changes the picture only, never the tracked spell.
function ns.EntryIcon(entry, originalIcon)
    return entry and entry.customIconID or originalIcon
end

function ns.NormalizeEntry(entry)
    if type(entry) ~= "table" then return nil end
    local spellID = tonumber(entry.spellID)
    if not spellID or spellID < 1 or spellID ~= math.floor(spellID) then return nil end
    if not VALID_TYPES[entry.kind] then return nil end
    local kind = entry.kind
    local unit = VALID_UNITS[entry.unit] and entry.unit or "player"
    return {
        spellID = spellID, kind = kind, unit = unit,
        caster = entry.caster == "MINE" and "MINE" or "ANY",
        cooldownMode = (entry.cooldownMode == "READY" or entry.cooldownMode == "ALWAYS")
            and entry.cooldownMode or "ON_COOLDOWN",
        enabled = entry.enabled ~= false, groupId = nil,
        point = "CENTER", relativePoint = "CENTER", x = 0, y = -140,
        size = 36, alpha = 1, customIconID = nil, showCountdown = true, showBorder = true,
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
    local filter = entry.kind == "DEBUFF" and "HARMFUL" or "HELPFUL"
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
        entry = entry, name = aura.name or name, icon = ns.EntryIcon(entry, aura.icon or texture),
        count = tonumber(aura.count) or 0,
        start = duration > 0 and expires > 0 and (expires - duration) or 0,
        duration = duration > 0 and expires > 0 and duration or 0,
        expires = expires > 0 and expires or nil,
    }
end

-- Classic/Anniversary has a legacy GetSpellCooldown API; clients with the
-- newer C_Spell API return a table instead. Use whichever is available.
local function SpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return tonumber(info.startTime) or 0, tonumber(info.duration) or 0,
                info.isEnabled, tonumber(info.modRate) or 1
        end
    end
    if GetSpellCooldown then return GetSpellCooldown(spellID) end
    return nil
end

local function CooldownDisplay(entry, now, gcdStart, gcdDuration)
    -- A known spell check avoids treating an unrelated or unlearned spell ID
    -- with an empty cooldown response as an always-ready ability.
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if not C_SpellBook.IsSpellKnown(entry.spellID) then return nil end
    elseif IsSpellKnown and not IsSpellKnown(entry.spellID) then
        return nil
    end
    local started, duration, enabled, rate = SpellCooldown(entry.spellID)
    -- Don't interpret an unavailable API or a disabled spell as "ready".
    if started == nil or enabled == 0 or enabled == false then return nil end
    rate = type(rate) == "number" and rate > 0 and rate or 1
    duration = tonumber(duration) or 0
    started = tonumber(started) or 0
    local expires = started + duration / rate
    local running = started > 0 and duration > 0 and expires > now
    if running and duration <= 1.6 then
        -- Spell 61304 is the GCD. Do not mistake a GCD-only response for
        -- an ability's own cooldown. Also suppress short GCD-only responses
        -- when this client's GCD lookup isn't exposed.
        local matchesGCD = type(gcdStart) == "number" and gcdStart > 0
            and type(gcdDuration) == "number"
            and math.abs(started - gcdStart) < 0.12
            and math.abs(duration - gcdDuration) < 0.12
        if matchesGCD or not gcdStart or gcdStart == 0 then running = false end
    end
    local mode = entry.cooldownMode or "ON_COOLDOWN"
    if mode == "ON_COOLDOWN" and not running then
        return nil
    elseif mode == "READY" and running then
        return nil, expires -- Wake up when Ready should become visible.
    end
    -- ALWAYS remains visible in both states; a running cooldown supplies
    -- the same native swipe and numeric timer as ON_COOLDOWN.
    local name, icon = ns.SpellInfo(entry.spellID)
    return {
        entry = entry, name = name, icon = ns.EntryIcon(entry, icon), count = 0,
        start = running and started or 0,
        duration = running and duration or 0,
        rate = rate, expires = running and expires or nil,
    }, running and expires or nil
end

function ns.ReadTracked(now)
    local active, cache = {}, {}
    local earliest
    local gcdStart, gcdDuration = SpellCooldown(61304)
    for _, entry in ipairs(ns.db.tracked) do
        if entry.enabled then
            local result, wake
            if entry.kind == "COOLDOWN" then
                result, wake = CooldownDisplay(entry, now, gcdStart, gcdDuration)
            elseif entry.kind == "BUFF" or entry.kind == "DEBUFF" then
                result = AuraDisplay(entry, FindAura(entry, cache, now))
            end
            if result then active[#active + 1] = result end
            local expires = wake or (result and result.expires)
            if expires and expires > now and (not earliest or expires < earliest) then
                earliest = expires
            end
        end
    end
    return active, earliest
end

function ns.ReadPreview(now, onlyGroupID, onlyEntryID)
    local entries = {}
    for _, entry in ipairs(ns.db.tracked) do
        if (entry.enabled or entry.id == onlyEntryID)
            and (not onlyGroupID or entry.groupId == onlyGroupID)
            and (not onlyEntryID or entry.id == onlyEntryID) then
            entries[#entries + 1] = entry
        end
    end
    if #entries == 0 and not onlyGroupID and not onlyEntryID then
        entries = {
            { id = -1, spellID = 30823, kind = "BUFF", unit = "player", size = 36, point = "CENTER", relativePoint = "CENTER", x = -44, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
            { id = -2, spellID = 24398, kind = "BUFF", unit = "player", size = 36, point = "CENTER", relativePoint = "CENTER", x = 0, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
            { id = -3, spellID = 1715, kind = "DEBUFF", unit = "target", size = 36, point = "CENTER", relativePoint = "CENTER", x = 44, y = -140, showCountdown = true, showBorder = true, showStacks = true, locked = true },
        }
    end
    local result = {}
    for i, entry in ipairs(entries) do
        local name, icon = ns.SpellInfo(entry.spellID)
        local duration = (entry.kind == "COOLDOWN" and entry.cooldownMode == "READY") and 0 or (15 + i * 8)
        result[#result + 1] = {
            entry = entry, name = (name or ("Spell " .. entry.spellID)) .. " (test)",
            icon = ns.EntryIcon(entry, icon), count = entry.kind ~= "COOLDOWN" and i == 2 and 3 or 0,
            start = ns.previewStart or now, duration = duration,
            expires = duration > 0 and ((ns.previewStart or now) + duration) or nil,
        }
    end
    return result
end
