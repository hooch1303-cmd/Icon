local _, ns = ...

-- Version 2 extends IconDB without discarding the existing tracked Spell IDs.
local SCHEMA = 2
local DEFAULT_SIZE, DEFAULT_SPACING = 40, 4

local function ValidID(value)
    local id = tonumber(value)
    if id and id > 0 and id == math.floor(id) then return id end
end

local function Number(value, default, low, high)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

local function OneOf(value, choices, default)
    return choices[value] and value or default
end

local function NormalizeIcon(value, index, oldX, oldY)
    local data = type(value) == "table" and value or {}
    return {
        enabled = data.enabled ~= false,
        size = Number(data.size, DEFAULT_SIZE, 20, 100),
        alpha = Number(data.alpha, 1, 0, 1),
        border = data.border ~= false,
        customIcon = ValidID(data.customIcon),
        countdown = data.countdown == true,
        locked = data.locked ~= false,
        x = Number(data.x, oldX + (index - 1) * (DEFAULT_SIZE + DEFAULT_SPACING), -10000, 10000),
        y = Number(data.y, oldY, -10000, 10000),
    }
end

local function NormalizeGroup(value, known, claimed)
    if type(value) ~= "table" then return end
    local id = ValidID(value.id)
    if not id then return end
    local members = {}
    if type(value.members) == "table" then
        for _, raw in ipairs(value.members) do
            local spellID = ValidID(raw)
            if spellID and known[spellID] and not claimed[spellID] then
                members[#members + 1] = spellID
                claimed[spellID] = true
            end
        end
    end
    return {
        id = id,
        name = type(value.name) == "string" and value.name:sub(1, 32) or ("Group " .. id),
        x = Number(value.x, 0, -10000, 10000),
        y = Number(value.y, -140, -10000, 10000),
        locked = value.locked ~= false,
        orientation = OneOf(value.orientation, { horizontal=true, vertical=true }, "horizontal"),
        layout = OneOf(value.layout, { compact=true, fixed=true }, "compact"),
        sizeMode = OneOf(value.sizeMode, { individual=true, uniform=true }, "individual"),
        size = Number(value.size, DEFAULT_SIZE, 20, 100),
        spacing = Number(value.spacing, DEFAULT_SPACING, 0, 30),
        alignment = OneOf(value.alignment, { start=true, center=true, finish=true }, "center"),
        members = members,
    }
end

function ns.InitDatabase()
    if type(IconDB) ~= "table" then IconDB = {} end
    local db = IconDB
    local tracked, seen = {}, {}
    if type(db.tracked) == "table" then
        for _, value in ipairs(db.tracked) do
            local id = ValidID(value)
            if id and ns.reactiveSpells[id] and not seen[id] then
                seen[id] = true
                tracked[#tracked + 1] = id
            end
        end
    end
    db.tracked = tracked
    db.x = Number(db.x, 0, -10000, 10000)
    db.y = Number(db.y, -140, -10000, 10000)
    db.locked = db.locked ~= false

    local icons = {}
    local savedIcons = type(db.icons) == "table" and db.icons or {}
    -- Place legacy row members around its saved center, not all to its right.
    local oldLeft = db.x - math.max(0, #tracked - 1) * (DEFAULT_SIZE + DEFAULT_SPACING) / 2
    for index, id in ipairs(tracked) do
        icons[id] = NormalizeIcon(savedIcons[id] or savedIcons[tostring(id)], index, oldLeft, db.y)
    end
    db.icons = icons
    local groups, claimed, groupIDs, maxID = {}, {}, {}, 0
    if type(db.groups) == "table" then
        for _, value in ipairs(db.groups) do
            local group = NormalizeGroup(value, seen, claimed)
            if group and not groupIDs[group.id] then
                groupIDs[group.id] = true
                maxID = math.max(maxID, group.id)
                groups[#groups + 1] = group
            end
        end
    end
    db.groups = groups
    db.nextGroupID = math.max(maxID + 1, ValidID(db.nextGroupID) or 1)
    db.schemaVersion = SCHEMA
    ns.db = db
    return true
end

function ns.GetIconSettings(spellID)
    return ns.db and ns.db.icons[spellID]
end

function ns.GetGroup(groupID)
    if not ns.db then return end
    for _, group in ipairs(ns.db.groups) do
        if group.id == groupID then return group end
    end
end

function ns.GetSpellGroup(spellID)
    if not ns.db then return end
    for _, group in ipairs(ns.db.groups) do
        for _, id in ipairs(group.members) do
            if id == spellID then return group end
        end
    end
end

function ns.AddReact(spellID)
    spellID = ValidID(spellID)
    if not spellID then return false, "Enter a positive numeric Spell ID." end
    if not ns.reactiveSpells[spellID] then
        return false, "This ID is not in the Spell React candidate list."
    end
    local name = ns.GetSpellInfo(spellID)
    if not name then return false, "Unknown Spell ID." end
    for _, id in ipairs(ns.db.tracked) do
        if id == spellID then return false, "Already tracking this Spell ID." end
    end
    ns.db.tracked[#ns.db.tracked + 1] = spellID
    ns.db.icons[spellID] = NormalizeIcon(nil, #ns.db.tracked, ns.db.x, ns.db.y)
    ns.Refresh()
    ns.Draw()
    return true, "Added " .. name .. " (" .. spellID .. ")."
end

function ns.RemoveReact(spellID)
    spellID = ValidID(spellID)
    for index, id in ipairs(ns.db.tracked) do
        if id == spellID then
            table.remove(ns.db.tracked, index)
            local group = ns.GetSpellGroup(id)
            if group then
                for n, member in ipairs(group.members) do
                    if member == id then table.remove(group.members, n); break end
                end
            end
            ns.db.icons[id] = nil
            if ns.testSpellID == id then ns.testSpellID = nil end
            ns.Refresh()
            ns.Draw()
            return true, "Removed Spell ID " .. id .. "."
        end
    end
    return false, "This Spell ID is not tracked."
end

function ns.CreateGroup(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false, "Enter a group name." end
    if #name > 32 then return false, "Group name must be 32 characters or fewer." end
    local id = ns.db.nextGroupID
    ns.db.nextGroupID = id + 1
    local group = NormalizeGroup({id=id, name=name, x=ns.db.x, y=ns.db.y}, {}, {})
    ns.db.groups[#ns.db.groups + 1] = group
    ns.Draw()
    return true, group
end

function ns.DeleteGroup(groupID)
    for index, group in ipairs(ns.db.groups) do
        if group.id == groupID then
            -- Every member returns to Solo; its individual settings are preserved.
            for _, spellID in ipairs(group.members) do
                local settings = ns.GetIconSettings(spellID)
                if settings then settings.x, settings.y = group.x, group.y end
            end
            table.remove(ns.db.groups, index)
            ns.Draw()
            return true
        end
    end
    return false
end

function ns.MoveReact(spellID, groupID)
    local settings = ns.GetIconSettings(spellID)
    if not settings then return false, "Spell is not tracked." end
    local from = ns.GetSpellGroup(spellID)
    local to = groupID and ns.GetGroup(groupID) or nil
    if groupID and not to then return false, "Unknown group." end
    if from == to then return true end
    -- A group member must return to Solo before moving to another group.
    if from and to then return false, "Move the spell to Solo first." end
    if from then
        for index, id in ipairs(from.members) do
            if id == spellID then table.remove(from.members, index); break end
        end
        settings.x, settings.y = from.x, from.y
    elseif to then
        to.members[#to.members + 1] = spellID
    end
    ns.Draw()
    return true
end

function ns.MoveGroupMember(group, spellID, direction)
    if not group or (direction ~= -1 and direction ~= 1) then return false end
    for index, id in ipairs(group.members) do
        if id == spellID then
            local target = index + direction
            if target < 1 or target > #group.members then return false end
            group.members[index], group.members[target] = group.members[target], group.members[index]
            ns.Draw()
            return true
        end
    end
    return false
end
