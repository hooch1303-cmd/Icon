local ADDON_NAME, ns = ...

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local BORDER = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Border_squared"
local function Unlocked(settings)
    return ns.db and (not ns.db.locked or not settings.locked)
end

local function SavePosition(root)
    if not ns.db then return end
    local x, y = root:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and y and ux and uy then
        root.data.x, root.data.y = x - ux, y - uy
        if ns.RefreshOptions then ns.RefreshOptions() end
    end
end

local function MakeRoot(data, isGroup)
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(40, 40)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root.data, root.isGroup = data, isGroup
    root:SetScript("OnDragStart", function(self)
        if Unlocked(self.data) then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    root.handle = root:CreateTexture(nil, "OVERLAY")
    root.handle:SetSize(18, 18)
    root.handle:SetPoint("CENTER")
    root.handle:SetColorTexture(.38, .28, .64, .8)
    root.handleText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    root.handleText:SetPoint("CENTER", root.handle)
    root.handleText:SetText(isGroup and "G" or "+")
    root:SetScript("OnEnter", function(self)
        if not Unlocked(self.data) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(isGroup and (self.data.name or "Group") or "Solo icon")
        GameTooltip:AddLine("Drag to move", .8, .8, .8)
        GameTooltip:Show()
    end)
    root:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return root
end

local function MakeIcon(spellID)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.spellID = spellID
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(.07, .93, .07, .93)
    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetAllPoints()
    frame.border:SetTexture(BORDER)
    frame.countdown = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.countdown:SetPoint("CENTER")
    frame.countdown:SetTextColor(1, 1, 1)
    frame:SetScript("OnDragStart", function(self)
        local root = self.root
        if root and Unlocked(root.data) then root:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        local root = self.root
        if root then
            root:StopMovingOrSizing()
            SavePosition(root)
        end
    end)
    frame:SetScript("OnEnter", function(self)
        local state = ns.states and ns.states[self.spellID]
        local name = ns.GetSpellInfo(self.spellID)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name or ("Spell " .. self.spellID), 1, 1, 1)
        GameTooltip:AddLine("Spell React | ID: " .. self.spellID, .75, .75, .75)
        GameTooltip:AddLine(state and state.active and "Active" or "Test preview", .8, .8, .8)
        if self.root and Unlocked(self.root.data) then
            GameTooltip:AddLine("Drag to move", .7, .65, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return frame
end

function ns.HasReactCountdown(spellID)
    -- These two tracked dodge/block windows have locally known expiration.
    -- Do not invent durations for Execute, Victorious, or other candidates.
    return ns.IsOverpower(spellID) or ns.IsRevenge(spellID)
end

function ns.UpdateCountdown()
    if not ns.iconFrames then return end
    for spellID, frame in pairs(ns.iconFrames) do
        if frame:IsShown() and ns.HasReactCountdown(spellID) then
            local settings = ns.GetIconSettings(spellID)
            local state = ns.states and ns.states[spellID]
            local remaining = state and state.remaining
            if settings and settings.countdown and state and state.active
                and type(remaining) == "number" and remaining > 0 then
                frame.countdown:SetText(remaining >= 3 and tostring(math.ceil(remaining))
                    or string.format("%.1f", remaining))
                frame.countdown:Show()
            else
                frame.countdown:Hide()
            end
        else
            frame.countdown:Hide()
        end
    end
end

function ns.CreateDisplay()
    if ns.iconFrames then return end
    ns.iconFrames, ns.soloRoots, ns.groupRoots = {}, {}, {}
end

local function ConfigureIcon(spellID, root, size)
    local settings = ns.GetIconSettings(spellID)
    local frame = ns.iconFrames[spellID]
    if not frame then
        frame = MakeIcon(spellID)
        ns.iconFrames[spellID] = frame
    end
    frame.root = root
    frame:SetParent(root)
    frame:SetSize(size, size)
    frame:SetAlpha(settings.alpha)
    local _, defaultIcon = ns.GetSpellInfo(spellID)
    frame.icon:SetTexture(settings.customIcon or defaultIcon or QUESTION)
    if settings.border then frame.border:Show() else frame.border:Hide() end
    return frame
end

local function PositionRoot(root)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", root.data.x, root.data.y)
    local unlocked = Unlocked(root.data)
    root:EnableMouse(unlocked)
    root.handle:SetShown(unlocked)
    root.handleText:SetShown(unlocked)
end

local function IsVisible(spellID)
    local settings = ns.GetIconSettings(spellID)
    local state = ns.states and ns.states[spellID]
    return settings and ((settings.enabled and state and state.active)
        or ns.testSpellID == spellID) or false
end

function ns.Draw()
    if not ns.db or not ns.iconFrames then return end
    local owned, seenGroups, configured = {}, {}, {}
    for _, group in ipairs(ns.db.groups) do
        seenGroups[group.id] = true
        local root = ns.groupRoots[group.id]
        if not root then
            root = MakeRoot(group, true)
            ns.groupRoots[group.id] = root
        end
        root.data = group
        local slots, visibleCount = {}, 0
        for _, spellID in ipairs(group.members) do
            owned[spellID] = true
            local visible = IsVisible(spellID)
            if visible then visibleCount = visibleCount + 1 end
            if visible or group.layout == "fixed" then
                local settings = ns.GetIconSettings(spellID)
                if settings then
                    slots[#slots + 1] = {
                        id = spellID, visible = visible,
                        size = group.sizeMode == "uniform" and group.size or settings.size,
                    }
                end
            end
        end
        local total, cross = 0, 0
        for _, slot in ipairs(slots) do
            total = total + slot.size
            cross = math.max(cross, slot.size)
        end
        total = total + math.max(0, #slots - 1) * group.spacing
        if group.orientation == "horizontal" then
            root:SetSize(math.max(18, total), math.max(18, cross))
        else
            root:SetSize(math.max(18, cross), math.max(18, total))
        end
        PositionRoot(root)
        local offset = -total / 2
        for _, slot in ipairs(slots) do
            local frame = ConfigureIcon(slot.id, root, slot.size)
            configured[slot.id] = true
            local crossOffset = 0
            if group.alignment == "start" then crossOffset = (cross - slot.size) / 2
            elseif group.alignment == "finish" then crossOffset = -(cross - slot.size) / 2 end
            frame:ClearAllPoints()
            if group.orientation == "horizontal" then
                frame:SetPoint("CENTER", root, "CENTER", offset + slot.size / 2, crossOffset)
            else
                frame:SetPoint("CENTER", root, "CENTER", crossOffset, -(offset + slot.size / 2))
            end
            frame:SetShown(slot.visible)
            offset = offset + slot.size + group.spacing
        end
        root:SetShown(visibleCount > 0 or Unlocked(group))
    end
    for id, root in pairs(ns.groupRoots) do
        if not seenGroups[id] then root:Hide(); ns.groupRoots[id] = nil end
    end

    local wanted = {}
    for _, spellID in ipairs(ns.db.tracked) do
        wanted[spellID] = true
        if not owned[spellID] then
            local settings = ns.GetIconSettings(spellID)
            if settings then
                local root = ns.soloRoots[spellID]
                if not root then
                    root = MakeRoot(settings, false)
                    ns.soloRoots[spellID] = root
                end
                root.data = settings
                root:SetSize(settings.size, settings.size)
                PositionRoot(root)
                local frame = ConfigureIcon(spellID, root, settings.size)
                configured[spellID] = true
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", root, "CENTER")
                local visible = IsVisible(spellID)
                frame:SetShown(visible)
                root:SetShown(visible or Unlocked(settings))
            end
        elseif ns.soloRoots[spellID] then
            ns.soloRoots[spellID]:Hide()
        end
    end
    for spellID, frame in pairs(ns.iconFrames) do
        if not configured[spellID] then
            frame:Hide()
        end
    end
    for spellID, root in pairs(ns.soloRoots) do
        if not wanted[spellID] then root:Hide(); ns.soloRoots[spellID] = nil end
    end
    ns.UpdateCountdown()
end
