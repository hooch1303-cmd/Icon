local ADDON_NAME, ns = ...

local panel, panes, testButton, closeButton, spellInput, groupInput, statusText, groupStatus
local groupMenu, menuDismiss, menuGroupID, renamePopup, renameName, renameStatus, renameSave, renameGroupID
local iconPopup, iconInput, iconPreview, iconStatus, iconSave, iconGroupID
local spellMenu, menuEntryID, addPopup, addGroupID, addInput, addStatus, addTabs, addPanes
local movePopup, moveEntryID, deletePopup, deleteEntryID, deleteLabel
local OpenSpellMenu, OpenAddPopup, OpenMovePopup, OpenDeletePopup, RefreshAddPopup
local addExistingPage, addSelection, addRecent, addMode = 1, {}, {}, "existing"
local addForm = { kind = "BUFF", unit = "player", caster = "ANY" }
local addWidgets = { rows = {}, recent = {} }
local movePage = 1
local MOVE_PAGE_SIZE = 6
local activePage = "spells"
local selectedEntryID, selectedGroupID
local spellPage, groupPage, memberPage = 1, 1, 1
local PAGE_SIZE, GROUP_PAGE_SIZE, MEMBER_PAGE_SIZE = 5, 6, 4
local form = { kind = "BUFF", unit = "player", caster = "ANY" }
local widgets = { spellRows = {}, groupRows = {}, memberRows = {} }
local dragMemberID, dragGroupID, dragTargetID
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function ResetMemberDrag()
    dragMemberID, dragGroupID, dragTargetID = nil, nil, nil
    for _, row in ipairs(widgets.memberRows) do
        if row.bg then row.bg:SetVertexColor(.18, .16, .22, .56) end
    end
end

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

local function Slider(parent, title, x, y, low, high, callback, width)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(width or 480, 18)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local caption = Label(parent, title, x, y + 30, width or 490)
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

local TYPE_OPTIONS = { { "Buff", "BUFF" }, { "Debuff", "DEBUFF" }, { "Cooldown", "COOLDOWN" } }
local UNIT_OPTIONS = { { "Player", "player" }, { "Target", "target" }, { "Focus", "focus" }, { "Pet", "pet" } }
local CASTER_OPTIONS = { { "Any", "ANY" }, { "Mine", "MINE" } }
local MODE_OPTIONS = { { "On Cooldown", "ON_COOLDOWN" }, { "Ready", "READY" }, { "Always", "ALWAYS" } }
local MODE_NAMES = { ON_COOLDOWN = "On Cooldown", READY = "Ready", ALWAYS = "Always" }
local TYPE_NAMES = { BUFF = "Buff", DEBUFF = "Debuff", COOLDOWN = "Cooldown" }

