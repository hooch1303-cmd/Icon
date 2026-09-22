local ADDON_NAME, ns = ...
local events = CreateFrame("Frame")
ns.procWindows = {}
ns.testMode = false

local SCHEMA = 2 -- Development build: deliberately do not migrate v0.1 saved variables.
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
    end
    ns.Draw(active)
    if earliest and C_Timer and C_Timer.After then
        C_Timer.After(math.max(0.05, earliest - now + 0.05), function()
            if refreshSerial == serial and not ns.testMode then ns.Refresh() end
        end)
    end
end

function ns.UpdateCombatRegistration()
    if ns.HasCombatProcs() then
        events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        events:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ns.ClearProcWindows()
    end
end

function ns.EntriesChanged()
    ns.UpdateCombatRegistration()
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
            and old.unit == entry.unit and old.caster == entry.caster
            and old.trigger == entry.trigger and old.auraKind == entry.auraKind then
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

function ns.RemoveEntry(id)
    local entry = ns.FindEntry(id)
    if not entry then return end
    RemoveMember(ns.FindGroup(entry.groupId), id)
    for index, item in ipairs(ns.db.tracked) do
        if item.id == id then table.remove(ns.db.tracked, index); break end
    end
    ns.EntriesChanged()
end

function ns.CreateGroup(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false, "Enter a group name." end
    if #name > 30 then return false, "Group name must be 30 characters or fewer." end
    for _, group in ipairs(ns.db.groups) do
        if group.name:lower() == name:lower() then return false, "A group with that name exists." end
    end
    local id = ns.db.nextGroupID
    ns.db.nextGroupID = id + 1
    ns.db.groups[#ns.db.groups + 1] = {
        id = id, name = name, members = {},
        point = "CENTER", relativePoint = "CENTER", x = 0,
        y = -140 - (#ns.db.groups * 56),
        orientation = "HORIZONTAL", layout = "FIXED", align = "CENTER",
        sizeMode = "INDIVIDUAL", groupSize = 36, spacing = 4, locked = true,
    }
    ns.EntriesChanged()
    return true, "Created group " .. name .. ".", id
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

function ns.DeleteGroup(id)
    local group = ns.FindGroup(id)
    if not group then return end
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
    ns.previewStart = ns.testMode and GetTime() or nil
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.Reset()
    ns.db = NewDatabase()
    IconDB = ns.db
    ns.testMode = false
    ns.ClearProcWindows()
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
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if type(IconDB) ~= "table" or IconDB.schemaVersion ~= SCHEMA then
                IconDB = NewDatabase()
            end
            ns.db = IconDB
            ns.CreateDisplay()
            ns.UpdateCombatRegistration()
            ns.Refresh()
        elseif name == "OmniCC" and ns.db then
            ns.Refresh()
        end
        return
    end
    if not ns.db then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        ns.HandleCombatLog()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" then ns.Refresh() end
    elseif event == "UNIT_PET" then
        if (...) == "player" then ns.Refresh() end
    elseif event == "PLAYER_DEAD" or event == "PLAYER_ENTERING_WORLD" then
        ns.ClearProcWindows()
        ns.Refresh()
    else
        ns.Refresh()
    end
end)
