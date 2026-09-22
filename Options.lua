local ADDON_NAME, ns = ...

-- Icon 1.0: compact Options window inspired by Icon 0.5.3.
-- This file changes only the UI; it does not replace tracking or saved data.
local panel, panes, widgets
local activePage = "spells"
local selectedSpell, selectedGroup
local spellPage, groupPage, memberPage = 1, 1, 1
local SPELL_PAGE_SIZE, GROUP_PAGE_SIZE, MEMBER_PAGE_SIZE = 5, 6, 3
local FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local BORDER = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Border_squared"
local sliderIndex = 0
local updating = false
local confirmSpell, confirmGroup

local function Label(parent, value, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    label:SetWidth(width)
    label:SetHeight(22)
    label:SetJustifyH("LEFT")
    label:SetText(value or "")
    return label
end

local function Button(parent, title, x, y, width, height, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    button:SetSize(width, height or 26)
    button:SetText(title)
    button:SetScript("OnClick", callback)
    return button
end

local function Edit(parent, x, y, width, numeric, submit)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 5, -y)
    input:SetSize(width - 10, 25)
    input:SetAutoFocus(false)
    if numeric then input:SetNumeric(true); input:SetMaxLetters(10) end
    input:SetScript("OnEnterPressed", function(self)
        if submit then submit(self:GetText()) end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

local function Check(parent, title, x, y, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    check:SetSize(24, 24)
    local label = Label(parent, title, x + 27, y + 1, 142, "GameFontHighlight")
    check:SetScript("OnClick", function(self)
        if not updating then callback(self:GetChecked() == true) end
    end)
    return check, label
end

local function Slider(parent, title, x, y, width, low, high, step, callback)
    sliderIndex = sliderIndex + 1
    local name = "IconClassicOptionsSlider" .. sliderIndex
    local titleLabel = Label(parent, title, x, y - 25, width, "GameFontNormal")
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 5, -y)
    slider:SetSize(width - 15, 16)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    if _G[name .. "Low"] then _G[name .. "Low"]:SetText(tostring(low)) end
    if _G[name .. "High"] then _G[name .. "High"]:SetText(tostring(high)) end
    if _G[name .. "Text"] then _G[name .. "Text"]:SetText("") end
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        callback(math.floor(value / step + .5) * step)
    end)
    return slider, titleLabel
end

local function Backdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(.08, .08, .10, .97)
    frame:SetBackdropBorderColor(.45, .38, .60)
end

local function Row(parent, y, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -y)
    row:SetSize(width, 37)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(.18, .16, .22, .56)
    row.bg = bg
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(29, 29)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(.07, .93, .07, .93)
    row.name = Label(row, "", 42, 2, width - 72, "GameFontHighlight")
    row.desc = Label(row, "", 42, 19, width - 72, "GameFontHighlightSmall")
    row.arrow = Label(row, ">", width - 22, 8, 17, "GameFontHighlight")
    return row
end

local function Refresh()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function Changed()
    ns.Draw()
    Refresh()
end

local function SelectedSettings()
    return selectedSpell and ns.GetIconSettings(selectedSpell)
end

local function SelectedGroup()
    return selectedGroup and ns.GetGroup(selectedGroup)
end

local function SetPage(page)
    if activePage ~= page then
        ns.testSpellID = nil
        ns.Draw()
    end
    activePage = page
    confirmSpell, confirmGroup = nil, nil
    Refresh()
end

local function OpenSpell(id)
    if not ns.GetIconSettings(id) then return end
    if ns.testSpellID ~= id then ns.testSpellID = nil end
    selectedSpell = id
    confirmSpell = nil
    SetPage("entry")
end

local function OpenGroup(id)
    if not ns.GetGroup(id) then return end
    selectedGroup, memberPage, confirmGroup = id, 1, nil
    SetPage("group")
end

local function AddSpell(text)
    local ok, message = ns.AddReact(text)
    ns.Print(message)
    if ok then
        widgets.spellInput:SetText("")
        selectedSpell = tonumber(text)
        OpenSpell(selectedSpell)
    else
        widgets.spellStatus:SetText(message)
    end
end

local function AddGroup(text)
    local ok, result = ns.CreateGroup(text)
    if ok then
        widgets.groupInput:SetText("")
        OpenGroup(result.id)
    else
        widgets.groupStatus:SetText(result)
        ns.Print(result)
    end
end

local function BuildSpells(pane)
    Label(pane, "Add spell", 20, 3, 200, "GameFontNormal")
    Label(pane, "Spell ID", 20, 31, 115, "GameFontHighlightSmall")
    widgets.spellInput = Edit(pane, 20, 55, 118, true, AddSpell)
    Button(pane, "Add", 410, 55, 150, 27, function() AddSpell(widgets.spellInput:GetText()) end)
    widgets.spellStatus = Label(pane, "", 20, 91, 530)
    Label(pane, "Tracked spells - click to edit", 20, 125, 530, "GameFontNormal")
    widgets.spellRows = {}
    for i = 1, SPELL_PAGE_SIZE do
        local row = Row(pane, 154 + (i - 1) * 42, 540)
        row:SetScript("OnClick", function(self)
            if self.id then OpenSpell(self.id) end
        end)
        widgets.spellRows[i] = row
    end
    widgets.spellPrev = Button(pane, "<", 20, 385, 36, 24, function()
        spellPage = math.max(1, spellPage - 1); Refresh()
    end)
    widgets.spellPage = Label(pane, "", 66, 388, 160)
    widgets.spellNext = Button(pane, ">", 218, 385, 36, 24, function()
        spellPage = spellPage + 1; Refresh()
    end)
    Label(pane, "Each spell keeps its own position, size and appearance.", 20, 428, 540)
end

local function BuildGroups(pane)
    Label(pane, "Create group", 20, 3, 260, "GameFontNormal")
    Label(pane, "Group name", 20, 31, 200, "GameFontHighlightSmall")
    widgets.groupInput = Edit(pane, 20, 55, 365, false, AddGroup)
    Button(pane, "Create", 410, 55, 150, 27, function() AddGroup(widgets.groupInput:GetText()) end)
    widgets.groupStatus = Label(pane, "", 20, 91, 530)
    Label(pane, "Groups - click to edit", 20, 125, 530, "GameFontNormal")
    widgets.groupRows = {}
    for i = 1, GROUP_PAGE_SIZE do
        local row = Row(pane, 154 + (i - 1) * 42, 540)
        row:SetScript("OnClick", function(self)
            if self.id then OpenGroup(self.id) end
        end)
        widgets.groupRows[i] = row
    end
    widgets.groupPrev = Button(pane, "<", 20, 428, 36, 24, function()
        groupPage = math.max(1, groupPage - 1); Refresh()
    end)
    widgets.groupPage = Label(pane, "", 66, 431, 160)
    widgets.groupNext = Button(pane, ">", 218, 428, 36, 24, function()
        groupPage = groupPage + 1; Refresh()
    end)
end

local function CommitID(text)
    local settings = SelectedSettings()
    if not settings then return end
    -- Changing the tracked Spell ID requires a different DB action; do not
    -- silently overwrite a key or discard the old settings from this editor.
    if tostring(selectedSpell) ~= tostring(text) then
        widgets.entryStatus:SetText("To change ID, add the new spell and remove the old one.")
    end
end

local function BuildEntry(pane)
    widgets.entryTitle = Label(pane, "", 20, 1, 540, "GameFontNormalLarge")
    widgets.preview = CreateFrame("Frame", nil, pane)
    widgets.preview:SetPoint("TOPLEFT", pane, "TOPLEFT", 25, -50)
    widgets.preview:SetSize(64, 64)
    widgets.previewIcon = widgets.preview:CreateTexture(nil, "ARTWORK")
    widgets.previewIcon:SetAllPoints()
    widgets.previewIcon:SetTexCoord(.07, .93, .07, .93)
    widgets.previewBorder = widgets.preview:CreateTexture(nil, "OVERLAY")
    widgets.previewBorder:SetAllPoints()
    widgets.previewBorder:SetTexture(BORDER)
    widgets.previewCount = widgets.preview:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    widgets.previewCount:SetPoint("CENTER")
    widgets.previewCount:SetText("5")
    widgets.previewCount:SetShadowOffset(1, -1)
    widgets.previewCount:SetShadowColor(0, 0, 0, 1)

    widgets.enabled = Check(pane, "Enabled", 280, 43, function(value)
        local settings = SelectedSettings()
        if settings then settings.enabled = value; Changed() end
    end)
    widgets.lock = Check(pane, "Lock position", 419, 43, function(value)
        local settings = SelectedSettings()
        if settings then
            local group = ns.GetSpellGroup(selectedSpell)
            if group then group.locked = value else settings.locked = value end
            Changed()
        end
    end)
    Label(pane, "Spell ID", 145, 70, 120)
    widgets.entryID = Edit(pane, 145, 91, 116, true, CommitID)
    Button(pane, "Apply ID", 270, 91, 98, 26, function() CommitID(widgets.entryID:GetText()) end)
    widgets.entryGroup = Button(pane, "Group: Solo", 380, 91, 180, 26, function()
        if not selectedSpell then return end
        local from = ns.GetSpellGroup(selectedSpell)
        if from then
            ns.MoveReact(selectedSpell, nil)
        elseif #ns.db.groups > 0 then
            local target = ns.GetGroup(selectedGroup) or ns.db.groups[1]
            ns.MoveReact(selectedSpell, target.id)
        end
        Changed()
    end)
    widgets.entryStatus = Label(pane, "", 145, 122, 415)

    Label(pane, "Tracking", 20, 144, 525, "GameFontNormalLarge")
    widgets.entryTracking = Label(pane, "Spell React - player", 22, 168, 520)

    Label(pane, "Appearance", 20, 192, 525, "GameFontNormalLarge")
    widgets.count, widgets.countLabel = Check(pane, "Countdown", 20, 217, function(value)
        local s = SelectedSettings()
        if s and ns.HasReactCountdown(selectedSpell) then s.countdown = value; Changed() end
    end)
    widgets.border = Check(pane, "Border", 214, 217, function(value)
        local s = SelectedSettings()
        if s then s.border = value; Changed() end
    end)
    widgets.entrySize, widgets.entrySizeLabel = Slider(pane, "Icon size", 27, 275, 236, 20, 100, 1, function(value)
        local s = SelectedSettings()
        if s then s.size = value; Changed() end
    end)
    widgets.entryAlpha, widgets.entryAlphaLabel = Slider(pane, "Icon alpha", 303, 275, 236, 0, 100, 5, function(value)
        local s = SelectedSettings()
        if s then s.alpha = value / 100; Changed() end
    end)
    Label(pane, "Custom Icon FileDataID", 20, 318, 188, "GameFontNormal")
    widgets.iconInput = Edit(pane, 218, 317, 118, true, function(text)
        local s = SelectedSettings()
        local id = tonumber(text)
        if s and id and id >= 1 and id == math.floor(id) then
            s.customIcon = id; Changed()
        else
            widgets.entryStatus:SetText("Enter a positive numeric FileDataID.")
        end
    end)
    Button(pane, "Apply", 349, 317, 84, 26, function()
        local s = SelectedSettings()
        local id = tonumber(widgets.iconInput:GetText())
        if s and id and id >= 1 and id == math.floor(id) then
            s.customIcon = id; Changed()
        else
            widgets.entryStatus:SetText("Enter a positive numeric FileDataID.")
        end
    end)
    Button(pane, "Default", 439, 317, 116, 26, function()
        local s = SelectedSettings()
        if s then s.customIcon = nil; widgets.iconInput:SetText(""); Changed() end
    end)
    Label(pane, "Position", 20, 352, 525, "GameFontNormalLarge")
    widgets.entryPosition = Label(pane, "", 20, 381, 280)
    widgets.resetPosition = Button(pane, "Reset Position", 392, 375, 163, 26, function()
        local s = SelectedSettings()
        if s and not ns.GetSpellGroup(selectedSpell) then
            s.x, s.y = 0, -140; Changed()
        end
    end)
    widgets.entryHint = Label(pane, "", 20, 409, 540)
    widgets.entryTest = Button(pane, "Test icon", 20, 441, 168, 28, function()
        if selectedSpell then
            ns.testSpellID = ns.testSpellID == selectedSpell and nil or selectedSpell
            Changed()
        end
    end)
    widgets.entryRemove = Button(pane, "Remove spell", 390, 441, 170, 28, function()
        if not selectedSpell then return end
        if confirmSpell ~= selectedSpell then
            confirmSpell = selectedSpell
            Refresh()
            return
        end
        local id = selectedSpell
        ns.testSpellID = nil
        ns.RemoveReact(id)
        confirmSpell = nil
        selectedSpell = nil
        spellPage = 1
        SetPage("spells")
    end)
end

local function Cycle(value, values)
    for i, candidate in ipairs(values) do
        if value == candidate then return values[i % #values + 1] end
    end
    return values[1]
end

local function BuildGroup(pane)
    widgets.groupTitle = Label(pane, "", 20, 3, 530, "GameFontNormalLarge")
    widgets.renameInput = Edit(pane, 20, 40, 350, false, function(text)
        local group = SelectedGroup()
        text = text:match("^%s*(.-)%s*$")
        if group and #text > 0 and #text <= 32 then group.name = text; Changed() end
    end)
    Button(pane, "Rename", 395, 40, 165, 26, function()
        local group = SelectedGroup()
        local text = widgets.renameInput:GetText():match("^%s*(.-)%s*$")
        if group and #text > 0 and #text <= 32 then group.name = text; Changed() end
    end)
    widgets.groupLock = Check(pane, "Lock position", 20, 77, function(value)
        local group = SelectedGroup()
        if group then group.locked = value; Changed() end
    end)
    widgets.groupRemove = Button(pane, "Delete group", 395, 76, 165, 27, function()
        local group = SelectedGroup()
        if not group then return end
        if confirmGroup ~= group.id then confirmGroup = group.id; Refresh(); return end
        ns.DeleteGroup(group.id)
        confirmGroup, selectedGroup = nil, nil
        groupPage = 1
        SetPage("groups")
    end)
    Label(pane, "Layout", 20, 110, 530, "GameFontNormalLarge")
    widgets.orientation = Button(pane, "Horizontal", 20, 139, 255, 27, function()
        local group = SelectedGroup()
        if group then group.orientation = Cycle(group.orientation, {"horizontal", "vertical"}); Changed() end
    end)
    widgets.layout = Button(pane, "Compact", 305, 139, 255, 27, function()
        local group = SelectedGroup()
        if group then group.layout = Cycle(group.layout, {"compact", "fixed"}); Changed() end
    end)
    widgets.align = Button(pane, "Center", 20, 177, 255, 27, function()
        local group = SelectedGroup()
        if group then group.alignment = Cycle(group.alignment, {"start", "center", "finish"}); Changed() end
    end)
    widgets.sizeMode = Button(pane, "Individual", 305, 177, 255, 27, function()
        local group = SelectedGroup()
        if group then group.sizeMode = Cycle(group.sizeMode, {"individual", "uniform"}); Changed() end
    end)
    widgets.spacing, widgets.spacingLabel = Slider(pane, "Spacing", 27, 253, 236, 0, 30, 1, function(value)
        local group = SelectedGroup()
        if group then group.spacing = value; Changed() end
    end)
    widgets.groupSize, widgets.groupSizeLabel = Slider(pane, "Group size", 303, 253, 236, 20, 100, 1, function(value)
        local group = SelectedGroup()
        if group then group.size = value; Changed() end
    end)
    widgets.groupPosition = Label(pane, "", 20, 277, 530)
    Label(pane, "Spells in group", 20, 310, 530, "GameFontNormal")
    widgets.members = {}
    for i = 1, MEMBER_PAGE_SIZE do
        local y = 340 + (i - 1) * 34
        local row = {}
        row.name = Label(pane, "", 20, y + 2, 312)
        row.up = Button(pane, "Up", 330, y, 60, 25, function()
            local group = SelectedGroup()
            if group and row.id then ns.MoveGroupMember(group, row.id, -1); Changed() end
        end)
        row.down = Button(pane, "Down", 398, y, 73, 25, function()
            local group = SelectedGroup()
            if group and row.id then ns.MoveGroupMember(group, row.id, 1); Changed() end
        end)
        row.solo = Button(pane, "Solo", 479, y, 81, 25, function()
            if row.id then ns.MoveReact(row.id, nil); Changed() end
        end)
        widgets.members[i] = row
    end
    widgets.memberPrev = Button(pane, "<", 20, 445, 34, 24, function()
        memberPage = math.max(1, memberPage - 1); Refresh()
    end)
    widgets.memberPage = Label(pane, "", 64, 447, 160)
    widgets.memberNext = Button(pane, ">", 206, 445, 34, 24, function()
        memberPage = memberPage + 1; Refresh()
    end)
end

function ns.RefreshOptions()
    if not panel or not ns.db then return end
    updating = true
    local onSpells = activePage == "spells" or activePage == "entry"
    widgets.spellsTab:SetEnabled(not onSpells)
    widgets.groupsTab:SetEnabled(onSpells)
    widgets.global:SetText(ns.db.locked and "Global: Locked" or "Global: Unlocked")
    for name, pane in pairs(panes) do pane:SetShown(name == activePage) end

    if activePage == "spells" then
        local entries = {}
        for _, id in ipairs(ns.db.tracked) do
            if not ns.GetSpellGroup(id) then entries[#entries + 1] = id end
        end
        for _, group in ipairs(ns.db.groups) do
            for _, id in ipairs(group.members) do entries[#entries + 1] = id end
        end
        local pages = math.max(1, math.ceil(#entries / SPELL_PAGE_SIZE))
        spellPage = math.min(spellPage, pages)
        widgets.spellPage:SetText(spellPage .. " / " .. pages)
        widgets.spellPrev:SetEnabled(spellPage > 1)
        widgets.spellNext:SetEnabled(spellPage < pages)
        for i, row in ipairs(widgets.spellRows) do
            local id = entries[(spellPage - 1) * SPELL_PAGE_SIZE + i]
            row.id = id
            row:SetShown(id ~= nil)
            if id then
                local name, icon = ns.GetSpellInfo(id)
                local group = ns.GetSpellGroup(id)
                row.icon:SetTexture(icon or FALLBACK)
                row.name:SetText(name or ("Spell " .. id))
                row.desc:SetText((group and group.name or "Solo") .. " | Spell React | " .. id)
            end
        end
    elseif activePage == "groups" then
        local pages = math.max(1, math.ceil(#ns.db.groups / GROUP_PAGE_SIZE))
        groupPage = math.min(groupPage, pages)
        widgets.groupPage:SetText(groupPage .. " / " .. pages)
        widgets.groupPrev:SetEnabled(groupPage > 1)
        widgets.groupNext:SetEnabled(groupPage < pages)
        for i, row in ipairs(widgets.groupRows) do
            local group = ns.db.groups[(groupPage - 1) * GROUP_PAGE_SIZE + i]
            row.id = group and group.id
            row:SetShown(group ~= nil)
            if group then
                row.icon:SetTexture(FALLBACK)
                row.name:SetText(group.name)
                row.desc:SetText(#group.members .. " spells | " .. group.orientation)
            end
        end
    elseif activePage == "entry" then
        local s = SelectedSettings()
        if not s then updating = false; SetPage("spells"); return end
        local name, icon = ns.GetSpellInfo(selectedSpell)
        local group = ns.GetSpellGroup(selectedSpell)
        widgets.entryTitle:SetText(name or ("Spell " .. selectedSpell))
        widgets.previewIcon:SetTexture(s.customIcon or icon or FALLBACK)
        widgets.preview:SetAlpha(s.alpha)
        widgets.previewBorder:SetShown(s.border)
        local timed = ns.HasReactCountdown(selectedSpell)
        widgets.previewCount:SetShown(timed and s.countdown)
        widgets.enabled:SetChecked(s.enabled)
        widgets.lock:SetChecked(group and group.locked or s.locked)
        if not widgets.entryID:HasFocus() then widgets.entryID:SetText(tostring(selectedSpell)) end
        widgets.entryStatus:SetText(group and "Grouped: return to Solo to move to another group." or "")
        widgets.entryGroup:SetText(group and ("Group: " .. group.name .. " (Solo)") or
            (#ns.db.groups > 0 and ("Group: Solo -> " .. (ns.GetGroup(selectedGroup) or ns.db.groups[1]).name) or "Group: Solo"))
        widgets.entryGroup:SetEnabled(group ~= nil or #ns.db.groups > 0)
        widgets.count:SetChecked(timed and s.countdown)
        widgets.count:SetEnabled(timed)
        widgets.countLabel:SetText(timed and "Countdown" or "Countdown (N/A)")
        widgets.border:SetChecked(s.border)
        widgets.entrySize:SetValue(s.size)
        widgets.entrySizeLabel:SetText("Icon size: " .. s.size .. " px")
        widgets.entryAlpha:SetValue(s.alpha * 100)
        widgets.entryAlphaLabel:SetText("Icon alpha: " .. math.floor(s.alpha * 100 + .5) .. "%")
        if not widgets.iconInput:HasFocus() then
            widgets.iconInput:SetText(s.customIcon and tostring(s.customIcon) or "")
        end
        local pos = group or s
        widgets.entryPosition:SetText(string.format("X: %.0f   Y: %.0f", pos.x, pos.y))
        widgets.resetPosition:SetEnabled(group == nil)
        widgets.entryHint:SetText(group and "Unlock the group to move this icon. Personal size stays saved." or
            "Unlock this icon or Global Lock to drag. Test previews only this spell.")
        widgets.entryTest:SetText(ns.testSpellID == selectedSpell and "Stop test" or "Test icon")
        widgets.entryRemove:SetText(confirmSpell == selectedSpell and "Confirm remove" or "Remove spell")
    elseif activePage == "group" then
        local group = SelectedGroup()
        if not group then updating = false; SetPage("groups"); return end
        widgets.groupTitle:SetText(group.name .. " (" .. #group.members .. ")")
        if not widgets.renameInput:HasFocus() then widgets.renameInput:SetText(group.name) end
        widgets.groupLock:SetChecked(group.locked)
        widgets.groupRemove:SetText(confirmGroup == group.id and "Confirm delete" or "Delete group")
        widgets.orientation:SetText("Orientation: " .. group.orientation)
        widgets.layout:SetText("Layout: " .. group.layout)
        widgets.align:SetText("Alignment: " .. group.alignment)
        widgets.sizeMode:SetText("Sizes: " .. group.sizeMode)
        widgets.spacing:SetValue(group.spacing)
        widgets.spacingLabel:SetText("Spacing: " .. group.spacing .. " px")
        widgets.groupSize:SetValue(group.size)
        widgets.groupSizeLabel:SetText("Group size: " .. group.size .. " px")
        widgets.groupSize:SetEnabled(group.sizeMode == "uniform")
        widgets.groupPosition:SetText(string.format("X: %.0f   Y: %.0f", group.x, group.y))
        local pages = math.max(1, math.ceil(#group.members / MEMBER_PAGE_SIZE))
        memberPage = math.min(memberPage, pages)
        widgets.memberPage:SetText(memberPage .. " / " .. pages)
        widgets.memberPrev:SetEnabled(memberPage > 1)
        widgets.memberNext:SetEnabled(memberPage < pages)
        for i, row in ipairs(widgets.members) do
            local index = (memberPage - 1) * MEMBER_PAGE_SIZE + i
            local id = group.members[index]
            row.id = id
            row.name:SetText(id and ((ns.GetSpellInfo(id) or "Spell") .. " [" .. id .. "]") or "")
            row.up:SetShown(id ~= nil)
            row.down:SetShown(id ~= nil)
            row.solo:SetShown(id ~= nil)
            row.up:SetEnabled(id ~= nil and index > 1)
            row.down:SetEnabled(id ~= nil and index < #group.members)
        end
    end
    updating = false
end

local function BuildPanel()
    panel = CreateFrame("Frame", "IconOptionsFrame", UIParent, "BackdropTemplate")
    panel:SetSize(590, 650)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    Backdrop(panel)
    widgets = {}
    Label(panel, "Icon |cff9f7bff1.0|r", 216, 13, 185, "GameFontNormalLarge")
    Label(panel, "Author: Hooch", 20, 44, 190)
    Button(panel, "X", 548, 12, 27, 25, function() panel:Hide() end)
    widgets.global = Button(panel, "Global: Locked", 360, 43, 215, 25, function()
        ns.db.locked = not ns.db.locked
        Changed()
    end)
    widgets.spellsTab = Button(panel, "Spells", 20, 77, 267, 27, function() SetPage("spells") end)
    widgets.groupsTab = Button(panel, "Groups", 300, 77, 267, 27, function() SetPage("groups") end)
    panes = {}
    for _, name in ipairs({"spells", "groups", "entry", "group"}) do
        local pane = CreateFrame("Frame", nil, panel)
        pane:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -111)
        pane:SetSize(590, 480)
        panes[name] = pane
    end
    BuildSpells(panes.spells)
    BuildGroups(panes.groups)
    BuildEntry(panes.entry)
    BuildGroup(panes.group)
    Button(panel, "Back", 20, 603, 267, 28, function()
        if activePage == "entry" then SetPage("spells")
        elseif activePage == "group" then SetPage("groups")
        else panel:Hide() end
    end)
    Button(panel, "Close", 300, 603, 267, 28, function() panel:Hide() end)
    panel:SetScript("OnShow", ns.RefreshOptions)
    panel:SetScript("OnHide", function()
        if ns.testSpellID then ns.testSpellID = nil; ns.Draw() end
    end)
    panel:Hide()
end

function ns.ToggleOptions()
    if not panel then BuildPanel() end
    panel:SetShown(not panel:IsShown())
end
