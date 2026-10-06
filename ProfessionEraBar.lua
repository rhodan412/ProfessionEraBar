local BUTTON_SCALE = 0.8
local BUTTON_SIZE = 52 * BUTTON_SCALE
local BUTTON_GAP = 3 * BUTTON_SCALE
local FRAME_GAP = 6
local TOP_OFFSET = -25

local MEDIA = "Interface\\AddOns\\ProfessionEraBar\\Media\\"
local EXPANSION_ART = MEDIA .. "Expansions\\"
local FRAME_TRIM = MEDIA .. "AzureGoldFrameTrim.tga"

local artByName = {
    midnight = "Midnight",
    khazalgar = "KhazAlgar",
    thewarwithin = "KhazAlgar",
    dragonisles = "DragonIsles",
    dragonflight = "DragonIsles",
    shadowlands = "Shadowlands",
    kultiran = "KulTiran",
    zandalari = "KulTiran",
    battleforazeroth = "KulTiran",
    legion = "Legion",
    draenor = "Draenor",
    warlordsofdraenor = "Draenor",
    pandaria = "Pandaria",
    mistsofpandaria = "Pandaria",
    cataclysm = "Cataclysm",
    northrend = "Northrend",
    wrathofthelichking = "Northrend",
    outland = "Outland",
    theburningcrusade = "Outland",
    burningcrusade = "Outland",
    classic = "Classic",
}
local newestFirst = {
    "Midnight", "KhazAlgar", "DragonIsles", "Shadowlands",
    "KulTiran", "Legion", "Draenor", "Pandaria",
    "Cataclysm", "Northrend", "Outland", "Classic",
}
local eraLabels = {
    Midnight = "Midnight",
    KhazAlgar = "The War Within",
    DragonIsles = "Dragonflight",
    Shadowlands = "Shadowlands",
    KulTiran = "Battle for Azeroth",
    Legion = "Legion",
    Draenor = "Warlords of Draenor",
    Pandaria = "Mists of Pandaria",
    Cataclysm = "Cataclysm",
    Northrend = "Wrath of the Lich King",
    Outland = "The Burning Crusade",
    Classic = "Classic",
}

local function NameKey(name)
    local key = (name or ""):lower():gsub("[%s%p]", "")
    return key
end