-- Standard Blizzard dropdown (not a button cycling through its values).
-- The control owns no saved state: getValue and onPick read/write the form
-- or the selected entry, and Sync refreshes the text and disabled state.
local dropdownSerial = 0
local function Dropdown(parent, x, y, width, caption, options, getValue, onPick)
    -- Classic UIDropDownMenu_EnableDropDown/DisableDropDown build child names
    -- from frame:GetName(); anonymous template frames cause a nil concat error.
    dropdownSerial = dropdownSerial + 1
    local dropName = ADDON_NAME .. "OptionsDropdown" .. dropdownSerial
    local drop = CreateFrame("Frame", dropName, parent, "UIDropDownMenuTemplate")
    drop:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y + 3)
    UIDropDownMenu_SetWidth(drop, width - 34)
    drop.caption = Label(parent, caption, x + 1, y + 22, width - 4, "GameFontHighlightSmall")
    UIDropDownMenu_Initialize(drop, function(_, level)
        if level ~= 1 then return end
        for _, option in ipairs(type(options) == "function" and options() or options) do
            local value, label = option[2], option[1]
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = label, value
            info.checked = getValue() == value
            info.func = function()
                CloseDropDownMenus()
                onPick(value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    function drop:Sync(enabled)
        local value = getValue()
        local name = "?"
        for _, option in ipairs(type(options) == "function" and options() or options) do
            if option[2] == value then name = option[1]; break end
        end
        UIDropDownMenu_SetText(self, name)
        if enabled == false then UIDropDownMenu_DisableDropDown(self)
        else UIDropDownMenu_EnableDropDown(self) end
    end
    return drop
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
    ResetMemberDrag()
    CloseGroupMenu()
    if addPopup then addPopup:Hide() end
    if movePopup then movePopup:Hide() end
    if deletePopup then deletePopup:Hide() end
    activePage = name
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function OpenEntry(id)
    if not ns.FindEntry(id) then return end
    if widgets.entryIDInput then
        widgets.entryIDInput:ClearFocus()
        widgets.entryIDInput:SetText(tostring(ns.FindEntry(id).spellID))
    end
    SetStatus(widgets.entryStatus, "")
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
    widgets.formKind:Sync()
    local usesAura = form.kind ~= "COOLDOWN"
    widgets.formUnit:SetShown(usesAura)
    widgets.formUnit.caption:SetShown(usesAura)
    widgets.formCaster:SetShown(usesAura)
    widgets.formCaster.caption:SetShown(usesAura)
    if usesAura then
        widgets.formUnit:Sync()
        widgets.formCaster:Sync()
    end
end

local function SetForm(field, value)
    form[field] = value
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
    row.bg = bg
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
    widgets.formKind = Dropdown(pane, 150, -52, 126, "Type", TYPE_OPTIONS,
        function() return form.kind end, function(v) SetForm("kind", v) end)
    widgets.formUnit = Dropdown(pane, 282, -52, 126, "Unit", UNIT_OPTIONS,
        function() return form.unit end, function(v) SetForm("unit", v) end)
    widgets.formCaster = Dropdown(pane, 414, -52, 145, "Caster", CASTER_OPTIONS,
        function() return form.caster end, function(v) SetForm("caster", v) end)
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
    addWidgets.kind:Sync()
    local usesAura = addForm.kind ~= "COOLDOWN"
    addWidgets.unit:SetShown(usesAura)
    addWidgets.unit.caption:SetShown(usesAura)
    addWidgets.caster:SetShown(usesAura)
    addWidgets.caster.caption:SetShown(usesAura)
    if usesAura then
        addWidgets.unit:Sync()
        addWidgets.caster:Sync()
    end
end

local function SetAddForm(field, value)
    addForm[field] = value
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
    addWidgets.kind = Dropdown(newer, 145, -33, 119, "Type", TYPE_OPTIONS,
        function() return addForm.kind end, function(v) SetAddForm("kind", v) end)
    addWidgets.unit = Dropdown(newer, 270, -33, 119, "Unit", UNIT_OPTIONS,
        function() return addForm.unit end, function(v) SetAddForm("unit", v) end)
    addWidgets.caster = Dropdown(newer, 395, -33, 132, "Caster", CASTER_OPTIONS,
        function() return addForm.caster end, function(v) SetAddForm("caster", v) end)
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

local function ChangeEntry(field, value)
    local entry = ns.FindEntry(selectedEntryID)
    if not entry then return end
    entry[field] = value
    if field == "kind" and value == "COOLDOWN" and not MODE_NAMES[entry.cooldownMode] then
        entry.cooldownMode = "ON_COOLDOWN"
    end
    ns.EntriesChanged()
end

local function CommitEntrySpellID()
    local entry = ns.FindEntry(selectedEntryID)
    if not entry then return end
    local id = tonumber(widgets.entryIDInput:GetText())
    widgets.entryIDInput:ClearFocus()
    local ok, message = ns.UpdateEntrySpell(entry.id, id)
    SetStatus(widgets.entryStatus, message, not ok)
    if ok then widgets.entryIDInput:SetText(tostring(entry.spellID)) end
end

local function EntryGroupOptions()
    local options = { { "Solo", false } }
    for _, group in ipairs(ns.db.groups) do
        options[#options + 1] = { group.name, group.id }
    end
    return options
end

-- One editor for both solo icons and group members.
local function BuildEntry(pane)
    local preview = CreateFrame("Frame", nil, pane)
    preview:SetSize(106, 106)
    preview:SetPoint("TOPLEFT", pane, "TOPLEFT", 20, -3)
    local backing = preview:CreateTexture(nil, "BACKGROUND")
    backing:SetAllPoints()
    backing:SetTexture("Interface\\Buttons\\WHITE8X8")
    backing:SetVertexColor(.15, .14, .18, .65)

    widgets.entryPreview = CreateFrame("Frame", nil, preview)
    widgets.entryPreview:SetPoint("CENTER", preview, "CENTER")
    widgets.entryPreview:SetSize(36, 36)
    widgets.entryIcon = widgets.entryPreview:CreateTexture(nil, "ARTWORK")
    widgets.entryIcon:SetAllPoints()
    widgets.entryIcon:SetTexCoord(.07, .93, .07, .93)
    widgets.entryPreviewBorder = widgets.entryPreview:CreateTexture(nil, "OVERLAY")
    widgets.entryPreviewBorder:SetAllPoints()
    widgets.entryPreviewBorder:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Border_squared")

    widgets.entryTitle = Label(pane, "", 145, -9, 265, "GameFontNormalLarge")
    widgets.entryEnabled, widgets.entryEnabledLabel = Checkbox(pane, "Enabled", 429, -5, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.enabled = checked; ns.EntriesChanged() end
    end)
    widgets.entryEnabledLabel:SetWidth(95)
    Label(pane, "Spell ID", 145, -39, 115, "GameFontHighlightSmall")
    widgets.entryIDInput = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    widgets.entryIDInput:SetSize(116, 25)
    widgets.entryIDInput:SetPoint("TOPLEFT", 150, -57)
    widgets.entryIDInput:SetAutoFocus(false)
    widgets.entryIDInput:SetNumeric(true)
    widgets.entryIDInput:SetMaxLetters(9)
    widgets.entryIDInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        local entry = ns.FindEntry(selectedEntryID)
        if entry then self:SetText(tostring(entry.spellID)) end
    end)
    widgets.entryIDInput:SetScript("OnEnterPressed", CommitEntrySpellID)
    Button(pane, "Apply ID", 285, -57, 102, 26, CommitEntrySpellID)
    widgets.entryStatus = Label(pane, "", 145, -89, 417, "GameFontHighlightSmall")

    Label(pane, "Tracking", 20, -120, 525, "GameFontNormalLarge")
    widgets.entryKind = Dropdown(pane, 20, -164, 166, "Type", TYPE_OPTIONS,
        function() local e = ns.FindEntry(selectedEntryID); return e and e.kind end,
        function(v) ChangeEntry("kind", v) end)
    widgets.entryUnit = Dropdown(pane, 198, -164, 166, "Unit", UNIT_OPTIONS,
        function() local e = ns.FindEntry(selectedEntryID); return e and e.unit end,
        function(v) ChangeEntry("unit", v) end)
    widgets.entryCaster = Dropdown(pane, 378, -164, 182, "Caster", CASTER_OPTIONS,
        function() local e = ns.FindEntry(selectedEntryID); return e and e.caster end,
        function(v) ChangeEntry("caster", v) end)
    widgets.entryCooldown = Dropdown(pane, 198, -164, 362, "Display mode", MODE_OPTIONS,
        function() local e = ns.FindEntry(selectedEntryID); return e and (e.cooldownMode or "ON_COOLDOWN") end,
        function(v) ChangeEntry("cooldownMode", v) end)

    Label(pane, "Appearance", 20, -206, 525, "GameFontNormalLarge")
    widgets.entryCount, widgets.entryCountLabel = Checkbox(pane, "Cooldown Count", 20, -231, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showCountdown = checked; ns.EntriesChanged() end
    end)
    widgets.entryCountLabel:SetWidth(160)
    widgets.entryBorder, widgets.entryBorderLabel = Checkbox(pane, "Border", 214, -231, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showBorder = checked; ns.EntriesChanged() end
    end)
    widgets.entryBorderLabel:SetWidth(100)
    widgets.entryStacks, widgets.entryStacksLabel = Checkbox(pane, "Show stacks", 378, -231, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.showStacks = checked; ns.EntriesChanged() end
    end)
    widgets.entryStacksLabel:SetWidth(140)
    widgets.entrySize = Slider(pane, "Icon size", 28, -308, 18, 100, function(value)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.size = value; ns.EntriesChanged() end
    end, 233)
    widgets.entryAlpha = Slider(pane, "Icon alpha (%)", 306, -308, 0, 100, function(value)
        local entry = ns.FindEntry(selectedEntryID)
        if entry then entry.alpha = value / 100; ns.EntriesChanged() end
    end, 233)

    Label(pane, "Placement", 20, -342, 525, "GameFontNormalLarge")
    widgets.entryGroup = Dropdown(pane, 20, -386, 310, "Group", EntryGroupOptions,
        function()
            local entry = ns.FindEntry(selectedEntryID)
            return entry and (entry.groupId or false)
        end,
        function(groupID)
            local entry = ns.FindEntry(selectedEntryID)
            if entry then ns.AssignGroup(entry.id, groupID or nil) end
        end)
    widgets.entryLock, widgets.entryLockLabel = Checkbox(pane, "Lock position", 343, -383, function(checked)
        local entry = ns.FindEntry(selectedEntryID)
        if not entry then return end
        local group = ns.FindGroup(entry.groupId)
        if group then group.locked = checked else entry.locked = checked end
        ns.EntriesChanged()
    end)
    widgets.entryLockLabel:SetWidth(185)
    widgets.entryHint = Label(pane, "", 20, -421, 540, "GameFontHighlightSmall")
    widgets.entryTest = Button(pane, "Test icon", 20, -445, 168, 28, function()
        local entry = ns.FindEntry(selectedEntryID)
        if entry then ns.SetEntryTest(entry.id, ns.testEntryID ~= entry.id) end
    end)
    Button(pane, "Remove spell", 390, -445, 170, 28, function()
        if selectedEntryID then OpenDeletePopup(selectedEntryID) end
    end)
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
        row.grip = CreateFrame("Button", nil, row)
        row.grip:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
        row.grip:SetSize(24, 31)
        row.grip:RegisterForDrag("LeftButton")
        row.grip.label = row.grip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.grip.label:SetPoint("CENTER")
        row.grip.label:SetText("|cff9f7bff::|r")
        row.grip:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.grip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Drag to reorder", 1, 1, 1)
            GameTooltip:Show()
        end)
        row.grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.grip:SetScript("OnDragStart", function()
            local group = ns.FindGroup(selectedGroupID)
            local id = group and group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            if not id then return end
            CloseGroupMenu()
            dragMemberID, dragGroupID, dragTargetID = id, group.id, id
        end)
        row.grip:SetScript("OnDragStop", function()
            local from, target, groupID = dragMemberID, dragTargetID, dragGroupID
            ResetMemberDrag()
            if from and target and groupID and selectedGroupID == groupID then
                ns.ReorderMember(groupID, from, target)
            end
        end)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", row, "LEFT", 29, 0)
        row.icon:SetTexCoord(.07, .93, .07, .93)
        row.name = Label(row, "", 63, -8, 455, "GameFontHighlight")
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetPoint("TOPLEFT", row, "TOPLEFT", 25, 0)
        row.hit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.hit:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.hit:SetScript("OnClick", function(_, mouseButton)
            if dragMemberID then return end
            local group = ns.FindGroup(selectedGroupID)
            local id = group and group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            if not id then return end
            if mouseButton == "RightButton" then OpenSpellMenu(row, id, i + 3)
            else OpenEntry(id) end
        end)
        widgets.memberRows[i] = row
    end
    -- Highlight the row under the cursor while a grip is being dragged.
    -- This works only on the visible page; moving to another page still uses
    -- Move to group or the existing page controls.
    pane:SetScript("OnUpdate", function()
        if not dragMemberID or dragGroupID ~= selectedGroupID or activePage ~= "group" then return end
        local group = ns.FindGroup(dragGroupID)
        if not group then ResetMemberDrag(); return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = x / scale, y / scale
        dragTargetID = nil
        for i, row in ipairs(widgets.memberRows) do
            local memberID = group.members[(memberPage - 1) * MEMBER_PAGE_SIZE + i]
            local hovered = row:IsShown() and memberID
                and x >= row:GetLeft() and x <= row:GetRight()
                and y >= row:GetBottom() and y <= row:GetTop()
            if hovered then dragTargetID = memberID end
            if row.bg then
                if hovered then row.bg:SetVertexColor(.52, .37, .76, .72)
                elseif memberID == dragMemberID then row.bg:SetVertexColor(.32, .26, .40, .72)
                else row.bg:SetVertexColor(.18, .16, .22, .56) end
            end
        end
    end)
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
            row.desc:SetText((TYPE_NAMES[entry.kind] or entry.kind) .. " · " .. (group and ("Group: " .. group.name)
                or (entry.kind == "COOLDOWN" and (MODE_NAMES[entry.cooldownMode] or "On Cooldown")
                    or (entry.unit .. " · " .. entry.caster))))
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
    local group = ns.FindGroup(entry.groupId)
    widgets.entryIcon:SetTexture(icon or FALLBACK_ICON)
    widgets.entryTitle:SetText(name or "Unknown spell")
    widgets.entryEnabled:SetChecked(entry.enabled ~= false)
    if not widgets.entryIDInput:HasFocus() then
        widgets.entryIDInput:SetText(tostring(entry.spellID))
    end
    -- The preview is independent of whether this spell is currently active.
    -- In Uniform groups it reflects the actual group size, not the saved solo size.
    local size = group and group.sizeMode == "UNIFORM" and group.groupSize or entry.size or 36
    widgets.entryPreview:SetSize(size, size)
    widgets.entryPreview:SetAlpha(math.max(0, math.min(1, tonumber(entry.alpha) or 1)))
    widgets.entryPreviewBorder:SetShown(entry.showBorder ~= false)
    widgets.entryKind:Sync()
    local usesAura = entry.kind ~= "COOLDOWN"
    widgets.entryUnit:SetShown(usesAura)
    widgets.entryUnit.caption:SetShown(usesAura)
    widgets.entryCaster:SetShown(usesAura)
    widgets.entryCaster.caption:SetShown(usesAura)
    if usesAura then
        widgets.entryUnit:Sync()
        widgets.entryCaster:Sync()
    end
    widgets.entryCooldown:SetShown(not usesAura)
    widgets.entryCooldown.caption:SetShown(not usesAura)
    if not usesAura then widgets.entryCooldown:Sync() end
    widgets.entryGroup:Sync()
    widgets.entryCount:SetChecked(entry.showCountdown ~= false)
    widgets.entryBorder:SetChecked(entry.showBorder ~= false)
    widgets.entryStacks:SetChecked(entry.showStacks ~= false)
    local showCount = usesAura or entry.cooldownMode ~= "READY"
    widgets.entryCount:SetShown(showCount)
    widgets.entryCountLabel:SetShown(showCount)
    widgets.entryStacks:SetShown(usesAura)
    widgets.entryStacksLabel:SetShown(usesAura)
    widgets.entryLock:SetChecked(group and group.locked or (not group and entry.locked))
    widgets.entryLockLabel:SetText(group and "Lock group position" or "Lock position")
    widgets.entrySize:Sync(entry.size or 36)
    widgets.entryAlpha:Sync(math.floor((tonumber(entry.alpha) or 1) * 100 + .5))
    widgets.entryHint:SetText(group and group.sizeMode == "UNIFORM"
        and "Uniform size comes from the group. Personal icon size is saved."
        or (group and "Move the whole group after unlocking its position."
            or "Unlock and drag this icon to set its position."))
    widgets.entryTest:SetText(ns.testEntryID == entry.id and "Stop test" or "Test icon")
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
            local name, icon = ns.SpellInfo(entry.spellID)
            row.name:SetText((name or "Unknown") .. " [" .. entry.spellID .. "]")
            row.icon:SetTexture(icon or FALLBACK_ICON)
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
    local title = Label(panel, (Meta("Title") or "Icon") .. " |cff9f7bffv" .. (Meta("Version") or "0.5.0") .. "|r", 181, -14, 275, "GameFontNormalLarge")
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
