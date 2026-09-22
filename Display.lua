local ADDON_NAME, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Border_squared"
local FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function OmniCCLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded("OmniCC") end
    return IsAddOnLoaded and IsAddOnLoaded("OmniCC") or false
end

local function SetCountdown(cooldown, entry)
    local enabled = entry.showCountdown ~= false
    cooldown.noCooldownCount = not enabled or nil
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(not enabled or OmniCCLoaded())
    end
    if OmniCC and OmniCC.Cooldown and OmniCC.Cooldown.Refresh then
        OmniCC.Cooldown.Refresh(cooldown, true)
    end
end

local function ApplyPosition(frame, item)
    frame:ClearAllPoints()
    frame:SetPoint(item.point or "CENTER", UIParent, item.relativePoint or "CENTER", item.x or 0, item.y or -140)
end

local function SavePosition(frame, item)
    if not item then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    item.point, item.relativePoint, item.x, item.y = point, relativePoint, x, y
end

local function StartIconDrag(self)
    local entry = self.entry
    if not entry or not ns.db then return end
    local group = ns.FindGroup(entry.groupId)
    if group then
        if not group.locked and self.groupFrame then self.groupFrame:StartMoving() end
    elseif not entry.locked then
        self:StartMoving()
    end
end

local function StopIconDrag(self)
    local entry = self.entry
    if not entry then return end
    local group = ns.FindGroup(entry.groupId)
    if group and self.groupFrame then
        self.groupFrame:StopMovingOrSizing()
        SavePosition(self.groupFrame, group)
    elseif not group then
        self:StopMovingOrSizing()
        if entry.id and entry.id > 0 then SavePosition(self, entry) end
    end
end

local function MakeBorder(button)
    local layer = CreateFrame("Frame", nil, button)
    layer:SetAllPoints(button)
    layer:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.borderFrame = layer
    button.border = layer:CreateTexture(nil, "ARTWORK")
    button.border:SetAllPoints(layer)
    button.border:SetTexture(BORDER)
end

local function MakeIcon()
    local button = CreateFrame("Frame", nil, ns.displayRoot)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", StartIconDrag)
    button:SetScript("OnDragStop", StopIconDrag)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(.07, .93, .07, .93)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawSwipe(true)
    button.cooldown:SetReverse(true)
    if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(false) end
    if button.cooldown.SetDrawBling then button.cooldown:SetDrawBling(false) end
    MakeBorder(button)

    local above = CreateFrame("Frame", nil, button)
    above:SetAllPoints(button)
    above:SetFrameLevel(button.borderFrame:GetFrameLevel() + 1)
    button.stack = above:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.stack:SetJustifyH("RIGHT")
    button.stack:SetTextColor(1, 1, 1)
    button.stack:SetShadowOffset(1, -1)
    button.stack:SetShadowColor(0, 0, 0, 1)

    button.placeholder = button:CreateTexture(nil, "BACKGROUND")
    button.placeholder:SetAllPoints()
    button.placeholder:SetTexture(WHITE)
    button.placeholder:SetVertexColor(.52, .37, .76, .4)
    button.placeholderText = above:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.placeholderText:SetPoint("CENTER")
    button.placeholderText:SetText("+")

    button:SetScript("OnEnter", function(self)
        local entry, item = self.entry, self.item
        if not entry then return end
        local name = item and item.name or ns.SpellInfo(entry.spellID)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name or ("Spell " .. entry.spellID), 1, 1, 1)
        GameTooltip:AddLine(entry.kind == "COOLDOWN" and ("Cooldown  |  " .. (entry.cooldownMode == "READY" and "Ready" or entry.cooldownMode == "ALWAYS" and "Always" or "On Cooldown"))
            or (entry.kind .. "  |  " .. (entry.unit or "player")), .75, .75, .75)
        GameTooltip:AddLine("Spell ID: " .. entry.spellID, .75, .75, .75)
        if item and item.count and item.count > 1 then
            GameTooltip:AddLine("Stacks / charges: " .. item.count, 1, 1, 1)
        end
        if not item and not entry.groupId then
            GameTooltip:AddLine("Inactive — drag while unlocked.", .8, .7, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    button.positionDirty = true
    return button
end

local function MakeGroupFrame(group)
    local frame = CreateFrame("Frame", nil, ns.displayRoot)
    frame:SetFrameStrata("MEDIUM")
    frame:SetSize(140, 36)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.group = group
    frame:SetScript("OnDragStart", function(self)
        if self.group and not self.group.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self, self.group)
    end)
    frame.anchor = frame:CreateTexture(nil, "BACKGROUND")
    frame.anchor:SetAllPoints()
    frame.anchor:SetTexture(WHITE)
    frame.anchor:SetVertexColor(.52, .37, .76, .35)
    frame.anchorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.anchorText:SetPoint("CENTER")
    frame.anchorText:SetText(group.name .. " — drag to move")
    ApplyPosition(frame, group)
    frame:Hide()
    return frame
end

function ns.CreateDisplay()
    if ns.displayRoot then return end
    ns.displayRoot = CreateFrame("Frame", "IconTrackerRoot", UIParent)
    ns.displayRoot:SetAllPoints(UIParent)
    ns.iconFrames = {}
    ns.groupFrames = {}
end

function ns.ApplyPosition()
    if not ns.db then return end
    for _, group in ipairs(ns.db.groups) do
        local frame = ns.groupFrames[group.id]
        if frame then ApplyPosition(frame, group) end
    end
    for _, entry in ipairs(ns.db.tracked) do
        if not entry.groupId then
            local frame = ns.iconFrames[entry.id]
            if frame then ApplyPosition(frame, entry); frame.positionDirty = false end
        end
    end
    ns.Refresh()
