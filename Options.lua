local ADDON_NAME, ns = ...

local panel, panes, testButton, closeButton, spellInput, groupInput, statusText, groupStatus
local groupMenu, menuDismiss, menuGroupID, renamePopup, renameName, renameStatus, renameSave, renameGroupID
local iconPopup, iconInput, iconPreview, iconStatus, iconSave, iconGroupID
local spellMenu, menuEntryID, addPopup, addGroupID, addInput, addStatus, addTabs, addPanes
local movePopup, moveEntryID, deletePopup, deleteEntryID, deleteLabel
local OpenSpellMenu, OpenAddPopup, OpenMovePopup, OpenDeletePopup, RefreshAddPopup
local addExistingPage, addSelection, addRecent, addMode = 1, {}, {}, "existing"
local addForm = { kind = "BUFF", unit = "player", caster = "ANY", trigger = "AURA", auraKind = "BUFF" }
local addWidgets = { rows = {}, recent = {} }
local movePage = 1
local MOVE_PAGE_SIZE = 6
local activePage = "spells"
local selectedEntryID, selectedGroupID
local spellPage, groupPage, memberPage = 1, 1, 1
local PAGE_SIZE, GROUP_PAGE_SIZE, MEMBER_PAGE_SIZE = 5, 6, 4
local form = { kind = "BUFF", unit = "player", caster = "ANY", trigger = "AURA", auraKind = "BUFF" }
local widgets = { spellRows = {}, groupRows = {}, memberRows = {} }

local function Meta(key)
    if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata(ADDON_NAME, key) end
    if GetAddOnMetadata then return GetAddOnMetadata(ADDON_NAME, key) end
end

