local ADDON_NAME, ns = ...

local panel, spellTab, settingsTab, testButton, spellInput, statusText
local activeTab = "spells"
local refreshers = {}
local page = 1
local PAGE_SIZE = 5
local form = { kind = "BUFF", unit = "player", caster = "ANY", trigger = "AURA", auraKind = "BUFF" }
local selectors = {}
local rows = {}

local function Meta(key)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, key)
    end
    if GetAddOnMetadata then return GetAddOnMetadata(ADDON_NAME, key) end
end

local function Button(parent, text, x, y, width, height, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height or 26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

local function Label(parent, text, x, y, width, font)
    local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then s:SetWidth(width); s:SetJustifyH("LEFT") end
    s:SetText(text)
    return s
end

local function SetStatus(message, bad)
    if not statusText then return end
    statusText:SetText(message or "")
    if bad then statusText:SetTextColor(1, .42, .42)
    else statusText:SetTextColor(.58, .85, .62) end
end

local function RefreshSelectors()
    local names = { BUFF = "Buff", DEBUFF = "Debuff", PROC = "Proc" }
    if selectors.kind then selectors.kind:SetText("Type: " .. names[form.kind]) end
    if selectors.unit then selectors.unit:SetText("Unit: " .. form.unit) end
    if selectors.caster then selectors.caster:SetText("Caster: " .. (form.caster == "MINE" and "Mine" or "Any")) end
    if selectors.trigger then
        local display = { AURA = "Aura", OVERPOWER = "Overpower", COUNTERATTACK = "Counterattack" }
        selectors.trigger:SetText("Trigger: " .. display[form.trigger])
        selectors.trigger:SetShown(form.kind == "PROC")
    end
    if selectors.auraKind then
        selectors.auraKind:SetText("Aura: " .. (form.auraKind == "BUFF" and "Buff" or "Debuff"))
        selectors.auraKind:SetShown(form.kind == "PROC" and form.trigger == "AURA")
    end
    if selectors.unit then selectors.unit:SetEnabled(form.kind ~= "PROC" or form.trigger == "AURA") end
    if selectors.caster then selectors.caster:SetEnabled(form.kind ~= "PROC" or form.trigger == "AURA") end
end

local function Cycle(field, options)
    local current = form[field]
    local nextIndex = 1
    for i, value in ipairs(options) do
        if value == current then nextIndex = i % #options + 1; break end
    end
    form[field] = options[nextIndex]
    if field == "kind" then
        if form.kind == "BUFF" then form.auraKind = "BUFF" end
        if form.kind == "DEBUFF" then form.auraKind = "DEBUFF" end
    end
    if field == "trigger" then
        if form.trigger == "OVERPOWER" then spellInput:SetText("7384") end
        if form.trigger == "COUNTERATTACK" then spellInput:SetText("19306") end
    end
    RefreshSelectors()
end

local function AddSpell()
    local id = tonumber(spellInput:GetText())
    if not id or id < 1 or id ~= math.floor(id) then
        SetStatus("Enter a valid numeric Spell ID.", true)
        return
    end
    local entry = {
        spellID = id, kind = form.kind, unit = form.unit, caster = form.caster,
        trigger = form.trigger, auraKind = form.kind == "PROC" and form.auraKind or form.kind,
        enabled = true,
    }
    local ok, message = ns.AddEntry(entry)
    SetStatus(message, not ok)
    if ok then
        spellInput:SetText("")
        spellInput:ClearFocus()
        page = math.ceil(#ns.db.tracked / PAGE_SIZE)
        ns.RefreshOptions()
    end
end

local function BuildSpells()
    spellTab = CreateFrame("Frame", nil, panel)
    spellTab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -111)
    spellTab:SetSize(565, 410)

    Label(spellTab, "Add spell", 20, -7, 200)
    Label(spellTab, "Spell ID", 20, -33)
    spellInput = CreateFrame("EditBox", nil, spellTab, "InputBoxTemplate")
    spellInput:SetSize(113, 25)
    spellInput:SetPoint("TOPLEFT", spellTab, "TOPLEFT", 25, -54)
    spellInput:SetAutoFocus(false)
    spellInput:SetNumeric(true)
    spellInput:SetMaxLetters(9)
    spellInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    spellInput:SetScript("OnEnterPressed", AddSpell)

    selectors.kind = Button(spellTab, "", 148, -53, 118, 26, function()
        Cycle("kind", { "BUFF", "DEBUFF", "PROC" })
    end)
    selectors.unit = Button(spellTab, "", 271, -53, 125, 26, function()
        Cycle("unit", { "player", "target", "focus", "pet" })
    end)
    selectors.caster = Button(spellTab, "", 401, -53, 141, 26, function()
        Cycle("caster", { "ANY", "MINE" })
    end)
    selectors.trigger = Button(spellTab, "", 20, -87, 190, 25, function()
        Cycle("trigger", { "AURA", "OVERPOWER", "COUNTERATTACK" })
    end)
    selectors.auraKind = Button(spellTab, "", 220, -87, 156, 25, function()
        Cycle("auraKind", { "BUFF", "DEBUFF" })
    end)
    Button(spellTab, "Add", 405, -87, 137, 25, AddSpell)
    statusText = Label(spellTab, "", 20, -123, 520, "GameFontHighlightSmall")

    local line = spellTab:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(.43, .37, .52, .6)
    line:SetPoint("TOPLEFT", 19, -149)
    line:SetSize(526, 1)
    Label(spellTab, "Tracked spells", 20, -160, 300)

    for rowNumber = 1, PAGE_SIZE do
        local index = rowNumber
        local y = -188 - (rowNumber - 1) * 38
        local row = CreateFrame("Frame", nil, spellTab)
        row:SetPoint("TOPLEFT", 20, y)
        row:SetSize(522, 36)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(.18, .16, .22, rowNumber % 2 == 0 and .68 or .45)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(29, 29)
        row.icon:SetPoint("LEFT", 4, 0)
        row.name = Label(row, "", 39, -3, 258, "GameFontHighlight")
        row.description = Label(row, "", 39, -19, 322, "GameFontHighlightSmall")
        row.toggle = Button(row, "On", 385, -5, 55, 25, function()
            local entryIndex = (page - 1) * PAGE_SIZE + index
            local entry = ns.db.tracked[entryIndex]
            if entry then
                entry.enabled = not entry.enabled
                ns.EntriesChanged()
            end
        end)
        row.remove = Button(row, "X", 446, -5, 65, 25, function()
            local entryIndex = (page - 1) * PAGE_SIZE + index
            ns.RemoveEntry(entryIndex)
            if (page - 1) * PAGE_SIZE >= #ns.db.tracked then
                page = math.max(1, page - 1)
            end
            ns.RefreshOptions()
        end)
        rows[index] = row
    end
    local prev = Button(spellTab, "<", 20, -394, 34, 24, function()
        page = math.max(1, page - 1)
        ns.RefreshOptions()
    end)
    local pageLabel = Label(spellTab, "1 / 1", 65, -397, 140, "GameFontHighlightSmall")
    local next = Button(spellTab, ">", 159, -394, 34, 24, function()
        page = page + 1
        ns.RefreshOptions()
    end)
    Label(spellTab, "Click Type / Unit / Caster to cycle options.", 216, -399, 325, "GameFontHighlightSmall")

    refreshers[#refreshers + 1] = function()
        local total = #ns.db.tracked
        local pages = math.max(1, math.ceil(total / PAGE_SIZE))
        page = math.min(page, pages)
        pageLabel:SetText(page .. " / " .. pages .. "   (" .. total .. " total)")
        prev:SetEnabled(page > 1)
        next:SetEnabled(page < pages)
        RefreshSelectors()
        for i, row in ipairs(rows) do
            local entry = ns.db.tracked[(page - 1) * PAGE_SIZE + i]
            row:SetShown(entry ~= nil)
            if entry then
                local name, icon = ns.SpellInfo(entry.spellID)
                row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText((name or "Unknown") .. " |cff9f7bff[" .. entry.spellID .. "]|r")
                local detail = entry.kind .. " · "
                if entry.kind == "PROC" and entry.trigger ~= "AURA" then
                    detail = detail .. entry.trigger
                else
                    detail = detail .. entry.unit .. " · " .. entry.auraKind .. " · " .. entry.caster
                end
                row.description:SetText(detail)
                row.toggle:SetText(entry.enabled and "On" or "Off")
            end
        end
    end
end

local function Save(key, value)
    ns.db[key] = value
    if key == "locked" then ns.ApplyMovability() end
    ns.Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function Checkbox(parent, text, key, x, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(27, 27)
    check:SetPoint("TOPLEFT", x, y)
    local caption = Label(parent, text, x + 31, y - 6, 200)
    check:SetScript("OnClick", function(self) Save(key, self:GetChecked() == true) end)
    refreshers[#refreshers + 1] = function() check:SetChecked(ns.db[key]) end
    return check, caption
end

local function Slider(parent, title, key, low, high, y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 28, y)
    slider:SetSize(332, 18)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local label = Label(parent, title, 28, y + 29, 420)
    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        if updating or not ns.db then return end
        local rounded = math.floor(value + 0.5)
        label:SetText(title .. ": " .. rounded)
        Save(key, rounded)
    end)
    refreshers[#refreshers + 1] = function()
        updating = true
        slider:SetValue(ns.db[key])
        updating = false
        label:SetText(title .. ": " .. ns.db[key])
    end
end

local function BuildSettings()
    settingsTab = CreateFrame("Frame", nil, panel)
    settingsTab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -111)
    settingsTab:SetSize(565, 410)
    Label(settingsTab, "Display", 20, -7)
    Checkbox(settingsTab, "Cooldown Count", "showCountdown", 20, -43)
    Checkbox(settingsTab, "Border", "showBorder", 292, -43)
    Checkbox(settingsTab, "Lock position", "locked", 20, -85)
    Label(settingsTab, "Unlock to drag the icons. Empty groups show a move handle.", 25, -128, 515, "GameFontHighlightSmall")
    Slider(settingsTab, "Icon size", "size", 18, 64, -194)
    Slider(settingsTab, "Spacing", "spacing", 0, 20, -278)
    Button(settingsTab, "Reset visual settings", 20, -345, 242, 28, function()
        ns.ResetSettings()
        SetStatus("Visual settings reset.")
    end)
    Label(settingsTab, "Reset does not delete tracked spells.", 280, -354, 260, "GameFontHighlightSmall")
end

local function ShowTab(which)
    activeTab = which
    spellTab:SetShown(which == "spells")
    settingsTab:SetShown(which == "settings")
    ns.RefreshOptions()
end

function ns.RefreshOptions()
    if not panel or not ns.db then return end
    for _, fn in ipairs(refreshers) do fn() end
    if testButton then testButton:SetText(ns.testMode and "Stop test" or "Start test") end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "IconOptions", UIParent, "BackdropTemplate")
    panel:SetSize(565, 580)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(.08, .08, .10, .97)
    panel:SetBackdropBorderColor(.45, .38, .60)
    local title = Label(panel, (Meta("Title") or "Icon") .. " |cff9f7bffv" .. (Meta("Version") or "0.1.0") .. "|r", 188, -14, 240, "GameFontNormalLarge")
    title:SetJustifyH("CENTER")
    Label(panel, "Author: " .. (Meta("Author") or "Hooch"), 19, -47, 300, "GameFontHighlightSmall")
    Button(panel, "X", 524, -12, 27, 25, function() panel:Hide() end)
    Button(panel, "Spells", 20, -78, 260, 27, function() ShowTab("spells") end)
    Button(panel, "Settings", 286, -78, 260, 27, function() ShowTab("settings") end)
    BuildSpells()
    BuildSettings()
    testButton = Button(panel, "Start test", 20, -533, 255, 28, function() ns.SetTest(not ns.testMode) end)
    Button(panel, "Close", 285, -533, 260, 28, function() panel:Hide() end)
    panel:SetScript("OnShow", ns.RefreshOptions)
    ShowTab(activeTab)
    panel:Hide()
end

function ns.ToggleOptions()
    if not panel then BuildPanel() end
    panel:SetShown(not panel:IsShown())
end
