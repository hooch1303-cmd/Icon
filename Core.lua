local ADDON_NAME, ns = ...
local events = CreateFrame("Frame")
local elapsed = 0
ns.states = {}
ns.testMode = false

function ns.Print(message)
    print("|cff9f7bffIcon 1.0|r: " .. tostring(message))
end

-- Read game state independently by Spell ID: no action bar or macro dependency.
function ns.Refresh()
    if not ns.db then return end
    local nextStates = {}
    local changed = false
    for _, spellID in ipairs(ns.db.tracked) do
        local state = ns.ReadSpellReact(spellID)
        nextStates[spellID] = state
        local old = ns.states[spellID]
        if not old or old.active ~= state.active then changed = true end
    end
    for spellID in pairs(ns.states) do
        if not nextStates[spellID] then changed = true end
    end
    ns.states = nextStates
    if changed then ns.Draw() end
end

local function PrintList()
    if #ns.db.tracked == 0 then
        ns.Print("No tracked spells. Try /icon add 25236")
        return
    end
    for _, id in ipairs(ns.db.tracked) do
        local name = ns.GetSpellInfo(id)
        local state = ns.states[id]
        ns.Print(id .. "  " .. (name or "Unknown") .. "  [" ..
            (state and state.active and "active" or "inactive") .. "]")
    end
end

local function DebugSpell(id)
    id = tonumber(id)
    if not id then ns.Print("Usage: /icon debug <Spell ID>"); return end
    local state = ns.ReadSpellReact(id)
    local name = ns.GetSpellInfo(id)
    ns.Print((name or "Unknown") .. " (" .. id .. ")" ..
        " | supported=" .. tostring(state.supported) ..
        " | known=" .. tostring(state.known) ..
        " | usable=" .. tostring(state.usable) ..
        " | noPower=" .. tostring(state.noPower) ..
        " | overlay=" .. tostring(state.overlay) ..
        " | usableAPI=" .. tostring(state.usableAPI) ..
        " | overlayAPI=" .. tostring(state.overlayAPI) ..
        (ns.IsOverpower(id) and (" | dodgeWindow=" .. string.format("%.1fs", state.remaining or 0) ..
            " | targetMatch=" .. tostring(state.targetMatch)) or "") ..
        " | ACTIVE=" .. tostring(state.active))
end

local function Commands(message)
    if not ns.db then ns.Print("Database isn't initialized."); return end
    local command, arg = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command == "add" then
        local _, reply = ns.AddReact(arg)
        ns.Print(reply)
        ns.Draw() -- New inactive entry must also appear when unlocked.
    elseif command == "remove" then
        local _, reply = ns.RemoveReact(arg)
        ns.Print(reply)
        ns.Draw()
    elseif command == "list" then
        PrintList()
    elseif command == "debug" then
        DebugSpell(arg)
    elseif command == "test" then
        ns.testMode = not ns.testMode
        ns.Draw()
        ns.Print("Test preview " .. (ns.testMode and "enabled" or "disabled") .. ".")
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"
        ns.Draw()
        ns.Print(ns.db.locked and "Icons locked." or "Icons unlocked: drag any icon to move the row.")
    elseif command == "" or command == "help" then
        ns.Print("/icon add <ID> | remove <ID> | list | debug <ID> | test | lock | unlock")
    else
        ns.Print("Unknown command. Type /icon for help.")
    end
end

SLASH_ICON1 = "/icon"
SlashCmdList.ICON = Commands

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= ADDON_NAME then return end
        if not ns.InitDatabase() then return end
        ns.CreateDisplay()
        ns.Refresh()
        ns.Draw()
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("SPELL_UPDATE_USABLE")
        events:RegisterEvent("SPELLS_CHANGED")
        events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        events:RegisterEvent("UNIT_HEALTH")
        events:RegisterEvent("UNIT_POWER_UPDATE")
        events:RegisterEvent("UNIT_AURA")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("PLAYER_DEAD")
        events:RegisterEvent("PLAYER_ALIVE")
        events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
        ns.ClearOverpower()
    end
    if not ns.db or #ns.db.tracked == 0 then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if ns.HandleReactiveCombatLog() then ns.Refresh() end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" and unit ~= "target" then return end
    elseif event == "UNIT_POWER_UPDATE" then
        if (...) ~= "player" then return end
    end
    ns.Refresh()
end)

-- Safety-net polling while tracking: covers missing or client-specific events.
-- Rendering still occurs ONLY when an active state changes.
events:SetScript("OnUpdate", function(_, delta)
    if not ns.db or #ns.db.tracked == 0 then return end
    elapsed = elapsed + delta
    if elapsed >= .20 then
        elapsed = 0
        ns.Refresh()
    end
end)
