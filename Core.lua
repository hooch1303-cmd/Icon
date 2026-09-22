local ADDON_NAME, ns = ...
local events = CreateFrame("Frame")
local elapsed = 0
ns.states = {}
ns.testSpellID = nil

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
        (ns.IsRevenge(id) and (" | revengeWindow=" .. string.format("%.1fs", state.remaining or 0)) or "") ..
        (ns.IsVictoryRush(id) and (" | victoriousAura=" .. tostring(state.victoriousAura) ..
            " | victoryWindow=" .. string.format("%.1fs", state.remaining or 0)) or "") ..
        " | ACTIVE=" .. tostring(state.active))
end

local function Commands(message)
    if not ns.db then ns.Print("Database isn't initialized."); return end
    local command, arg = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command == "add" then
        local _, reply = ns.AddReact(arg)
        ns.Print(reply)
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif command == "remove" then
        local _, reply = ns.RemoveReact(arg)
        ns.Print(reply)
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif command == "list" then
        PrintList()
    elseif command == "debug" then
        DebugSpell(arg)
    elseif command == "test" then
        local id = tonumber(arg)
        if not id or not ns.GetIconSettings(id) then id = ns.db.tracked[1] end
        if not id then ns.Print("No tracked spells to test."); return end
        ns.testSpellID = ns.testSpellID == id and nil or id
        ns.Draw()
        if ns.RefreshOptions then ns.RefreshOptions() end
        ns.Print("Test preview " .. (ns.testSpellID and ("enabled for " .. id) or "disabled") .. ".")
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"
        ns.Draw()
        if ns.RefreshOptions then ns.RefreshOptions() end
        ns.Print(ns.db.locked and "Global lock enabled." or "Global unlock enabled: drag individual icons/groups.")
    elseif command == "" then
        ns.ToggleOptions()
    elseif command == "help" then
        ns.Print("/icon | add <ID> | remove <ID> | list | debug <ID> | test [ID] | lock | unlock")
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
        ns.RefreshKnownReacts()
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
        ns.ClearReactiveWindows()
    end
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        ns.RefreshKnownReacts()
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
        ns.UpdateCountdown()
    end
end)
