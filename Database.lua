local _, ns = ...

local SCHEMA = 1

function ns.InitDatabase()
    if type(IconDB) ~= "table" or IconDB.schemaVersion ~= SCHEMA then
        IconDB = {
            schemaVersion = SCHEMA,
            tracked = {},
            x = 0, y = -140, locked = true,
        }
    end
    if type(IconDB.tracked) ~= "table" then IconDB.tracked = {} end

    local clean, seen = {}, {}
    for _, value in ipairs(IconDB.tracked) do
        local id = tonumber(value)
        if id and id > 0 and id == math.floor(id)
            and ns.reactiveSpells[id] and not seen[id] then
            seen[id] = true
            clean[#clean + 1] = id
        end
    end
    IconDB.tracked = clean
    if type(IconDB.x) ~= "number" then IconDB.x = 0 end
    if type(IconDB.y) ~= "number" then IconDB.y = -140 end
    IconDB.locked = IconDB.locked ~= false
    ns.db = IconDB
    return true
end

function ns.AddReact(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 or spellID ~= math.floor(spellID) then
        return false, "Enter a positive numeric Spell ID."
    end
    if not ns.reactiveSpells[spellID] then
        return false, "This ID is not in the Spell React candidate list."
    end
    local name = ns.GetSpellInfo(spellID)
    if not name then return false, "Unknown Spell ID." end
    for _, id in ipairs(ns.db.tracked) do
        if id == spellID then return false, "Already tracking this Spell ID." end
    end
    ns.db.tracked[#ns.db.tracked + 1] = spellID
    ns.Refresh()
    return true, "Added " .. name .. " (" .. spellID .. ")."
end

function ns.RemoveReact(spellID)
    spellID = tonumber(spellID)
    for index, id in ipairs(ns.db.tracked) do
        if id == spellID then
            table.remove(ns.db.tracked, index)
            ns.Refresh()
            return true, "Removed Spell ID " .. id .. "."
        end
    end
    return false, "This Spell ID is not tracked."
end