local function Button(parent, text, x, y, width, height, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height or 26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

local function Label(parent, text, x, y, width, font)
    local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then s:SetWidth(width); s:SetJustifyH("LEFT") end
    s:SetText(text)
    return s
end

local function Checkbox(parent, caption, x, y, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(27, 27)
    check:SetPoint("TOPLEFT", x, y)
    local label = Label(parent, caption, x + 30, y - 6, 225)
    check:SetScript("OnClick", function(self) callback(self:GetChecked() == true) end)
    return check, label
end

local function Slider(parent, title, x, y, low, high, callback)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(480, 18)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local caption = Label(parent, title, x, y + 30, 490)
    slider.updating = false
    slider:SetScript("OnValueChanged", function(self, value)
        if self.updating then return end
        local rounded = math.floor(value + .5)
        caption:SetText(title .. ": " .. rounded)
        callback(rounded)
    end)
    function slider:Sync(value)
        self.updating = true
        self:SetValue(value)
        self.updating = false
        caption:SetText(title .. ": " .. value)
    end
    slider.caption = caption
    return slider
end

local function SetStatus(label, message, bad)
    if not label then return end
    label:SetText(message or "")
    if bad then label:SetTextColor(1, .42, .42)
    else label:SetTextColor(.58, .85, .62) end
end

local function CycleValue(current, options)
    for i, value in ipairs(options) do
        if value == current then return options[i % #options + 1] end
    end
    return options[1]
end

local function CloseGroupMenu()
    if groupMenu then groupMenu:Hide() end
    if spellMenu then spellMenu:Hide() end
    if menuDismiss then menuDismiss:Hide() end
    menuGroupID, menuEntryID = nil, nil
end

local function SelectPage(name)
    CloseGroupMenu()
    if addPopup then addPopup:Hide() end
    if movePopup then movePopup:Hide() end
    if deletePopup then deletePopup:Hide() end
    activePage = name
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function OpenEntry(id)
    if not ns.FindEntry(id) then return end
    selectedEntryID = id
    SelectPage("entry")
end

local function OpenGroup(id)
    if not ns.FindGroup(id) then return end
    selectedGroupID = id
    memberPage = 1
    SelectPage("group")
end

local function RefreshForm()
    local typeNames = { BUFF = "Buff", DEBUFF = "Debuff", PROC = "Proc" }
    local triggerNames = { AURA = "Aura", OVERPOWER = "Overpower", COUNTERATTACK = "Counterattack" }
    widgets.formKind:SetText("Type: " .. typeNames[form.kind])
    widgets.formUnit:SetText("Unit: " .. form.unit)
    widgets.formCaster:SetText("Caster: " .. (form.caster == "MINE" and "Mine" or "Any"))
    widgets.formTrigger:SetText("Trigger: " .. triggerNames[form.trigger])
    widgets.formTrigger:SetShown(form.kind == "PROC")
    widgets.formAura:SetText("Aura: " .. (form.auraKind == "BUFF" and "Buff" or "Debuff"))
    widgets.formAura:SetShown(form.kind == "PROC" and form.trigger == "AURA")
    widgets.formUnit:SetEnabled(form.kind ~= "PROC" or form.trigger == "AURA")
    widgets.formCaster:SetEnabled(form.kind ~= "PROC" or form.trigger == "AURA")
end

local function CycleForm(field, options)
    form[field] = CycleValue(form[field], options)
    if field == "kind" then
        if form.kind == "BUFF" or form.kind == "DEBUFF" then form.auraKind = form.kind end
    elseif field == "trigger" then
        if form.trigger == "OVERPOWER" then spellInput:SetText("7384") end
        if form.trigger == "COUNTERATTACK" then spellInput:SetText("19306") end
    end
    RefreshForm()
end

local function AddSpell()
    local id = tonumber(spellInput:GetText())
    if not id or id < 1 or id ~= math.floor(id) then
        SetStatus(statusText, "Enter a valid numeric Spell ID.", true)
        return
    end
    local ok, message = ns.AddEntry({
        spellID = id, kind = form.kind, unit = form.unit, caster = form.caster,
        trigger = form.trigger, auraKind = form.kind == "PROC" and form.auraKind or form.kind,
        enabled = true,
    })
    SetStatus(statusText, message, not ok)
    if ok then
        spellInput:SetText("")
        spellInput:ClearFocus()
        spellPage = math.ceil(#ns.db.tracked / PAGE_SIZE)
        ns.RefreshOptions()
    end
end

local function NewRow(parent, y, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 20, y)
    row:SetSize(width, 36)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(.18, .16, .22, .56)
    return row
end

local function BuildSpells(pane)
    Label(pane, "Add spell", 20, -5)
    Label(pane, "Spell ID", 20, -32)
    spellInput = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    spellInput:SetSize(117, 25)
    spellInput:SetPoint("TOPLEFT", 25, -52)
    spellInput:SetAutoFocus(false)
    spellInput:SetNumeric(true)
    spellInput:SetMaxLetters(9)
    spellInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    spellInput:SetScript("OnEnterPressed", AddSpell)
    widgets.formKind = Button(pane, "", 150, -52, 126, 26, function() CycleForm("kind", { "BUFF", "DEBUFF", "PROC" }) end)
    widgets.formUnit = Button(pane, "", 282, -52, 126, 26, function() CycleForm("unit", { "player", "target", "focus", "pet" }) end)
    widgets.formCaster = Button(pane, "", 414, -52, 145, 26, function() CycleForm("caster", { "ANY", "MINE" }) end)
    widgets.formTrigger = Button(pane, "", 20, -85, 196, 26, function() CycleForm("trigger", { "AURA", "OVERPOWER", "COUNTERATTACK" }) end)
    widgets.formAura = Button(pane, "", 226, -85, 160, 26, function() CycleForm("auraKind", { "BUFF", "DEBUFF" }) end)
    Button(pane, "Add", 414, -85, 145, 26, AddSpell)
    statusText = Label(pane, "", 20, -120, 530, "GameFontHighlightSmall")
    Label(pane, "Tracked spells — left-click to edit, right-click for actions", 20, -152, 550)
    for i = 1, PAGE_SIZE do
        local row = NewRow(pane, -180 - (i - 1) * 40, 540)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(29, 29)
        row.icon:SetPoint("LEFT", 4, 0)
        row.name = Label(row, "", 40, -3, 320, "GameFontHighlight")
        row.desc = Label(row, "", 40, -20, 330, "GameFontHighlightSmall")
        row.arrow = Label(row, ">", 511, -8, 18, "GameFontHighlight")
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetAllPoints(row)
        row.hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.hit:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.hit:SetScript("OnClick", function(_, mouseButton)
            local entry = ns.db.tracked[(spellPage - 1) * PAGE_SIZE + i]
            if not entry then return end
            if mouseButton == "RightButton" then OpenSpellMenu(row, entry.id, i)
            else OpenEntry(entry.id) end
        end)
        widgets.spellRows[i] = row
    end
    widgets.spellPrev = Button(pane, "<", 20, -391, 36, 24, function()
        spellPage = math.max(1, spellPage - 1); ns.RefreshOptions()
    end)
    widgets.spellPages = Label(pane, "", 67, -395, 190, "GameFontHighlightSmall")
    widgets.spellNext = Button(pane, ">", 215, -391, 36, 24, function()
        spellPage = spellPage + 1; ns.RefreshOptions()
    end)
    Label(pane, "Each spell has its own display and position.", 20, -433, 540, "GameFontHighlightSmall")
end

-- Rename and group icon are separate actions. The group icon only appears in
-- the configuration list; the combat display uses each tracked spell's icon.
local function BuildRenamePopup()
    renamePopup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    renamePopup:SetSize(480, 187)
    renamePopup:SetPoint("CENTER", panel, "CENTER")
    renamePopup:SetFrameStrata("FULLSCREEN_DIALOG")
    renamePopup:SetFrameLevel(panel:GetFrameLevel() + 80)
    renamePopup:EnableMouse(true)
    renamePopup:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    renamePopup:SetBackdropColor(.08, .08, .10, .99)
    renamePopup:SetBackdropBorderColor(.58, .43, .78)
    Label(renamePopup, "Rename group", 20, -15, 350, "GameFontNormalLarge")
    Button(renamePopup, "X", 436, -12, 26, 23, function() renamePopup:Hide() end)
    Label(renamePopup, "Name", 22, -51, 155)
    renameName = CreateFrame("EditBox", nil, renamePopup, "InputBoxTemplate")
    renameName:SetSize(422, 25)
    renameName:SetPoint("TOPLEFT", 28, -75)
    renameName:SetAutoFocus(false)
    renameName:SetMaxLetters(30)
    renameName:SetScript("OnEscapePressed", function(self) self:ClearFocus(); renamePopup:Hide() end)
    renameStatus = Label(renamePopup, "", 23, -107, 440, "GameFontHighlightSmall")
    renameSave = Button(renamePopup, "Save", 20, -145, 215, 27, function()
        if not renameGroupID then return end
        local ok, message = ns.RenameGroup(renameGroupID, renameName:GetText())
        if ok then renamePopup:Hide()
        else SetStatus(renameStatus, message, true) end
    end)
    Button(renamePopup, "Cancel", 245, -145, 215, 27, function() renamePopup:Hide() end)
    renameName:SetScript("OnEnterPressed", function(self) self:ClearFocus(); renameSave:Click() end)
    renamePopup:Hide()
end

local function OpenRename(groupID)
    local group = ns.FindGroup(groupID)
    if not group then return end
    CloseGroupMenu()
    renameGroupID = group.id
    renameName:SetText(group.name)
    SetStatus(renameStatus, "", false)
    renamePopup:Show()
    renameName:SetFocus()
    renameName:HighlightText()
end

local function RefreshIconPreview()
    if not iconPopup then return end
    local value = iconInput:GetText()
    if value == "" then
        iconPreview:SetTexture(ns.DEFAULT_GROUP_ICON)
        SetStatus(iconStatus, "Blank ID restores the question mark.", false)
        iconSave:SetEnabled(true)
        return
    end
    local id = tonumber(value)
    if id and id > 0 and id == math.floor(id) then
        iconPreview:SetTexture(id)
        SetStatus(iconStatus, "", false)
        iconSave:SetEnabled(true)
    else
        iconPreview:SetTexture(ns.DEFAULT_GROUP_ICON)
        SetStatus(iconStatus, "Enter a positive numeric Icon ID.", true)
        iconSave:SetEnabled(false)
    end
end

local function BuildIconPopup()
    iconPopup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    iconPopup:SetSize(480, 198)
    iconPopup:SetPoint("CENTER", panel, "CENTER")
    iconPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    iconPopup:SetFrameLevel(panel:GetFrameLevel() + 80)
    iconPopup:EnableMouse(true)
    iconPopup:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    iconPopup:SetBackdropColor(.08, .08, .10, .99)
    iconPopup:SetBackdropBorderColor(.58, .43, .78)
    Label(iconPopup, "Add Group Icon", 20, -15, 350, "GameFontNormalLarge")
    Button(iconPopup, "X", 436, -12, 26, 23, function() iconPopup:Hide() end)
    Label(iconPopup, "Custom Icon ID", 22, -58, 230)
    iconInput = CreateFrame("EditBox", nil, iconPopup, "InputBoxTemplate")
    iconInput:SetSize(275, 25)
    iconInput:SetPoint("TOPLEFT", 28, -81)
    iconInput:SetAutoFocus(false)
    iconInput:SetNumeric(true)
    iconInput:SetMaxLetters(10)
    iconInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); iconPopup:Hide() end)
    iconPreview = iconPopup:CreateTexture(nil, "ARTWORK")
    iconPreview:SetSize(45, 45)
    iconPreview:SetPoint("TOPLEFT", iconPopup, "TOPLEFT", 392, -60)
    iconPreview:SetTexCoord(.07, .93, .07, .93)
    iconStatus = Label(iconPopup, "", 23, -116, 440, "GameFontHighlightSmall")
    iconSave = Button(iconPopup, "Save", 20, -154, 215, 27, function()
        if not iconGroupID then return end
        local text = iconInput:GetText()
        local id = text ~= "" and tonumber(text) or nil
        local ok, message = ns.SetGroupIcon(iconGroupID, id)
        if ok then iconPopup:Hide()
        else SetStatus(iconStatus, message, true) end
    end)
    Button(iconPopup, "Cancel", 245, -154, 215, 27, function() iconPopup:Hide() end)
    iconInput:SetScript("OnTextChanged", RefreshIconPreview)
    iconInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); if iconSave:IsEnabled() then iconSave:Click() end end)
    iconPopup:Hide()