-- Blizzard's expansion names are localized; add their full names alongside the
-- profession tier names above when the client provides them.
for index, art in ipairs(newestFirst) do
    local expansionName = _G["EXPANSION_NAME" .. (#newestFirst - index)]
    if expansionName then
        artByName[NameKey(expansionName)] = art
    end
end

local professionsFrame
local bar
local buttons = {}
local pendingSpecReturn
local launcher
local settings

local function GetSelectedProfessionID()
    local selected
    if professionsFrame:GetTab() == professionsFrame.specializationsTabID then
        local filters = professionsFrame.recipesFilters
        selected = filters and filters.professionInfo
    end
    selected = selected or C_TradeSkillUI.GetChildProfessionInfo()
    return selected and selected.professionID
end

local function AnchorBar()
    local frameScale = professionsFrame:GetEffectiveScale()
    local screenRight = (UIParent:GetRight() or 0) * UIParent:GetEffectiveScale()
    local frameRight = (professionsFrame:GetRight() or 0) * frameScale
    local frameLeft = (professionsFrame:GetLeft() or 0) * frameScale
    local spaceOnRight = screenRight - frameRight
    local spaceOnLeft = frameLeft
    local spaceNeeded = (BUTTON_SIZE + FRAME_GAP) * frameScale

    bar:ClearAllPoints()
    if spaceOnRight >= spaceNeeded or spaceOnRight >= spaceOnLeft then
        bar.side = "RIGHT"
        bar:SetPoint("TOPLEFT", professionsFrame, "TOPRIGHT", FRAME_GAP, TOP_OFFSET)
    else
        bar.side = "LEFT"
        bar:SetPoint("TOPRIGHT", professionsFrame, "TOPLEFT", -FRAME_GAP, TOP_OFFSET)
    end
end

-- RQE's Azure & Gold frame trim is drawn as eight slices, so the corners stay crisp.
local function AddFrameTrim(button)
    button.trimTextures = {}
    local function Piece(left, right, top, bottom)
        local texture = button:CreateTexture(nil, "OVERLAY", nil, 2)
        texture:SetTexture(FRAME_TRIM)
        texture:SetTexCoord(left, right, top, bottom)
        table.insert(button.trimTextures, texture)
        return texture
    end

    local tl = Piece(0, 0.27, 0, 0.27)
    local tr = Piece(0.73, 1, 0, 0.27)
    local bl = Piece(0, 0.27, 0.73, 1)
    local br = Piece(0.73, 1, 0.73, 1)
    local top = Piece(0.27, 0.73, 0, 0.27)
    local bottom = Piece(0.27, 0.73, 0.73, 1)
    local left = Piece(0, 0.27, 0.27, 0.73)
    local right = Piece(0.73, 1, 0.27, 0.73)
    local corner = 11 * BUTTON_SCALE

    for _, piece in ipairs({ tl, tr, bl, br }) do
        piece:SetSize(corner, corner)
    end
    tl:SetPoint("TOPLEFT")
    tr:SetPoint("TOPRIGHT")
    bl:SetPoint("BOTTOMLEFT")
    br:SetPoint("BOTTOMRIGHT")
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    top:SetHeight(corner)
    bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    bottom:SetHeight(corner)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    left:SetWidth(corner)
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    right:SetWidth(corner)

    local function Keyline(r, g, b, a, point, relativePoint, x, y, horizontal)
        local line = button:CreateTexture(nil, "OVERLAY", nil, 3)
        line:SetColorTexture(r, g, b, a)
        table.insert(button.trimTextures, line)
        line:SetPoint(point, button, relativePoint, x, y)
        if horizontal then
            line:SetWidth(BUTTON_SIZE - 8 * BUTTON_SCALE)
            line:SetHeight(1)
        else
            line:SetWidth(1)
            line:SetHeight(BUTTON_SIZE - 8 * BUTTON_SCALE)
        end
    end
    Keyline(0, 87 / 255, 184 / 255, 1, "TOP", "TOP", 0, -1, true)
    Keyline(0, 87 / 255, 184 / 255, 1, "BOTTOM", "BOTTOM", 0, 1, true)
    Keyline(0, 87 / 255, 184 / 255, 1, "LEFT", "LEFT", 1, 0, false)
    Keyline(0, 87 / 255, 184 / 255, 1, "RIGHT", "RIGHT", -1, 0, false)
    Keyline(1, 215 / 255, 0, 0.88, "TOP", "TOP", 0, -3, true)
end

local RefreshBar
local MaybeReturnToSpecializations

local function CreateButton(index)
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -(index - 1) * (BUTTON_SIZE + BUTTON_GAP))

    button.art = button:CreateTexture(nil, "ARTWORK")
    button.art:SetPoint("TOPLEFT", 4, -4)
    button.art:SetPoint("BOTTOMRIGHT", -4, 4)

    button.hover = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.hover:SetAllPoints(button.art)
    button.hover:SetColorTexture(1, 1, 1, 0.17)
    button.hover:Hide()

    AddFrameTrim(button)

    button.selection = button:CreateTexture(nil, "OVERLAY", nil, 4)
    button.selection:SetColorTexture(1, 0.85, 0.15, 1)
    button.selection:SetPoint("BOTTOMLEFT", 10.4, 2.4)
    button.selection:SetPoint("BOTTOMRIGHT", -10.4, 2.4)
    button.selection:SetHeight(2)
    button.selection:Hide()

    button:SetScript("OnEnter", function(self)
        self.hover:Show()
        GameTooltip:SetOwner(self, bar.side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        local info = self.professionInfo
        GameTooltip:SetText(self.eraName, 1, 0.82, 0)
        if info then
            GameTooltip:AddLine(("%d/%d"):format(info.skillLevel or 0, info.maxSkillLevel or 0), 1, 1, 1)
            if C_ProfSpecs.SkillLineHasSpecialization(info.professionID) then
                local currency = C_ProfSpecs.GetCurrencyInfoForSkillLine(info.professionID)
                if currency and currency.numAvailable ~= nil then
                    GameTooltip:AddLine(("Skill Pts Available: %d"):format(currency.numAvailable), 1, 1, 1)
                end
            end
        else
            GameTooltip:AddLine("Unlearned for this profession", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self)
        local info = self.professionInfo
        if not info then
            return
        end

        local onSpecializations = professionsFrame:GetTab() == professionsFrame.specializationsTabID
        if not onSpecializations and info.professionID == GetSelectedProfessionID() then
            return
        end

        if onSpecializations then
            -- Older expansions stay on Recipes because they have no specialization tree.
            local hasSpecializations = C_ProfSpecs.SkillLineHasSpecialization(info.professionID)
            pendingSpecReturn = hasSpecializations and info.professionID or nil
            professionsFrame:SetTab(professionsFrame.recipesTabID)
            EventRegistry:TriggerEvent("Professions.SelectSkillLine", info)
            if hasSpecializations then
                C_Timer.After(0, MaybeReturnToSpecializations)
            end
        else
            pendingSpecReturn = nil
            EventRegistry:TriggerEvent("Professions.SelectSkillLine", info)
        end
        RefreshBar()
    end)
    buttons[index] = button
    return button
end

RefreshBar = function()
    if not bar or not professionsFrame:IsShown() then
        return
    end

    local tab = professionsFrame:GetTab()
    if (tab ~= professionsFrame.recipesTabID and tab ~= professionsFrame.specializationsTabID)
        or C_TradeSkillUI.IsNPCCrafting() then
        bar:Hide()
        return
    end

    local infos = C_TradeSkillUI.GetChildProfessionInfos()
    if not infos or #infos == 0 then
        bar:Hide()
        return
    end

    local selectedID = GetSelectedProfessionID()
    local selectedFound = false
    for _, info in ipairs(infos) do
        if info.professionID == selectedID then
            selectedFound = true
            break
        end
    end
    if not selectedFound then
        local current = C_TradeSkillUI.GetChildProfessionInfo()
        selectedID = current and current.professionID
    end

    local infoByArt = {}
    for index, info in ipairs(infos) do
        local art = artByName[NameKey(info.expansionName)]
            or (#infos == #newestFirst and newestFirst[index])
        if art then
            infoByArt[art] = info
        end
    end

    for index, art in ipairs(newestFirst) do
        local info = infoByArt[art]
        local button = buttons[index] or CreateButton(index)
        button.professionInfo = info
        button.eraName = info and info.expansionName or eraLabels[art]
        button.art:SetTexture(EXPANSION_ART .. art .. ".tga")
        button.art:SetDesaturated(not info)
        for _, texture in ipairs(button.trimTextures) do
            texture:SetDesaturated(not info)
        end
        button.selection:SetShown(info ~= nil and info.professionID == selectedID)
        button:Show()
    end

    bar:SetHeight(#newestFirst * (BUTTON_SIZE + BUTTON_GAP) - BUTTON_GAP)
    AnchorBar()
    bar:Show()
end

MaybeReturnToSpecializations = function()
    if not pendingSpecReturn then
        return
    end
    if not professionsFrame or not professionsFrame:IsShown()
        or professionsFrame:GetTab() ~= professionsFrame.recipesTabID then
        pendingSpecReturn = nil
        return
    end
    if C_TradeSkillUI.IsDataSourceChanging() then
        return
    end
    local current = C_TradeSkillUI.GetChildProfessionInfo()
    if not current or current.professionID ~= pendingSpecReturn then
        return
    end

    pendingSpecReturn = nil
    professionsFrame:SetTab(professionsFrame.specializationsTabID)
    RefreshBar()
end

local function InitializeBar()
    if bar then
        return
    end
    professionsFrame = ProfessionsFrame
    if not professionsFrame then
        return
    end

    bar = CreateFrame("Frame", nil, professionsFrame)
    bar:SetWidth(BUTTON_SIZE)
    bar:Hide()
    professionsFrame:HookScript("OnSizeChanged", function()
        if bar:IsShown() then
            AnchorBar()
        end
    end)
    professionsFrame:HookScript("OnDragStop", function()
        if bar:IsShown() then
            AnchorBar()
        end
    end)
end

local function GetPrimaryProfession(slot)
    local first, second = GetProfessions()
    local index
    if slot == 1 then
        index = first
    else
        index = second
    end
    if not index then
        return
    end
    local name, _, _, _, _, _, skillLineID = GetProfessionInfo(index)
    return name, skillLineID
end

local function ShowLauncherTooltip()
    local firstName = GetPrimaryProfession(1)
    local secondName = GetPrimaryProfession(2)

    GameTooltip:SetOwner(launcher, "ANCHOR_RIGHT")
    GameTooltip:SetText("Profession Era Bar", 1, 0.82, 0)
    GameTooltip:AddLine("Left click: Open " .. (firstName or "unlearned first profession") .. " Recipes", 1, 1, 1)
    GameTooltip:AddLine("Right click: Open " .. (secondName or "unlearned second profession") .. " Recipes", 1, 1, 1)
    GameTooltip:AddLine(settings.locked and "Ctrl + left click: Unlock" or "Ctrl + left click: Lock", 0.7, 0.85, 1)
    if not settings.locked then
        GameTooltip:AddLine("Drag: Move  |  Shift + drag: Resize", 0.7, 0.85, 1)
    end
    GameTooltip:Show()
end

local function SaveLauncher()
    -- Keep the saved coordinates relative to UIParent after a drag.
    local x = launcher:GetLeft() or settings.x
    local y = launcher:GetBottom() or settings.y
    launcher:ClearAllPoints()
    launcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    settings.x = x
    settings.y = y
    settings.size = launcher:GetWidth()
end

local function InitializeLauncher()
    if launcher then
        return
    end

    if type(ProfessionEraBarDB) ~= "table" then
        ProfessionEraBarDB = {}
    end
    if type(ProfessionEraBarDB.profile) ~= "table" then
        ProfessionEraBarDB.profile = {}
    end
    settings = ProfessionEraBarDB.profile
    settings.size = math.max(28, math.min(96, tonumber(settings.size) or 44))
    settings.x = tonumber(settings.x) or 80
    settings.y = tonumber(settings.y) or 220
    if type(settings.locked) ~= "boolean" then
        settings.locked = false
    end

    launcher = CreateFrame("Button", "ProfessionEraBarLauncher", UIParent)
    launcher:SetSize(settings.size, settings.size)
    launcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.x, settings.y)
    launcher:SetFrameStrata("HIGH")
    launcher:SetMovable(true)
    launcher:SetClampedToScreen(true)
    launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    launcher:RegisterForDrag("LeftButton")

    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(MEDIA .. "ProfessionEraBar.tga")

    launcher:SetScript("OnEnter", ShowLauncherTooltip)
    launcher:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    launcher:SetScript("OnClick", function(self, mouseButton)
        if self.ignoreClick then
            return
        end
        if mouseButton == "LeftButton" and IsControlKeyDown() then
            settings.locked = not settings.locked
            ShowLauncherTooltip()
            return
        end

        local slot = mouseButton == "RightButton" and 2 or 1
        local _, skillLineID = GetPrimaryProfession(slot)
        if not skillLineID then
            return
        end
        pendingSpecReturn = nil
        C_TradeSkillUI.OpenTradeSkill(skillLineID)
        local frame = ProfessionsFrame
        if frame and frame:IsShown() then
            frame:SetTab(frame.recipesTabID)
        end
    end)
    launcher:SetScript("OnDragStart", function(self)
        if settings.locked then
            return
        end
        self.ignoreClick = true
        if IsShiftKeyDown() then
            self.resizing = true
            self.startCursorX = GetCursorPosition()
            self.startSize = self:GetWidth()
            self:SetScript("OnUpdate", function(button)
                local cursorX = GetCursorPosition()
                local size = button.startSize + (cursorX - button.startCursorX) / button:GetEffectiveScale()
                size = math.floor(math.max(28, math.min(96, size)) + 0.5)
                button:SetSize(size, size)
            end)
        else
            self:StartMoving()
        end
    end)
    launcher:SetScript("OnDragStop", function(self)
        if self.resizing then
            self.resizing = nil
            self:SetScript("OnUpdate", nil)
        else
            self:StopMovingOrSizing()
        end
        SaveLauncher()
        C_Timer.After(0, function()
            self.ignoreClick = nil
        end)
    end)
end

EventRegistry:RegisterCallback("ProfessionsFrame.Show", function()
    InitializeBar()
    RefreshBar()
end)
EventRegistry:RegisterCallback("ProfessionsFrame.TabSet", RefreshBar)
EventRegistry:RegisterCallback("Professions.ProfessionSelected", RefreshBar)
EventRegistry:RegisterCallback("ProfessionsFrame.Hide", function()
    pendingSpecReturn = nil
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitializeLauncher()
    else
        if pendingSpecReturn then
            C_Timer.After(0, MaybeReturnToSpecializations)
        end
        RefreshBar()
    end
end)
