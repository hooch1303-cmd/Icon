local ADDON_NAME, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local BORDER_COLORS = {
    BUFF = { 0.35, 0.80, 0.45 },
    DEBUFF = { 0.96, 0.32, 0.31 },
    PROC = { 0.68, 0.48, 0.98 },
}

local function OmniCCLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded("OmniCC") end
    return IsAddOnLoaded and IsAddOnLoaded("OmniCC") or false
end

local function SetCountdown(cooldown)
    local enabled = ns.db.showCountdown
    cooldown.noCooldownCount = not enabled or nil
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(not enabled or OmniCCLoaded())
    end
    if OmniCC and OmniCC.Cooldown and OmniCC.Cooldown.Refresh then
        OmniCC.Cooldown.Refresh(cooldown, true)
    end
end

local function SavePosition()
    local point, _, relativePoint, x, y = ns.container:GetPoint(1)
    ns.db.point, ns.db.relativePoint, ns.db.x, ns.db.y = point, relativePoint, x, y
end

local function StartDrag()
    if ns.db and not ns.db.locked then ns.container:StartMoving() end
end

local function StopDrag()
    ns.container:StopMovingOrSizing()
    SavePosition()
end

local function CreateBorder(button)
    local layer = CreateFrame("Frame", nil, button)
    layer:SetAllPoints(button)
    layer:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.borderFrame = layer
    button.edges = {}
    local data = {
        { "TOPLEFT", "TOPRIGHT", 2, true },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 2, true },
        { "TOPLEFT", "BOTTOMLEFT", 2, false },
        { "TOPRIGHT", "BOTTOMRIGHT", 2, false },
    }
    for _, points in ipairs(data) do
        local texture = layer:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(WHITE)
        texture:SetPoint(points[1], layer, points[1], 0, 0)
        texture:SetPoint(points[2], layer, points[2], 0, 0)
        if points[4] then texture:SetHeight(points[3]) else texture:SetWidth(points[3]) end
        button.edges[#button.edges + 1] = texture
    end
end

local function MakeButton(container)
    local button = CreateFrame("Frame", nil, container)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", StopDrag)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button.cooldown:SetDrawSwipe(true)
    button.cooldown:SetReverse(true)
    if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(false) end
    if button.cooldown.SetDrawBling then button.cooldown:SetDrawBling(false) end
    CreateBorder(button)

    -- Keep stack count above the swipe and border.
    local labelFrame = CreateFrame("Frame", nil, button)
    labelFrame:SetAllPoints(button)
    labelFrame:SetFrameLevel(button.borderFrame:GetFrameLevel() + 1)
    button.stack = labelFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.stack:SetJustifyH("RIGHT")
    button.stack:SetTextColor(1, 1, 1)
    button.stack:SetShadowOffset(1, -1)
    button.stack:SetShadowColor(0, 0, 0, 1)

    button:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.name or ("Spell " .. item.entry.spellID), 1, 1, 1)
        GameTooltip:AddLine(item.entry.kind .. "  |  " .. (item.entry.unit or "player"), .75, .75, .75)
        GameTooltip:AddLine("Spell ID: " .. item.entry.spellID, .75, .75, .75)
        if item.count and item.count > 1 then
            GameTooltip:AddLine("Stacks / charges: " .. item.count, 1, 1, 1)
        end
        if item.entry.kind == "PROC" and item.entry.trigger ~= "AURA" then
            GameTooltip:AddLine("Combat-log estimate; not a castability check.", 1, .8, .35, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    return button
end

function ns.CreateDisplay()
    if ns.container then return end
    local container = CreateFrame("Frame", "IconTrackerFrame", UIParent)
    container:SetSize(140, 36)
    container:SetClampedToScreen(true)
    container:SetMovable(true)
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", StartDrag)
    container:SetScript("OnDragStop", StopDrag)
    ns.container = container
    ns.buttons = {}

    local anchor = container:CreateTexture(nil, "BACKGROUND")
    anchor:SetAllPoints(container)
    anchor:SetTexture(WHITE)
    anchor:SetVertexColor(.52, .37, .76, .3)
    ns.anchor = anchor
    local anchorText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anchorText:SetPoint("CENTER", container, "CENTER")
    anchorText:SetText("Icon — drag to move")
    ns.anchorText = anchorText
    ns.ApplyPosition()
end

function ns.ApplyPosition()
    if not ns.container or not ns.db then return end
    ns.container:ClearAllPoints()
    ns.container:SetPoint(ns.db.point, UIParent, ns.db.relativePoint, ns.db.x, ns.db.y)
    ns.Layout()
end

function ns.ApplyMovability()
    if ns.db then ns.Layout() end
end

function ns.Layout()
    if not ns.db or not ns.container then return end
    local count = ns.visibleCount or 0
    local size, spacing = ns.db.size, ns.db.spacing
    local width = count > 0 and count * size + (count - 1) * spacing or 140
    ns.container:SetSize(width, count > 0 and size or 36)
    ns.container:SetShown(count > 0 or not ns.db.locked)
    ns.anchor:SetShown(count == 0 and not ns.db.locked)
    ns.anchorText:SetShown(count == 0 and not ns.db.locked)
    for i, button in ipairs(ns.buttons) do
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("LEFT", ns.container, "LEFT", (i - 1) * (size + spacing), 0)
        button:SetShown(i <= count)
    end
end

function ns.Draw(active)
    if not ns.db or not ns.container then return end
    for i = #ns.buttons + 1, #active do
        ns.buttons[i] = MakeButton(ns.container)
    end
    for i, button in ipairs(ns.buttons) do
        local item = active[i]
        button.item = item
        if item then
            local color = BORDER_COLORS[item.entry.kind] or BORDER_COLORS.BUFF
            button.icon:SetTexture(item.icon or FALLBACK)
            for _, edge in ipairs(button.edges) do edge:SetVertexColor(color[1], color[2], color[3], .9) end
            button.borderFrame:SetShown(ns.db.showBorder)
            button.stack:SetText(item.count and item.count > 1 and item.count or "")
            SetCountdown(button.cooldown)
            if item.duration and item.duration > 0 then
                local start = item.start or 0
                if button.lastStart ~= start or button.lastDuration ~= item.duration then
                    button.cooldown:SetCooldown(start, item.duration)
                    button.lastStart, button.lastDuration = start, item.duration
                end
                button.cooldown:Show()
            else
                button.cooldown:Clear()
                button.cooldown:Hide()
                button.lastStart, button.lastDuration = nil, nil
            end
        else
            button.cooldown:Clear()
            button.cooldown:Hide()
            button.lastStart, button.lastDuration = nil, nil
        end
    end
    ns.visibleCount = #active
    ns.Layout()
end