end

local function OpenGroupIcon(groupID)
    local group = ns.FindGroup(groupID)
    if not group then return end
    CloseGroupMenu()
    iconGroupID = group.id
    iconInput:SetText(type(group.icon) == "number" and tostring(group.icon) or "")
    RefreshIconPreview()
    iconPopup:Show()
    iconInput:SetFocus()
    iconInput:HighlightText()
end

local function BuildGroupMenu()
    menuDismiss = CreateFrame("Button", nil, UIParent)
    menuDismiss:SetAllPoints(UIParent)
    menuDismiss:SetFrameStrata("FULLSCREEN_DIALOG")
    menuDismiss:SetFrameLevel(panel:GetFrameLevel() + 55)
    menuDismiss:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    menuDismiss:SetScript("OnClick", CloseGroupMenu)
    menuDismiss:Hide()

    groupMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    groupMenu:SetSize(224, 224)
    groupMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    groupMenu:SetFrameLevel(menuDismiss:GetFrameLevel() + 1)
    groupMenu:SetClampedToScreen(true)
    groupMenu:EnableMouse(true)
    groupMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 13,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    groupMenu:SetBackdropColor(.08, .08, .10, .99)
    groupMenu:SetBackdropBorderColor(.58, .43, .78)

    local actions = {
        { title = "Edit group", run = function(id) OpenGroup(id) end },
        { title = "Add spell", run = function(id) OpenAddPopup(id) end },
        { title = "Start test", run = function(id)
            ns.SetGroupTest(id, ns.testGroupID ~= id)
        end },
        { title = "Unlock position", run = function(id)
            local group = ns.FindGroup(id)
            if group then group.locked = not group.locked; ns.Refresh(); ns.RefreshOptions() end
        end },
        { title = "Rename", run = OpenRename },
        { title = "Add Group Icon", run = OpenGroupIcon },
    }
    groupMenu.actions = actions
    for i, action in ipairs(actions) do
        local b = CreateFrame("Button", nil, groupMenu)
        b:SetSize(208, 31)
        local separatorOffset = (i > 2 and 8 or 0) + (i > 4 and 8 or 0)
        b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 32 - separatorOffset)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        -- Text-only context menu: no decorative action icons.
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b.label:SetText(action.title)
        b:SetScript("OnClick", function()
            local id = menuGroupID
            CloseGroupMenu()
            if id and ns.FindGroup(id) then action.run(id) end
        end)
        action.button = b
    end
    for _, y in ipairs({ -73, -145 }) do
        local line = groupMenu:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(.45, .37, .55, .65)
        line:SetPoint("TOPLEFT", 11, y)
        line:SetSize(202, 1)
    end
    groupMenu:Hide()
end

local function OpenGroupMenu(row, groupID, rowIndex)
    local group = ns.FindGroup(groupID)
    if not group then return end
    CloseGroupMenu()
    menuGroupID = groupID
    groupMenu.actions[3].button.label:SetText(ns.testGroupID == groupID and "Stop test" or "Start test")
    groupMenu.actions[4].button.label:SetText(group.locked and "Unlock position" or "Lock position")
    groupMenu:ClearAllPoints()
    if rowIndex > 3 then
        groupMenu:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, -2)
    else
        groupMenu:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 2)
    end
    menuDismiss:Show()
    groupMenu:Show()
end

-- Shared popup style for the small, self-contained list actions.
local function Popup(width, height)
    local popup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    popup:SetSize(width, height)
    popup:SetPoint("CENTER", panel, "CENTER")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(panel:GetFrameLevel() + 85)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup:SetBackdropColor(.08, .08, .10, .99)
    popup:SetBackdropBorderColor(.58, .43, .78)
    popup:Hide()
    return popup
end