end

local function RenderIcon(button, entry, item, size, placeholder)
    button.entry, button.item = entry, item
    button:SetSize(size, size)
    button:SetAlpha(math.max(0, math.min(1, tonumber(entry.alpha) or 1)))
    button.placeholder:SetShown(placeholder)
    button.placeholderText:SetShown(placeholder)
    button.icon:SetShown(item ~= nil)
    button.borderFrame:SetShown(item ~= nil and entry.showBorder ~= false)
    button.stack:SetText(item and entry.showStacks ~= false and item.count and item.count > 1 and item.count or "")
    if item then
        button.icon:SetTexture(item.icon or FALLBACK)
        SetCountdown(button.cooldown, entry)
        if item.duration and item.duration > 0 then
            local start = item.start or 0
            if button.lastEntryID ~= entry.id or button.lastStart ~= start
                or button.lastDuration ~= item.duration or button.lastRate ~= (item.rate or 1) then
                button.cooldown:SetCooldown(start, item.duration, item.rate or 1)
                button.lastEntryID, button.lastStart, button.lastDuration, button.lastRate = entry.id, start, item.duration, item.rate or 1
            end
            button.cooldown:Show()
        else
            button.cooldown:Clear()
            button.cooldown:Hide()
            button.lastEntryID, button.lastStart, button.lastDuration, button.lastRate = nil, nil, nil, nil
        end
    else
        button.cooldown:Clear()
        button.cooldown:Hide()
        button.lastEntryID, button.lastStart, button.lastDuration, button.lastRate = nil, nil, nil, nil
    end
end

local function GetIcon(entry)
    local button = ns.iconFrames[entry.id]
    if not button then
        button = MakeIcon()
        ns.iconFrames[entry.id] = button
    end
    return button
end

local function DrawSolo(entry, item)
    local button = GetIcon(entry)
    if button:GetParent() ~= ns.displayRoot then
        button:SetParent(ns.displayRoot)
        button.positionDirty = true
    end
    button.groupFrame = nil
    if button.positionDirty then
        ApplyPosition(button, entry)
        button.positionDirty = false
    end
    local visible = item ~= nil or (entry.enabled and not entry.locked)
    if visible then RenderIcon(button, entry, item, entry.size or 36, item == nil) end
    button:SetShown(visible)
end

local function Offset(extra, align)
    if align == "START" then return 0 end
    if align == "END" then return extra end
    return extra / 2
end

local function DrawGroup(group, active)
    local frame = ns.groupFrames[group.id]
    if not frame then
        frame = MakeGroupFrame(group)
        ns.groupFrames[group.id] = frame
    end
    frame.group = group -- Resetting the development DB may reuse a group ID.
    local occupied, visibleCount = {}, 0
    for _, id in ipairs(group.members) do
        local entry = ns.FindEntry(id)
        local item = entry and active[id]
        if entry and (entry.enabled or item) then
            if item then visibleCount = visibleCount + 1 end
            if item or group.layout == "FIXED" then
                occupied[#occupied + 1] = { entry = entry, item = item,
                    size = group.sizeMode == "UNIFORM" and group.groupSize or entry.size or 36 }
            end
        end
    end
    local horizontal = group.orientation ~= "VERTICAL"
    local spacing = group.spacing or 0
    local totalMain, maxCross = 0, 0
    for _, slot in ipairs(occupied) do
        totalMain = totalMain + slot.size
        if slot.size > maxCross then maxCross = slot.size end
    end
    if #occupied > 1 then totalMain = totalMain + spacing * (#occupied - 1) end
    local width = horizontal and totalMain or maxCross
    local height = horizontal and maxCross or totalMain
    if visibleCount == 0 then
        width, height = 140, 36
    end
    frame:SetSize(math.max(1, width), math.max(1, height))
    frame:EnableMouse(not group.locked)
    frame.anchor:SetShown(visibleCount == 0 and not group.locked)
    frame.anchorText:SetShown(visibleCount == 0 and not group.locked)
    frame.anchorText:SetText(group.name .. " — drag to move")
    frame:SetShown(visibleCount > 0 or not group.locked)
    local cursor = 0
    for _, slot in ipairs(occupied) do
        local button = GetIcon(slot.entry)
        if button:GetParent() ~= frame then button:SetParent(frame) end
        button.groupFrame = frame
        RenderIcon(button, slot.entry, slot.item, slot.size, false)
        button:ClearAllPoints()
        if horizontal then
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", cursor, -Offset(maxCross - slot.size, group.align))
        else
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", Offset(maxCross - slot.size, group.align), -cursor)
        end
        button.positionDirty = true -- Keep the old solo position for detaching later.
        button:SetShown(slot.item ~= nil)
        cursor = cursor + slot.size + spacing
    end
end

function ns.Draw(items)
    if not ns.db or not ns.displayRoot then return end
    local active = {}
    for _, item in ipairs(items) do active[item.entry.id] = item end
    for _, button in pairs(ns.iconFrames) do button:Hide() end
    for _, frame in pairs(ns.groupFrames) do frame:Hide() end
    for _, entry in ipairs(ns.db.tracked) do
        if (entry.enabled or active[entry.id]) and not entry.groupId then DrawSolo(entry, active[entry.id]) end
    end
    for _, group in ipairs(ns.db.groups) do DrawGroup(group, active) end
    -- Empty test mode previews have no saved spell entries or groups.
    if ns.testMode and #ns.db.tracked == 0 then
        for _, item in ipairs(items) do DrawSolo(item.entry, item) end
    end
end
