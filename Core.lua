local ADDON_NAME, ns = ...
local events = CreateFrame("Frame")
ns.procWindows = {}
ns.testMode = false

ns.defaults = {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -140,
    size = 36, spacing = 4, locked = true,
    showCountdown = true, showBorder = true,
}

function ns.Print(message)
    print("|cff9f7bffIcon|r: " .. tostring(message))
end

local refreshSerial = 0
function ns.Refresh()
    if not ns.db or not ns.container then return end
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

function ns.AddEntry(entry)
    entry = ns.NormalizeEntry(entry)
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
    ns.db.tracked[#ns.db.tracked + 1] = entry
    ns.EntriesChanged()
    return true, "Added " .. name .. "."
end

function ns.RemoveEntry(index)
    if not ns.db.tracked[index] then return end
    table.remove(ns.db.tracked, index)
    ns.EntriesChanged()
end

function ns.SetTest(value)
    ns.testMode = value == true
    ns.previewStart = ns.testMode and GetTime() or nil
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.ResetSettings()
    for key, value in pairs(ns.defaults) do ns.db[key] = value end
    ns.ApplyPosition()
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
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
        ns.db.locked = command == "lock"
        ns.ApplyMovability()
        ns.Refresh()
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif command == "reset" then
        ns.ResetSettings()
        ns.Print("Visual settings reset. Tracked spells kept.")
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
            IconDB = type(IconDB) == "table" and IconDB or {}
            for key, value in pairs(ns.defaults) do
                if IconDB[key] == nil then IconDB[key] = value end
            end
            IconDB.tracked = type(IconDB.tracked) == "table" and IconDB.tracked or {}
            local cleaned = {}
            for _, item in ipairs(IconDB.tracked) do
                local normalized = ns.NormalizeEntry(item)
                if normalized then cleaned[#cleaned + 1] = normalized end
            end
            IconDB.tracked = cleaned
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
        if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" then
            ns.Refresh()
        end
    elseif event == "UNIT_PET" then
        if (...) == "player" then ns.Refresh() end
    elseif event == "PLAYER_DEAD" then
        ns.ClearProcWindows()
        ns.Refresh()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.ClearProcWindows()
        ns.Refresh()
    else
        ns.Refresh()
    end
end)