-- This choice moves an existing record; it never creates a second copy.
local function RefreshMovePopup()
    if not movePopup or not movePopup:IsShown() then return end
    local entry = ns.FindEntry(moveEntryID)
    if not entry then movePopup:Hide(); return end
    local destinations = { false }
    for _, group in ipairs(ns.db.groups) do destinations[#destinations + 1] = group.id end
    local pages = math.max(1, math.ceil(#destinations / MOVE_PAGE_SIZE))
    movePage = math.max(1, math.min(movePage, pages))
    movePopup.pages:SetText(movePage .. " / " .. pages)
    movePopup.prev:SetEnabled(movePage > 1)
    movePopup.next:SetEnabled(movePage < pages)
    for i, row in ipairs(movePopup.rows) do
        local ix = (movePage - 1) * MOVE_PAGE_SIZE + i
        local destination = destinations[ix]
        local visible = ix <= #destinations
        row:SetShown(visible)
        if visible then
            local group = destination and ns.FindGroup(destination)
            local current = (entry.groupId or false) == destination
            row.title:SetText((group and group.name or "Solo") .. (current and "  |cff9f7bff(Current)|r" or ""))
            row.subtitle:SetText(group and (#group.members .. " spells") or "Independent icon")
            row:SetEnabled(not current)
        end
    end
end

local function BuildMovePopup()
    movePopup = Popup(480, 445)
    Label(movePopup, "Move to group", 19, -14, 350, "GameFontNormalLarge")
    Button(movePopup, "X", 437, -12, 25, 24, function() movePopup:Hide() end)
    Label(movePopup, "Choose a destination. The spell is moved, not copied.", 20, -48, 445, "GameFontHighlightSmall")
    movePopup.rows = {}
    for i = 1, MOVE_PAGE_SIZE do
        local row = CreateFrame("Button", nil, movePopup)
        row:SetPoint("TOPLEFT", movePopup, "TOPLEFT", 20, -77 - (i - 1) * 46)
        row:SetSize(440, 42)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(.18, .16, .22, .58)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.title = Label(row, "", 11, -4, 390, "GameFontHighlight")
        row.subtitle = Label(row, "", 11, -22, 390, "GameFontHighlightSmall")
        row:SetScript("OnClick", function()
            local ix = (movePage - 1) * MOVE_PAGE_SIZE + i
            local target = ix == 1 and false or (ns.db.groups[ix - 1] and ns.db.groups[ix - 1].id)
            if ix > 1 and not target then return end
            if not ns.FindEntry(moveEntryID) then movePopup:Hide(); return end
            ns.AssignGroup(moveEntryID, target or nil)
            movePopup:Hide()
            if ns.RefreshOptions then ns.RefreshOptions() end
        end)
        movePopup.rows[i] = row
    end
    movePopup.prev = Button(movePopup, "<", 20, -358, 37, 24, function()
        movePage = math.max(1, movePage - 1); RefreshMovePopup()
    end)
    movePopup.pages = Label(movePopup, "", 75, -362, 150, "GameFontHighlightSmall")
    movePopup.next = Button(movePopup, ">", 204, -358, 37, 24, function()
        movePage = movePage + 1; RefreshMovePopup()
    end)
    Button(movePopup, "Cancel", 20, -402, 440, 26, function() movePopup:Hide() end)
end

OpenMovePopup = function(id)
    if not ns.FindEntry(id) then return end
    CloseGroupMenu()
    moveEntryID, movePage = id, 1
    movePopup:Show()
    RefreshMovePopup()
end

local function RefreshAddForm()
    local typeNames = { BUFF = "Buff", DEBUFF = "Debuff", PROC = "Proc" }
    local triggers = { AURA = "Aura", OVERPOWER = "Overpower", COUNTERATTACK = "Counterattack" }
    addWidgets.kind:SetText("Type: " .. typeNames[addForm.kind])
    addWidgets.unit:SetText("Unit: " .. addForm.unit)
    addWidgets.caster:SetText("Caster: " .. (addForm.caster == "MINE" and "Mine" or "Any"))
    addWidgets.trigger:SetText("Trigger: " .. triggers[addForm.trigger])
    addWidgets.trigger:SetShown(addForm.kind == "PROC")
    addWidgets.aura:SetText("Aura: " .. (addForm.auraKind == "BUFF" and "Buff" or "Debuff"))
    addWidgets.aura:SetShown(addForm.kind == "PROC" and addForm.trigger == "AURA")
    local aura = addForm.kind ~= "PROC" or addForm.trigger == "AURA"
    addWidgets.unit:SetEnabled(aura)
    addWidgets.caster:SetEnabled(aura)
end

local function CycleAddForm(field, options)
    addForm[field] = CycleValue(addForm[field], options)
    if field == "kind" and (addForm.kind == "BUFF" or addForm.kind == "DEBUFF") then
        addForm.auraKind = addForm.kind
    elseif field == "trigger" then
        if addForm.trigger == "OVERPOWER" then addInput:SetText("7384") end
        if addForm.trigger == "COUNTERATTACK" then addInput:SetText("19306") end
    end
    RefreshAddForm()
end

RefreshAddPopup = function()
    if not addPopup or not addPopup:IsShown() then return end
    local group = ns.FindGroup(addGroupID)
    if not group then addPopup:Hide(); return end
    addPopup.target:SetText("Group: " .. group.name)
    addPanes.existing:SetShown(addMode == "existing")
    addPanes.new:SetShown(addMode == "new")
    addTabs.existing:SetEnabled(addMode ~= "existing")
    addTabs.new:SetEnabled(addMode ~= "new")
    if addMode == "existing" then
        local candidates = {}
        for _, entry in ipairs(ns.db.tracked) do
            if entry.groupId ~= addGroupID then candidates[#candidates + 1] = entry end
        end
        local pages = math.max(1, math.ceil(#candidates / 5))
        addExistingPage = math.max(1, math.min(addExistingPage, pages))
        addWidgets.pages:SetText(addExistingPage .. " / " .. pages .. "   (" .. #candidates .. " available)")
        addWidgets.prev:SetEnabled(addExistingPage > 1)
        addWidgets.next:SetEnabled(addExistingPage < pages)
        local count = 0
        for entryID, chosen in pairs(addSelection) do
            if chosen and ns.FindEntry(entryID) then count = count + 1 else addSelection[entryID] = nil end
        end
        addWidgets.selected:SetText(count .. " selected")
        addWidgets.addSelected:SetEnabled(count > 0)
        for i, row in ipairs(addWidgets.rows) do
            local entry = candidates[(addExistingPage - 1) * 5 + i]
            row.entryID = entry and entry.id
            row:SetShown(entry ~= nil)
            if entry then
                local name, icon = ns.SpellInfo(entry.spellID)
                row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText((name or "Unknown") .. " [" .. entry.spellID .. "]")
                local source = ns.FindGroup(entry.groupId)
                row.source:SetText(source and ("Group: " .. source.name) or "Solo")
                row.mark:SetText(addSelection[entry.id] and "[x]" or "[ ]")
            end
        end
    else
        RefreshAddForm()
        for i, row in ipairs(addWidgets.recent) do
            local id = addRecent[i]
            local entry = id and ns.FindEntry(id)
            row:SetShown(entry ~= nil)
            if entry then
                local name, icon = ns.SpellInfo(entry.spellID)
                row.name:SetText((name or "Unknown") .. " [" .. entry.spellID .. "]")
                row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
end

local function FinishAdd()
    local id = addGroupID
    addPopup:Hide()
    if ns.FindGroup(id) then OpenGroup(id) else SelectPage("groups") end
end

local function AddSelectedEntries()
    local ids = {}
    for _, entry in ipairs(ns.db.tracked) do
        if entry.groupId ~= addGroupID and addSelection[entry.id] then
            ids[#ids + 1] = entry.id
        end
    end
    for _, id in ipairs(ids) do ns.AssignGroup(id, addGroupID) end
    addSelection = {}
    SetStatus(addWidgets.existingStatus, #ids .. " spell(s) moved to group.", false)
    RefreshAddPopup()
end

local function AddNewEntry()
    local id = tonumber(addInput:GetText())
    if not id or id < 1 or id ~= math.floor(id) then
        SetStatus(addStatus, "Enter a valid numeric Spell ID.", true)
        return
    end
    local ok, message, newID = ns.AddEntry({
        spellID = id, kind = addForm.kind, unit = addForm.unit, caster = addForm.caster,
        trigger = addForm.trigger, auraKind = addForm.kind == "PROC" and addForm.auraKind or addForm.kind,
        enabled = true,
    })
    if not ok then
        SetStatus(addStatus, message, true)
        return
    end
    ns.AssignGroup(newID, addGroupID)
    table.insert(addRecent, 1, newID)
    while #addRecent > 3 do table.remove(addRecent) end
    local group = ns.FindGroup(addGroupID)
    local name = ns.SpellInfo(id)
    SetStatus(addStatus, (name or ("Spell " .. id)) .. " added to " .. (group and group.name or "group") .. ".", false)
    addInput:SetText("")
    addInput:ClearFocus()
    RefreshAddPopup()
end

local function BuildAddPopup()
    addPopup = Popup(548, 506)
    Label(addPopup, "Add spell", 20, -13, 370, "GameFontNormalLarge")
    Button(addPopup, "X", 508, -12, 25, 24, FinishAdd)
    addPopup.target = Label(addPopup, "", 20, -43, 500, "GameFontHighlightSmall")
    addTabs = {}
    addTabs.existing = Button(addPopup, "Existing spells", 20, -73, 250, 27, function()
        addMode = "existing"; RefreshAddPopup()
    end)
    addTabs.new = Button(addPopup, "New spell", 278, -73, 250, 27, function()
        addMode = "new"; RefreshAddPopup()
    end)
    addPanes = {}
    for _, key in ipairs({ "existing", "new" }) do
        local pane = CreateFrame("Frame", nil, addPopup)
        pane:SetSize(548, 340)
        pane:SetPoint("TOPLEFT", addPopup, "TOPLEFT", 0, -111)
        addPanes[key] = pane
    end
    local existing = addPanes.existing
    Label(existing, "Select spells to move (Solo or other groups):", 20, -4, 510, "GameFontHighlightSmall")
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, existing)
        row:SetPoint("TOPLEFT", existing, "TOPLEFT", 20, -30 - (i - 1) * 43)
        row:SetSize(508, 40)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(.18, .16, .22, .58)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.mark = Label(row, "[ ]", 8, -11, 32, "GameFontHighlight")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", row, "LEFT", 40, 0)
        row.name = Label(row, "", 79, -3, 390, "GameFontHighlight")
        row.source = Label(row, "", 79, -21, 390, "GameFontHighlightSmall")
        row:SetScript("OnClick", function(self)
            if not self.entryID then return end
            addSelection[self.entryID] = not addSelection[self.entryID]
            RefreshAddPopup()
        end)
        addWidgets.rows[i] = row
    end
    addWidgets.prev = Button(existing, "<", 20, -253, 36, 24, function()
        addExistingPage = math.max(1, addExistingPage - 1); RefreshAddPopup()
    end)
    addWidgets.pages = Label(existing, "", 65, -257, 200, "GameFontHighlightSmall")
    addWidgets.next = Button(existing, ">", 244, -253, 36, 24, function()
        addExistingPage = addExistingPage + 1; RefreshAddPopup()
    end)
    addWidgets.selected = Label(existing, "0 selected", 20, -290, 235, "GameFontHighlightSmall")
    addWidgets.addSelected = Button(existing, "Add selected", 320, -282, 208, 27, AddSelectedEntries)
    addWidgets.existingStatus = Label(existing, "", 20, -322, 508, "GameFontHighlightSmall")

    local newer = addPanes.new
    Label(newer, "Spell ID", 20, -8)
    addInput = CreateFrame("EditBox", nil, newer, "InputBoxTemplate")
    addInput:SetSize(106, 25)
    addInput:SetPoint("TOPLEFT", newer, "TOPLEFT", 25, -33)
    addInput:SetAutoFocus(false)
    addInput:SetNumeric(true)
    addInput:SetMaxLetters(9)
    addInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addInput:SetScript("OnEnterPressed", AddNewEntry)
    addWidgets.kind = Button(newer, "", 145, -33, 119, 26, function() CycleAddForm("kind", { "BUFF", "DEBUFF", "PROC" }) end)
    addWidgets.unit = Button(newer, "", 270, -33, 119, 26, function() CycleAddForm("unit", { "player", "target", "focus", "pet" }) end)
    addWidgets.caster = Button(newer, "", 395, -33, 132, 26, function() CycleAddForm("caster", { "ANY", "MINE" }) end)
    addWidgets.trigger = Button(newer, "", 20, -69, 205, 26, function() CycleAddForm("trigger", { "AURA", "OVERPOWER", "COUNTERATTACK" }) end)
    addWidgets.aura = Button(newer, "", 235, -69, 155, 26, function() CycleAddForm("auraKind", { "BUFF", "DEBUFF" }) end)
    addStatus = Label(newer, "", 20, -109, 508, "GameFontHighlightSmall")
    Label(newer, "Recently added — click Edit for individual settings", 20, -147, 508, "GameFontNormal")
    for i = 1, 3 do
        local row = NewRow(newer, -171 - (i - 1) * 40, 508)
        row:SetHeight(36)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", 5, 0)
        row.icon:SetSize(29, 29)
        row.name = Label(row, "", 40, -10, 340, "GameFontHighlight")
        row.edit = Button(row, "Edit", 408, -5, 87, 25, function()
            local id = addRecent[i]
            if id and ns.FindEntry(id) then
                addPopup:Hide()
                OpenEntry(id)
            end
        end)
        addWidgets.recent[i] = row
    end
    Button(newer, "Add", 320, -310, 208, 27, AddNewEntry)
    Button(addPopup, "Done", 20, -460, 508, 28, FinishAdd)
end

OpenAddPopup = function(id)
    if not ns.FindGroup(id) then return end
    CloseGroupMenu()
    addGroupID, addMode, addExistingPage = id, "existing", 1
    addSelection, addRecent = {}, {}
    addInput:SetText("")
    SetStatus(addStatus, "", false)
    SetStatus(addWidgets.existingStatus, "", false)
    addPopup:Show()
    RefreshAddPopup()
end

local function BuildDeletePopup()
    deletePopup = Popup(475, 198)
    Label(deletePopup, "Delete spell", 20, -14, 370, "GameFontNormalLarge")
    Button(deletePopup, "X", 434, -12, 25, 24, function() deletePopup:Hide() end)
    deleteLabel = Label(deletePopup, "", 20, -58, 430, "GameFontHighlight")
    Label(deletePopup, "This also removes its individual settings.", 20, -88, 430, "GameFontHighlightSmall")
    Button(deletePopup, "Delete", 20, -152, 210, 27, function()
        local id = deleteEntryID
        deletePopup:Hide()
        if id and ns.FindEntry(id) then
            ns.RemoveEntry(id)
            if activePage == "entry" and selectedEntryID == id then
                selectedEntryID = nil
                SelectPage("spells")
            end
        end
    end)
    Button(deletePopup, "Cancel", 244, -152, 210, 27, function() deletePopup:Hide() end)
end

OpenDeletePopup = function(id)
    local entry = ns.FindEntry(id)
    if not entry then return end
    CloseGroupMenu()
    deleteEntryID = id
    local name = ns.SpellInfo(entry.spellID)
    deleteLabel:SetText("Delete " .. (name or ("Spell " .. entry.spellID)) .. " [" .. entry.spellID .. "]?")
    deletePopup:Show()
end

local function BuildSpellMenu()
    spellMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    spellMenu:SetSize(224, 224)
    spellMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    spellMenu:SetFrameLevel(menuDismiss:GetFrameLevel() + 1)
    spellMenu:SetClampedToScreen(true)
    spellMenu:EnableMouse(true)
    spellMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 13,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    spellMenu:SetBackdropColor(.08, .08, .10, .99)
    spellMenu:SetBackdropBorderColor(.58, .43, .78)
    local actions = {
        { title = "Edit spell", run = function(id) OpenEntry(id) end },
        { title = "Move to group", run = function(id) OpenMovePopup(id) end },
        { title = "Start test", run = function(id)
            ns.SetEntryTest(id, ns.testEntryID ~= id)
        end },
        { title = "Unlock position", run = function(id)
            local entry = ns.FindEntry(id)
            if not entry then return end
            local item = ns.FindGroup(entry.groupId) or entry
            item.locked = not item.locked
            ns.Refresh()
            ns.RefreshOptions()
        end },
        { title = "Disable spell", run = function(id)
            local entry = ns.FindEntry(id)
            if entry then entry.enabled = not entry.enabled; ns.EntriesChanged() end
        end },
        { title = "Delete spell", run = OpenDeletePopup },
    }
    spellMenu.actions = actions
    for i, action in ipairs(actions) do
        local b = CreateFrame("Button", nil, spellMenu)
        b:SetSize(208, 31)
        local offset = (i > 2 and 8 or 0) + (i > 4 and 8 or 0)
        b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 32 - offset)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b.label:SetText(action.title)
        b:SetScript("OnClick", function()
            local id = menuEntryID
            CloseGroupMenu()
            if id and ns.FindEntry(id) then action.run(id) end
        end)
        action.button = b
    end
    for _, y in ipairs({ -73, -145 }) do
        local line = spellMenu:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(.45, .37, .55, .65)
        line:SetPoint("TOPLEFT", 11, y)
        line:SetSize(202, 1)
    end
    spellMenu:Hide()
end

OpenSpellMenu = function(row, id, rowIndex)
    local entry = ns.FindEntry(id)
    if not entry then return end
    CloseGroupMenu()
    menuEntryID = id
    local group = ns.FindGroup(entry.groupId)
    local item = group or entry
    spellMenu.actions[3].button.label:SetText(ns.testEntryID == id and "Stop test" or "Start test")
    spellMenu.actions[4].button.label:SetText(group
        and (item.locked and "Unlock group position" or "Lock group position")
        or (item.locked and "Unlock position" or "Lock position"))
    spellMenu.actions[5].button.label:SetText(entry.enabled and "Disable spell" or "Enable spell")
    spellMenu:ClearAllPoints()
    if rowIndex > 3 then
        spellMenu:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, -2)
    else
        spellMenu:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 2)
    end
    menuDismiss:Show()
    spellMenu:Show()
end

local function BuildGroups(pane)
    Label(pane, "Create group (name optional)", 20, -6)
    groupInput = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    groupInput:SetSize(335, 25)
    groupInput:SetPoint("TOPLEFT", 25, -33)
    groupInput:SetAutoFocus(false)
    groupInput:SetMaxLetters(30)
    groupInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function AddGroup()
        local ok, message = ns.CreateGroup(groupInput:GetText())
        SetStatus(groupStatus, message, not ok)
        if ok then
            groupInput:SetText("")
            groupInput:ClearFocus()
            groupPage = math.ceil(#ns.db.groups / GROUP_PAGE_SIZE)
            ns.RefreshOptions()
        end
    end
    groupInput:SetScript("OnEnterPressed", AddGroup)
    Button(pane, "Create", 412, -33, 147, 26, AddGroup)
    groupStatus = Label(pane, "Leave blank for Group 1, Group 2, etc.", 20, -71, 530, "GameFontHighlightSmall")
    Label(pane, "Groups — left-click to edit, right-click for actions", 20, -102, 540)
    for i = 1, GROUP_PAGE_SIZE do
        local row = NewRow(pane, -133 - (i - 1) * 44, 540)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 7, 0)
        row.icon:SetTexCoord(.07, .93, .07, .93)
        row.name = Label(row, "", 50, -5, 390, "GameFontHighlight")
        row.desc = Label(row, "", 50, -21, 390, "GameFontHighlightSmall")
        row.arrow = Label(row, ">", 513, -9, 20, "GameFontHighlight")
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetAllPoints(row)
        row.hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.hit:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.hit:SetScript("OnClick", function(_, mouseButton)
            local group = ns.db.groups[(groupPage - 1) * GROUP_PAGE_SIZE + i]
            if not group then return end
            if mouseButton == "RightButton" then OpenGroupMenu(row, group.id, i)
            else OpenGroup(group.id) end
        end)
        widgets.groupRows[i] = row
    end
    widgets.groupPrev = Button(pane, "<", 20, -412, 36, 24, function()
        groupPage = math.max(1, groupPage - 1); ns.RefreshOptions()
    end)
    widgets.groupPages = Label(pane, "", 67, -416, 190, "GameFontHighlightSmall")
    widgets.groupNext = Button(pane, ">", 215, -412, 36, 24, function()
        groupPage = groupPage + 1; ns.RefreshOptions()
    end)
    Label(pane, "Right-click a group to add or move spells.", 20, -450, 545, "GameFontHighlightSmall")
end

local function ChangeEntry(field, options)
    local entry = ns.FindEntry(selectedEntryID)
    if not entry then return end
    entry[field] = CycleValue(entry[field], options)
    if field == "kind" then
        if entry.kind == "BUFF" or entry.kind == "DEBUFF" then
            entry.trigger, entry.auraKind = "AURA", entry.kind
        end
    elseif field == "trigger" then
        if entry.trigger == "OVERPOWER" then entry.spellID = 7384 end
        if entry.trigger == "COUNTERATTACK" then entry.spellID = 19306 end
    end
    ns.EntriesChanged()
end

local function BuildEntry(pane)
    widgets.entryIcon = pane:CreateTexture(nil, "ARTWORK")
    widgets.entryIcon:SetSize(36, 36)
    widgets.entryIcon:SetPoint("TOPLEFT", 22, -6)
    widgets.entryTitle = Label(pane, "", 68, -7, 420, "GameFontNormalLarge")
    widgets.entryID = Label(pane, "", 69, -30, 405, "GameFontHighlightSmall")
    widgets.entryKind = Button(pane, "", 20, -62, 166, 27, function() ChangeEntry("kind", { "BUFF", "DEBUFF", "PROC" }) end)
    widgets.entryUnit = Button(pane, "", 195, -62, 166, 27, function() ChangeEntry("unit", { "player", "target", "focus", "pet" }) end)
    widgets.entryCaster = Button(pane, "", 370, -62, 190, 27, function() ChangeEntry("caster", { "ANY", "MINE" }) end)
    widgets.entryTrigger = Button(pane, "", 20, -99, 263, 27, function() ChangeEntry("trigger", { "AURA", "OVERPOWER", "COUNTERATTACK" }) end)
    widgets.entryAura = Button(pane, "", 292, -99, 267, 27, function() ChangeEntry("auraKind", { "BUFF", "DEBUFF" }) end)
    widgets.entryGroup = Button(pane, "", 20, -140, 540, 29, function()
        local entry = ns.FindEntry(selectedEntryID)
        if not entry then return end
        local groups = { false }
        for _, group in ipairs(ns.db.groups) do groups[#groups + 1] = group.id end
        local current = entry.groupId or false
        local nextID = CycleValue(current, groups)
        ns.AssignGroup(entry.id, nextID or nil)
    end)
    widgets.entryCount = Checkbox(pane, "Cooldown Count", 20, -188, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showCountdown = checked; ns.Refresh() end
    end)
    widgets.entryBorder = Checkbox(pane, "Border", 300, -188, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showBorder = checked; ns.Refresh() end
    end)
    widgets.entryStacks = Checkbox(pane, "Show stacks / charges", 20, -227, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showStacks = checked; ns.Refresh() end
    end)
    widgets.entryLock, widgets.entryLockLabel = Checkbox(pane, "Lock position (solo only)", 300, -227, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry and not entry.groupId then entry.locked = checked; ns.Refresh() end
    end)
    widgets.entrySize = Slider(pane, "Icon size", 28, -333, 18, 100, function(value)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.size = value; ns.Refresh() end
    end)
    widgets.entryHint = Label(pane, "Unlock and drag the icon to set its position.", 20, -372, 540, "GameFontHighlightSmall")
    Button(pane, "Remove spell", 20, -426, 200, 28, function()
        if selectedEntryID then OpenDeletePopup(selectedEntryID) end
    end)
    Label(pane, "To edit Spell ID, remove and add the spell again.", 240, -433, 325, "GameFontHighlightSmall")
end

local function BuildGroup(pane)
    widgets.groupTitle = Label(pane, "", 20, -9, 310, "GameFontNormalLarge")
    widgets.groupLock = Checkbox(pane, "Lock position", 328, -5, function(checked)
        local group = ns.FindGroup(selectedGroupID)
        if group then group.locked = checked; ns.Refresh() end
    end)
    widgets.groupOrientation = Button(pane, "", 20, -54, 264, 27, function()
        local group = ns.FindGroup(selectedGroupID)
        if group then group.orientation = CycleValue(group.orientation, { "HORIZONTAL", "VERTICAL" }); ns.EntriesChanged() end
    end)
    widgets.groupLayout = Button(pane, "", 295, -54, 264, 27, function()
        local group = ns.FindGroup(selectedGroupID)
        if group then group.layout = CycleValue(group.layout, { "COMPACT", "FIXED" }); ns.EntriesChanged() end
    end)
    widgets.groupAlignment = Button(pane, "", 20, -90, 264, 27, function()
        local group = ns.FindGroup(selectedGroupID)
        if group then group.align = CycleValue(group.align, { "CENTER", "START", "END" }); ns.EntriesChanged() end
    end)
    widgets.groupSizeMode = Button(pane, "", 295, -90, 264, 27, function()
        local group = ns.FindGroup(selectedGroupID)
        if group then group.sizeMode = CycleValue(group.sizeMode, { "INDIVIDUAL", "UNIFORM" }); ns.EntriesChanged() end
    end)
    widgets.groupSpacing = Slider(pane, "Spacing", 28, -164, 0, 24, function(value)
        local group = ns.FindGroup(selectedGroupID)
        if group then group.spacing = value; ns.Refresh() end
    end)
    widgets.groupSize = Slider(pane, "Group icon size", 28, -236, 18, 100, function(value)
        local group = ns.FindGroup(selectedGroupID)
        if group then group.groupSize = value; ns.Refresh() end
    end)
    widgets.memberHeading = Label(pane, "Spells in group", 20, -266, 340)
    Button(pane, "Add spell", 408, -261, 151, 24, function()
        if selectedGroupID then OpenAddPopup(selectedGroupID) end
    end)
    for i = 1, MEMBER_PAGE_SIZE do
        local row = NewRow(pane, -288 - (i - 1) * 36, 540)
        row:SetHeight(33)
        row.name = Label(row, "", 9, -8, 270, "GameFontHighlight")
        row.edit = Button(row, "Edit", 311, -4, 75, 24, function()
            local group = ns.FindGroup(selectedGroupID)
            local id = group and group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            if id then OpenEntry(id) end
        end)
        row.up = Button(row, "^", 392, -4, 62, 24, function()
            local group = ns.FindGroup(selectedGroupID)
            local id = group and group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            if id then ns.MoveMember(group.id, id, -1) end
        end)
        row.down = Button(row, "v", 461, -4, 63, 24, function()
            local group = ns.FindGroup(selectedGroupID)
            local id = group and group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            if id then ns.MoveMember(group.id, id, 1) end
        end)
        widgets.memberRows[i] = row
    end
    widgets.memberPrev = Button(pane, "<", 20, -438, 34, 24, function()
        memberPage = math.max(1, memberPage - 1); ns.RefreshOptions()
    end)
    widgets.memberPages = Label(pane, "", 65, -441, 155, "GameFontHighlightSmall")
    widgets.memberNext = Button(pane, ">", 180, -438, 34, 24, function()
        memberPage = memberPage + 1; ns.RefreshOptions()
    end)
    Button(pane, "Delete group", 355, -437, 205, 26, function()
        local id = selectedGroupID
        selectedGroupID = nil
        ns.DeleteGroup(id) -- Members become independent icons; spells are not deleted.
        SelectPage("groups")
    end)
end

local function RefreshSpells()
    local total = #ns.db.tracked
    local pages = math.max(1, math.ceil(total / PAGE_SIZE))
    spellPage = math.max(1, math.min(spellPage, pages))
    widgets.spellPrev:SetEnabled(spellPage > 1)
    widgets.spellNext:SetEnabled(spellPage < pages)
    widgets.spellPages:SetText(spellPage .. " / " .. pages .. "   (" .. total .. " total)")
    RefreshForm()
    for i, row in ipairs(widgets.spellRows) do
        local entry = ns.db.tracked[(spellPage - 1) * PAGE_SIZE + i]
        row:SetShown(entry ~= nil)
        if entry then
            local name, icon = ns.SpellInfo(entry.spellID)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText((name or "Unknown") .. " |cff9f7bff[" .. entry.spellID .. "]|r")
            local group = ns.FindGroup(entry.groupId)
            row.desc:SetText(entry.kind .. " · " .. (group and ("Group: " .. group.name) or (entry.unit .. " · " .. entry.auraKind .. " · " .. entry.caster)))
            if not entry.enabled then
                row.desc:SetText(row.desc:GetText() .. " · Disabled")
            end
        end
    end
end

local function RefreshGroups()
    local total = #ns.db.groups
    local pages = math.max(1, math.ceil(total / GROUP_PAGE_SIZE))
    groupPage = math.max(1, math.min(groupPage, pages))
    widgets.groupPrev:SetEnabled(groupPage > 1)
    widgets.groupNext:SetEnabled(groupPage < pages)
    widgets.groupPages:SetText(groupPage .. " / " .. pages .. "   (" .. total .. " total)")
    for i, row in ipairs(widgets.groupRows) do
        local group = ns.db.groups[(groupPage - 1) * GROUP_PAGE_SIZE + i]
        row:SetShown(group ~= nil)
        if group then
            row.name:SetText(group.name)
            row.icon:SetTexture(group.icon or ns.DEFAULT_GROUP_ICON)
            local count = #group.members
            row.desc:SetText(count == 0 and "Empty group" or (count .. (count == 1 and " spell" or " spells")))
        end
    end
end

local function RefreshEntry()
    local entry = ns.FindEntry(selectedEntryID)
    if not entry then SelectPage("spells"); return end
    local name, icon = ns.SpellInfo(entry.spellID)
    widgets.entryIcon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    widgets.entryTitle:SetText(name or "Unknown spell")
    widgets.entryID:SetText("Spell ID: " .. entry.spellID)
    widgets.entryKind:SetText("Type: " .. entry.kind)
    widgets.entryUnit:SetText("Unit: " .. entry.unit)
    widgets.entryCaster:SetText("Caster: " .. (entry.caster == "MINE" and "Mine" or "Any"))
    widgets.entryTrigger:SetText("Trigger: " .. entry.trigger)
    widgets.entryAura:SetText("Aura: " .. entry.auraKind)
    widgets.entryTrigger:SetShown(entry.kind == "PROC")
    widgets.entryAura:SetShown(entry.kind == "PROC" and entry.trigger == "AURA")
    local usesAura = entry.kind ~= "PROC" or entry.trigger == "AURA"
    widgets.entryUnit:SetEnabled(usesAura)
    widgets.entryCaster:SetEnabled(usesAura)
    local group = ns.FindGroup(entry.groupId)
    widgets.entryGroup:SetText("Group: " .. (group and group.name or "Solo") .. "   (click to change)")
    widgets.entryCount:SetChecked(entry.showCountdown)
    widgets.entryBorder:SetChecked(entry.showBorder)
    widgets.entryStacks:SetChecked(entry.showStacks)
    widgets.entryLock:SetChecked(group and group.locked or (not group and entry.locked))
    widgets.entryLock:SetEnabled(not group)
    widgets.entryLockLabel:SetText(group and "Lock position (controlled by group)" or "Lock position")
    widgets.entrySize:Sync(entry.size)
    widgets.entrySize:SetEnabled(not group or group.sizeMode == "INDIVIDUAL")
    widgets.entryHint:SetText(group and "Drag the group. Icon size is overridden in Uniform mode." or "Unlock and drag this icon to set its position.")
end

local function RefreshGroup()
    local group = ns.FindGroup(selectedGroupID)
    if not group then SelectPage("groups"); return end
    widgets.groupTitle:SetText(group.name .. "  (" .. #group.members .. ")")
    widgets.groupLock:SetChecked(group.locked)
    widgets.groupOrientation:SetText("Orientation: " .. (group.orientation == "VERTICAL" and "Vertical" or "Horizontal"))
    widgets.groupLayout:SetText("Layout: " .. (group.layout == "FIXED" and "Fixed" or "Compact"))
    local alignName
    if group.align == "CENTER" then alignName = "Center"
    elseif group.orientation == "VERTICAL" then alignName = group.align == "START" and "Left" or "Right"
    else alignName = group.align == "START" and "Top" or "Bottom" end
    widgets.groupAlignment:SetText("Alignment: " .. alignName)
    widgets.groupSizeMode:SetText("Icon size: " .. (group.sizeMode == "UNIFORM" and "Uniform" or "Individual"))
    widgets.groupSpacing:Sync(group.spacing)
    widgets.groupSize:Sync(group.groupSize)
    widgets.groupSize:SetShown(group.sizeMode == "UNIFORM")
    widgets.groupSize.caption:SetShown(group.sizeMode == "UNIFORM")
    widgets.memberHeading:SetText("Spells in group — " .. #group.members .. " total")
    local pages = math.max(1, math.ceil(#group.members / MEMBER_PAGE_SIZE))
    memberPage = math.max(1, math.min(memberPage, pages))
    widgets.memberPrev:SetEnabled(memberPage > 1)
    widgets.memberNext:SetEnabled(memberPage < pages)
    widgets.memberPages:SetText(memberPage .. " / " .. pages)
    for i, row in ipairs(widgets.memberRows) do
        local index = (memberPage - 1) * MEMBER_PAGE_SIZE + i
        local id = group.members[index]
        local entry = id and ns.FindEntry(id)
        row:SetShown(entry ~= nil)
        if entry then
            local name = ns.SpellInfo(entry.spellID)
            row.name:SetText((name or "Unknown") .. " [" .. entry.spellID .. "]")
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #group.members)
        end
    end
end

function ns.RefreshOptions()
    if not panel or not ns.db then return end
    panes.spells:SetShown(activePage == "spells")
    panes.groups:SetShown(activePage == "groups")
    panes.entry:SetShown(activePage == "entry")
    panes.group:SetShown(activePage == "group")
    widgets.spellsTab:SetText(activePage == "entry" and "< Back to Spells" or "Spells")
    widgets.groupsTab:SetText(activePage == "group" and "< Back to Groups" or "Groups")
    if activePage == "spells" then RefreshSpells()
    elseif activePage == "groups" then RefreshGroups()
    elseif activePage == "entry" then RefreshEntry()
    elseif activePage == "group" then RefreshGroup() end
    -- The global preview belongs to Spells, not the Groups list or a group editor.
    testButton:SetShown(activePage == "spells")
    closeButton:ClearAllPoints()
    if activePage == "spells" then
        closeButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -600)
        closeButton:SetSize(267, 28)
    else
        closeButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -600)
        closeButton:SetSize(547, 28)
    end
    testButton:SetText(ns.testMode and "Stop test" or "Start test")
    if addPopup and addPopup:IsShown() and RefreshAddPopup then RefreshAddPopup() end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "IconOptions", UIParent, "BackdropTemplate")
    panel:SetSize(590, 650)
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
    local title = Label(panel, (Meta("Title") or "Icon") .. " |cff9f7bffv" .. (Meta("Version") or "0.4.0") .. "|r", 181, -14, 275, "GameFontNormalLarge")
    title:SetJustifyH("CENTER")
    Label(panel, "Author: " .. (Meta("Author") or "Hooch"), 19, -46, 300, "GameFontHighlightSmall")
    Button(panel, "X", 550, -12, 27, 25, function() panel:Hide() end)
    widgets.spellsTab = Button(panel, "Spells", 20, -77, 267, 27, function() SelectPage("spells") end)
    widgets.groupsTab = Button(panel, "Groups", 300, -77, 267, 27, function() SelectPage("groups") end)
    panes = {}
    for _, name in ipairs({ "spells", "groups", "entry", "group" }) do
        local body = CreateFrame("Frame", nil, panel)
        body:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -111)
        body:SetSize(590, 480)
        panes[name] = body
    end
    BuildSpells(panes.spells)
    BuildRenamePopup()
    BuildIconPopup()
    BuildGroupMenu()
    BuildSpellMenu()
    BuildMovePopup()
    BuildAddPopup()
    BuildDeletePopup()
    BuildGroups(panes.groups)
    BuildEntry(panes.entry)
    BuildGroup(panes.group)
    testButton = Button(panel, "Start test", 20, -600, 267, 28, function() ns.SetTest(not ns.testMode) end)
    closeButton = Button(panel, "Close", 300, -600, 267, 28, function() panel:Hide() end)
    panel:SetScript("OnHide", function()
        CloseGroupMenu()
        if renamePopup then renamePopup:Hide() end
        if iconPopup then iconPopup:Hide() end
        if movePopup then movePopup:Hide() end
        if addPopup then addPopup:Hide() end
        if deletePopup then deletePopup:Hide() end
    end)
    panel:SetScript("OnShow", ns.RefreshOptions)
    ns.RefreshOptions()
    panel:Hide()
end

function ns.ToggleOptions()
    if not panel then BuildPanel() end
    panel:SetShown(not panel:IsShown())
end
