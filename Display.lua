local ADDON_NAME, ns = ...

local SIZE, SPACING = 40, 4
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local BORDER = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Border_squared"

local function SavePosition()
    if not ns.db or not ns.displayRoot then return end
    local x, y = ns.displayRoot:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and y and ux and uy then
        ns.db.x = x - ux
        ns.db.y = y - uy
    end
end

local function StartDrag()
    if ns.db and not ns.db.locked then ns.displayRoot:StartMoving() end
end

local function StopDrag()
    if not ns.displayRoot then return end
    ns.displayRoot:StopMovingOrSizing()
    SavePosition()
end

local function MakeIcon(spellID)
    local frame = CreateFrame("Frame", nil, ns.displayRoot)
    frame:SetSize(SIZE, SIZE)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartDrag)
    frame:SetScript("OnDragStop", StopDrag)
    -- Use the existing Icon/Media/Border_squared.blp texture from the pilot.
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexCoord(.07, .93, .07, .93)

    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetAllPoints(frame)
    frame.border:SetTexture(BORDER)
    frame:SetScript("OnEnter", function(self)
        local state = ns.states and ns.states[self.spellID]
        local name = ns.GetSpellInfo(self.spellID)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name or ("Spell " .. self.spellID), 1, 1, 1)
        GameTooltip:AddLine("Spell React  |  ID: " .. self.spellID, .75, .75, .75)
        GameTooltip:AddLine(state and state.active and "Active" or "Inactive (preview)", .8, .8, .8)
        if ns.db and not ns.db.locked then
            GameTooltip:AddLine("Drag to move the entire icon row.", .7, .65, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.spellID = spellID
    local _, icon = ns.GetSpellInfo(spellID)
    frame.icon:SetTexture(icon or QUESTION)
    return frame
end

function ns.CreateDisplay()
    if ns.displayRoot then return end
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(SIZE, SIZE)
    root:SetPoint("CENTER", UIParent, "CENTER", ns.db.x, ns.db.y)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", StartDrag)
    root:SetScript("OnDragStop", StopDrag)
    ns.displayRoot = root
    ns.iconFrames = {}
end

-- Unlike the pilot renderer, this only changes visibility when necessary.
-- Existing frames persist; removed IDs go to a small reusable frame pool.
function ns.Draw()
    if not ns.db or not ns.displayRoot then return end
    local visible = {}
    for _, spellID in ipairs(ns.db.tracked) do
        local state = ns.states and ns.states[spellID]
        if (state and state.active) or ns.testMode or not ns.db.locked then
            visible[#visible + 1] = spellID
        end
    end

    local count = #visible
    ns.displayRoot:SetSize(math.max(SIZE, count * (SIZE + SPACING) - SPACING), SIZE)
    local wanted = {}
    for index, spellID in ipairs(visible) do
        wanted[spellID] = true
        local frame = ns.iconFrames[spellID]
        if not frame then
            frame = MakeIcon(spellID)
            ns.iconFrames[spellID] = frame
        end
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", ns.displayRoot, "LEFT", (index - 1) * (SIZE + SPACING), 0)
        local state = ns.states and ns.states[spellID]
        frame:SetAlpha(((state and state.active) or ns.testMode) and 1 or .45)
        if not frame:IsShown() then frame:Show() end
    end
    for spellID, frame in pairs(ns.iconFrames) do
        if not wanted[spellID] and frame:IsShown() then frame:Hide() end
    end
    ns.displayRoot:EnableMouse(not ns.db.locked)
    if count == 0 then
        if ns.displayRoot:IsShown() then ns.displayRoot:Hide() end
    elseif not ns.displayRoot:IsShown() then
        ns.displayRoot:Show()
    end
end
