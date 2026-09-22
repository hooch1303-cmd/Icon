local ADDON_NAME, ns = ...
local events = CreateFrame("Frame")
ns.testMode = false
ns.testGroupID = nil
ns.testEntryID = nil

local SCHEMA = 2 -- Keep v0.2 tracked spells and groups.
ns.DEFAULT_GROUP_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local OLD_DEFAULT_GROUP_ICON = "Interface\\Icons\\INV_Misc_Rune_01"
local function NewDatabase()
    return { schemaVersion = SCHEMA, tracked = {}, groups = {}, nextEntryID = 1, nextGroupID = 1 }
end

function ns.Print(message)
    print("|cff9f7bffIcon|r: " .. tostring(message))
end

function ns.FindEntry(id)
    if not ns.db then return nil end
    for _, entry in ipairs(ns.db.tracked) do
        if entry.id == id then return entry end
    end
end

function ns.FindGroup(id)
    if not ns.db or not id then return nil end
    for _, group in ipairs(ns.db.groups) do
        if group.id == id then return group end
    end
end

local refreshSerial = 0
function ns.Refresh()
    if not ns.db or not ns.displayRoot then return end
    refreshSerial = refreshSerial + 1
    local serial = refreshSerial
    local now = GetTime()
    local active, earliest
    if ns.testMode then
        active = ns.ReadPreview(now)
    else
        active, earliest = ns.ReadTracked(now)
        local group = ns.FindGroup(ns.testGroupID)
        if group then
            local filtered = {}
            for _, item in ipairs(active) do
                if item.entry.groupId ~= group.id then filtered[#filtered + 1] = item end
            end
            for _, item in ipairs(ns.ReadPreview(now, group.id)) do
                filtered[#filtered + 1] = item
            end
            active = filtered
        elseif ns.testEntryID then
            local entry = ns.FindEntry(ns.testEntryID)
            if entry then
                local filtered = {}
                for _, item in ipairs(active) do
                    if item.entry.id ~= entry.id then filtered[#filtered + 1] = item end
                end
                for _, item in ipairs(ns.ReadPreview(now, nil, entry.id)) do
                    filtered[#filtered + 1] = item
                end
                active = filtered
            end
        end
    end
    ns.Draw(active)
    if earliest and C_Timer and C_Timer.After then
        C_Timer.After(math.max(0.05, earliest - now + 0.05), function()
            if refreshSerial == serial and not ns.testMode then ns.Refresh() end
        end)
    end
end

function ns.EntriesChanged()
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function RemoveMember(group, id)
    if not group then return end
    for index, memberID in ipairs(group.members) do
        if memberID == id then
            table.remove(group.members, index)
            return
        end
    end
end

function ns.AddEntry(data)
    local entry = ns.NormalizeEntry(data)
    if not entry then return false, "Invalid entry." end
    local name = ns.SpellInfo(entry.spellID)
    if not name then return false, "Unknown Spell ID (try another rank)." end
    for _, old in ipairs(ns.db.tracked) do
        if old.spellID == entry.spellID and old.kind == entry.kind
            and (entry.kind == "COOLDOWN"
                or (old.unit == entry.unit and old.caster == entry.caster)) then
            return false, "That tracking rule already exists."
        end
    end
    entry.id = ns.db.nextEntryID
    ns.db.nextEntryID = entry.id + 1
    entry.x = (#ns.db.tracked % 7) * (entry.size + 12) - 120
    entry.y = -140
    ns.db.tracked[#ns.db.tracked + 1] = entry
    ns.EntriesChanged()
    return true, "Added " .. name .. ".", entry.id
end

-- Replace the tracked spell without changing its entry ID, group, position or appearance.
function ns.UpdateEntrySpell(id, newSpellID)
    local entry = ns.FindEntry(id)
    if not entry then return false, "Spell entry not found." end
    newSpellID = tonumber(newSpellID)
    if not newSpellID or newSpellID < 1 or newSpellID ~= math.floor(newSpellID) then
        return false, "Enter a valid numeric Spell ID."
    end
    local name = ns.SpellInfo(newSpellID)
    if not name then return false, "Unknown Spell ID (try another rank)." end
    if newSpellID == entry.spellID then return true, "Spell ID unchanged." end
    for _, old in ipairs(ns.db.tracked) do
        if old.id ~= id and old.spellID == newSpellID and old.kind == entry.kind
            and (entry.kind == "COOLDOWN"
                or (old.unit == entry.unit and old.caster == entry.caster)) then
            return false, "That tracking rule already exists."
        end
    end
    entry.spellID = newSpellID
    ns.EntriesChanged()
    return true, "Now tracking " .. name .. "."
end

function ns.RemoveEntry(id)
    local entry = ns.FindEntry(id)
    if not entry then return end
    if ns.testEntryID == id then ns.testEntryID = nil end
    RemoveMember(ns.FindGroup(entry.groupId), id)
    for index, item in ipairs(ns.db.tracked) do
        if item.id == id then table.remove(ns.db.tracked, index); break end
    end
    ns.EntriesChanged()
end

local function TrimGroupName(name)
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
end

local function AvailableGroupName(name, exceptID)
    for _, group in ipairs(ns.db.groups) do
        if group.id ~= exceptID and group.name:lower() == name:lower() then return false end
    end
    return true
end

local function DefaultGroupName(id)
    local n = id
    while not AvailableGroupName("Group " .. n, id) do n = n + 1 end
    return "Group " .. n
end

function ns.CreateGroup(name)
    name = TrimGroupName(name)
    local id = ns.db.nextGroupID
    if name == "" then name = DefaultGroupName(id) end
    if #name > 30 then return false, "Group name must be 30 characters or fewer." end
    if not AvailableGroupName(name) then return false, "A group with that name exists." end
    ns.db.nextGroupID = id + 1
    ns.db.groups[#ns.db.groups + 1] = {
        id = id, name = name, icon = ns.DEFAULT_GROUP_ICON, members = {},
        point = "CENTER", relativePoint = "CENTER", x = 0,
        y = -140 - (#ns.db.groups * 56),
        orientation = "HORIZONTAL", layout = "FIXED", align = "CENTER",
        sizeMode = "INDIVIDUAL", groupSize = 36, spacing = 4, locked = true,
    }
    ns.EntriesChanged()
    return true, "Created group " .. name .. ".", id
end

function ns.RenameGroup(id, name)
    local group = ns.FindGroup(id)
    if not group then return false, "Group not found." end
    name = TrimGroupName(name)
    if name == "" then name = DefaultGroupName(group.id) end
    if #name > 30 then return false, "Group name must be 30 characters or fewer." end
    if not AvailableGroupName(name, id) then return false, "A group with that name exists." end
    group.name = name
    ns.EntriesChanged()
    return true, "Updated " .. name .. "."
end

-- The group icon is only an icon in the options list, not a tracked aura.
-- Passing nil restores the question-mark placeholder.
function ns.SetGroupIcon(id, iconID)
    local group = ns.FindGroup(id)
    if not group then return false, "Group not found." end
    if iconID ~= nil and (type(iconID) ~= "number" or iconID < 1 or iconID ~= math.floor(iconID)) then
        return false, "Enter a positive numeric Icon ID."
    end
    group.icon = iconID or ns.DEFAULT_GROUP_ICON
    ns.EntriesChanged()
    return true, "Group icon updated."
end

function ns.AssignGroup(id, newGroupID)
    local entry = ns.FindEntry(id)
    if not entry or (newGroupID and not ns.FindGroup(newGroupID)) then return end
    if entry.groupId == newGroupID then return end
    RemoveMember(ns.FindGroup(entry.groupId), id)
    entry.groupId = newGroupID
    local group = ns.FindGroup(newGroupID)
    if group then group.members[#group.members + 1] = id end
    ns.EntriesChanged()
end

function ns.MoveMember(groupID, entryID, step)
    local group = ns.FindGroup(groupID)
    if not group then return end
    for index, memberID in ipairs(group.members) do
        if memberID == entryID then
            local other = index + step
            if other >= 1 and other <= #group.members then
                group.members[index], group.members[other] = group.members[other], group.members[index]
                ns.EntriesChanged()
            end
            return
        end
    end
end

-- Dragging a member in the configuration list reorders IDs only. It never
-- changes the entry's group, personal display settings, or tracking rule.
function ns.ReorderMember(groupID, entryID, targetID)
    local group = ns.FindGroup(groupID)
    if not group or entryID == targetID then return false end
    local from, to
    for i, id in ipairs(group.members) do
        if id == entryID then from = i end
        if id == targetID then to = i end
    end
    if not from or not to then return false end
    table.remove(group.members, from)
    table.insert(group.members, to, entryID)
    ns.EntriesChanged()
    return true
end

function ns.DeleteGroup(id)
    local group = ns.FindGroup(id)
    if not group then return end
    if ns.testGroupID == id then ns.testGroupID = nil end
    for index, entryID in ipairs(group.members) do
        local entry = ns.FindEntry(entryID)
        if entry then
            entry.groupId = nil
            -- Start detached icons close to their former group, then drag individually.
            entry.point, entry.relativePoint = group.point, group.relativePoint
            entry.x = group.x + ((index - 1) % 5) * (entry.size + 8)
            entry.y = group.y
        end
    end
    for index, item in ipairs(ns.db.groups) do
        if item.id == id then table.remove(ns.db.groups, index); break end
    end
    ns.EntriesChanged()
end

function ns.SetTest(value)
    ns.testMode = value == true
    if ns.testMode then
        ns.testGroupID = nil
        ns.testEntryID = nil
    end
    ns.previewStart = ns.testMode and GetTime() or nil
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetGroupTest(id, value)
    if value and not ns.FindGroup(id) then return end
    ns.testGroupID = value and id or nil
    if value then
        ns.testMode = false
        ns.testEntryID = nil
    end
    ns.previewStart = value and GetTime() or nil
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetEntryTest(id, value)
    if value and not ns.FindEntry(id) then return end
    ns.testEntryID = value and id or nil
    if value then
        ns.testMode = false
        ns.testGroupID = nil
    end
    ns.previewStart = value and GetTime() or nil
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.Reset()
    ns.db = NewDatabase()
    IconDB = ns.db
    ns.testMode = false
    ns.testGroupID = nil
    ns.testEntryID = nil
    ns.EntriesChanged()
end

local function Slash(message)
    if not ns.db then return end
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "options" then
        ns.ToggleOptions()
    elseif command == "test" then
        ns.SetTest(not ns.testMode)
        ns.Print("Test mode: " .. (ns.testMode and "on" or "off"))
    elseif command == "lock" or command == "unlock" then
        local locked = command == "lock"
        for _, entry in ipairs(ns.db.tracked) do entry.locked = locked end
        for _, group in ipairs(ns.db.groups) do group.locked = locked end
        ns.Refresh()
        if ns.RefreshOptions then ns.RefreshOptions() end
        ns.Print(locked and "All icons locked." or "All icons unlocked.")
    elseif command == "reset" then
        ns.Reset()
        ns.Print("All settings, groups and tracked spells cleared.")
    else
        ns.Print("/icon — options | /icon test | /icon lock | /icon unlock | /icon reset")
    end
end

SLASH_ICONTRACKER1 = "/icon"
SlashCmdList.ICONTRACKER = Slash

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("UNIT_PET")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if type(IconDB) ~= "table" or IconDB.schemaVersion ~= SCHEMA then
                IconDB = NewDatabase()
            end
            ns.db = IconDB
            -- Development cleanup: remove old Proc rules without erasing
            -- existing Buff/Debuff icons or group positions.
            local removed = {}
            for i = #ns.db.tracked, 1, -1 do
                local entry = ns.db.tracked[i]
                if entry.kind == "PROC" then
                    removed[entry.id] = true
                    table.remove(ns.db.tracked, i)
                else
                    entry.trigger, entry.auraKind = nil, nil
                    if entry.kind == "COOLDOWN" and entry.cooldownMode ~= "ON_COOLDOWN"
                        and entry.cooldownMode ~= "READY" and entry.cooldownMode ~= "ALWAYS" then
                        entry.cooldownMode = "ON_COOLDOWN"
                    end
                end
            end
            for _, group in ipairs(ns.db.groups) do
                for i = #group.members, 1, -1 do
                    if removed[group.members[i]] then table.remove(group.members, i) end
                end
            end
            if removed[ns.testEntryID] then ns.testEntryID = nil end
            for _, group in ipairs(ns.db.groups) do
                -- Previously unnamed groups were displayed as bare numbers.
                if type(group.name) == "string" and group.name:match("^%d+$") then
                    local candidate = "Group " .. group.name
                    if AvailableGroupName(candidate, group.id) then group.name = candidate end
                end
                -- Replace the old automatic rune placeholder; retain chosen custom IDs.
                if not group.icon or group.icon == OLD_DEFAULT_GROUP_ICON then
                    group.icon = ns.DEFAULT_GROUP_ICON
                end
            end
            ns.CreateDisplay()
                    ns.Refresh()
        elseif name == "OmniCC" and ns.db then
            ns.Refresh()
        end
        return
    end
    if not ns.db then return end
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" then ns.Refresh() end
    elseif event == "UNIT_PET" then
        if (...) == "player" then ns.Refresh() end
    elseif event == "PLAYER_DEAD" or event == "PLAYER_ENTERING_WORLD" then
        ns.Refresh()
    else
        ns.Refresh()
    end
end)
