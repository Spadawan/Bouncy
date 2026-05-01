-------------------------------------------------------------------------------
-- UI/Details.lua
-- Full statistics window: bunny art + evolution, XP progress, jump details
-- per zone per character, sit count, best streak, leaderboard.
-------------------------------------------------------------------------------

local B       = _G.Bouncy
B.Details     = {}
local Details = B.Details

local DW, DH = 560, 500
local TAB_H  = 28

-- Panel IDs
local PANEL_STATS    = 1
local PANEL_ZONES    = 2
local PANEL_LEADERS  = 3
local PANEL_CUSTOM   = 4

local activePanel    = PANEL_STATS
local activeCharKey  = nil   -- which char is selected in zones panel

local function PlayCreatureFeedAnim(p)
    if not p._feedAnim then
        local ag = p.artwork:CreateAnimationGroup()
        local s1 = ag:CreateAnimation("Scale")
        s1:SetOrigin("CENTER", 0, 0); s1:SetScale(1.05, 1.05); s1:SetDuration(0.12); s1:SetOrder(1)
        local t1 = ag:CreateAnimation("Translation")
        t1:SetOffset(2, 0); t1:SetDuration(0.05); t1:SetOrder(1)
        local t2 = ag:CreateAnimation("Translation")
        t2:SetOffset(-4, 0); t2:SetDuration(0.08); t2:SetOrder(2)
        local t3 = ag:CreateAnimation("Translation")
        t3:SetOffset(2, 0); t3:SetDuration(0.05); t3:SetOrder(3)
        local s2 = ag:CreateAnimation("Scale")
        s2:SetOrigin("CENTER", 0, 0); s2:SetScale(1 / 1.05, 1 / 1.05); s2:SetDuration(0.18); s2:SetOrder(2)
        p._feedAnim = ag
    end
    p._feedAnim:Stop()
    p._feedAnim:Play()
end

local function PlayCreatureEvolveAnim(p)
    if not p._evolveOldFx or not p._evolveNewFx then return end
    p._evolveOldFx:SetTexture("Interface\\AddOns\\Bouncy\\media\\Misc_Holy_01.tga")
    p._evolveOldFx:SetVertexColor(1, 0.95, 0.45, 1)
    p._evolveOldFx:SetAlpha(0.95)
    p._evolveNewFx:SetTexture("Interface\\AddOns\\Bouncy\\media\\Misc_Holy_02.tga")
    p._evolveNewFx:SetVertexColor(0.7, 0.95, 1, 1)
    p._evolveNewFx:SetAlpha(0)
    if not p._evolveOldAnim then
        local oldAg = p._evolveOldFx:CreateAnimationGroup()
        local oldFade = oldAg:CreateAnimation("Alpha")
        oldFade:SetFromAlpha(0.95); oldFade:SetToAlpha(0); oldFade:SetDuration(0.65); oldFade:SetOrder(1)
        oldAg:SetScript("OnFinished", function() if p._evolveOldFx then p._evolveOldFx:SetAlpha(0) end end)
        p._evolveOldAnim = oldAg
        local newAg = p._evolveNewFx:CreateAnimationGroup()
        local ni = newAg:CreateAnimation("Alpha")
        ni:SetFromAlpha(0); ni:SetToAlpha(1); ni:SetDuration(0.2); ni:SetOrder(1)
        local no = newAg:CreateAnimation("Alpha")
        no:SetFromAlpha(1); no:SetToAlpha(0); no:SetDuration(1.1); no:SetOrder(2)
        newAg:SetScript("OnFinished", function() if p._evolveNewFx then p._evolveNewFx:SetAlpha(0) end end)
        p._evolveNewAnim = newAg
    end
    p._evolveOldAnim:Stop(); p._evolveNewAnim:Stop()
    p._evolveOldAnim:Play(); p._evolveNewAnim:Play()
end

local function PlayCreaturePopup(p, text, color)
    if not p.popupText then return end
    p.popupText:SetText(text or "")
    if color then p.popupText:SetTextColor(color[1], color[2], color[3]) end
    p.popupText:SetAlpha(1)
    p.popupText:ClearAllPoints()
    p.popupText:SetPoint("CENTER", p.artwork, "CENTER", 0, 12)
    if p._popupAnim then p._popupAnim:Stop(); p._popupAnim:Play() end
    C_Timer.After(1.2, function()
        if p and p.popupText then
            p.popupText:SetAlpha(0)
        end
    end)
end

local function SpawnCreatureParticles(p, evolve)
    if not p.frame or not p.artwork then return end
    for i = 1, (evolve and 24 or 14) do
        local tex = p.frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(evolve and "Interface\\Cooldown\\star4" or "Interface\\Cooldown\\star2")
        if evolve then tex:SetVertexColor(1.0, 0.92, 0.25, 1) end
        tex:SetBlendMode("ADD")
        tex:SetSize(math.random(8, 22), math.random(8, 22))
        tex:SetPoint("CENTER", p.artwork, "CENTER", math.random(-24, 24), math.random(-18, 18))
        tex:SetAlpha(0)
        local ag = tex:CreateAnimationGroup()
        local fi = ag:CreateAnimation("Alpha")
        fi:SetFromAlpha(0); fi:SetToAlpha(0.9); fi:SetDuration(0.1); fi:SetOrder(1)
        local tr = ag:CreateAnimation("Translation")
        tr:SetOffset(math.random(-55, 55), evolve and math.random(30, 90) or -math.random(20, 65))
        tr:SetDuration(evolve and 1.0 or 0.7); tr:SetOrder(1)
        local fo = ag:CreateAnimation("Alpha")
        fo:SetFromAlpha(0.9); fo:SetToAlpha(0); fo:SetDuration(evolve and 1.0 or 0.8); fo:SetOrder(2)
        ag:SetScript("OnFinished", function() tex:SetAlpha(0); tex:Hide(); tex:SetTexture(nil) end)
        ag:Play()
    end
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function MakeFont(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "OUTLINE")
    return fs
end

local function ClassColorHex(classTag)
    local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag or ""]) or NORMAL_FONT_COLOR
    return string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
end

local function CreateTab(parent, label, idx, x)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(115, TAB_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -38)
    btn:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                      edgeSize = 10, insets = { left=3,right=3,top=3,bottom=3 } })
    btn:SetBackdropColor(0.06, 0.06, 0.14, 0.95)
    btn:SetBackdropBorderColor(0.3, 0.5, 0.9, 0.6)

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetText(label)
    btn.label = fs

    function btn:SetActive(on)
        if on then
            self:SetBackdropColor(0.12, 0.18, 0.40, 0.98)
            self:SetBackdropBorderColor(0.50, 0.75, 1.0, 1.0)
            self.label:SetTextColor(0.6, 0.9, 1.0)
        else
            self:SetBackdropColor(0.06, 0.06, 0.14, 0.90)
            self:SetBackdropBorderColor(0.3, 0.5, 0.9, 0.6)
            self.label:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    btn:SetActive(false)
    return btn
end

-------------------------------------------------------------------------------
-- Separator line helper
-------------------------------------------------------------------------------
local function HSep(parent, yoff)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, yoff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yoff)
    t:SetColorTexture(0.3, 0.5, 0.9, 0.25)
    return t
end

-------------------------------------------------------------------------------
-- Scrollable content frame inside a panel
-------------------------------------------------------------------------------
local function CreateScrollPanel(parent, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(w - 20, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w - 38, 1)   -- height grows dynamically
    sf:SetScrollChild(content)
    return sf, content
end

-------------------------------------------------------------------------------
-- Build Details window
-------------------------------------------------------------------------------
function Details:Init()
    local f = CreateFrame("Frame", "Bouncy_Details", UIParent, "BackdropTemplate")
    f:SetSize(DW, DH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClipsChildren(true)

    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets   = { left=5, right=5, top=5, bottom=5 },
    })
    f:SetBackdropColor(0.03, 0.03, 0.10, 0.97)
    f:SetBackdropBorderColor(0.45, 0.72, 1.0, 0.80)

    -- Animated particle background (subtle dots that float up)
    self:_BuildParticleBG(f)

    -- Title
    local title = MakeFont(f, 18, "OUTLINE")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText(string.format("|cff%sBOUNCY  -  Statistics", B.COLOR.TITLE))

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Separator under title
    HSep(f, -34)

    -- Tabs
    self.tabs = {}
    local tabLabels = { "Stats", "Zones", "Leaderboard", "Customize" }
    local tabX      = { 10, 130, 250, 370 }
    for i, lbl in ipairs(tabLabels) do
        local btn = CreateTab(f, lbl, i, tabX[i])
        btn:SetScript("OnClick", function() Details:ShowPanel(i) end)
        self.tabs[i] = btn
    end

    -- Panel container
    local panelY = -38 - TAB_H - 4

    self.panels = {}
    for i = 1, 4 do
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT",  f, "TOPLEFT",  8,  panelY)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        p:Hide()
        self.panels[i] = p
    end

    self.frame = f

    -- Build each panel content
    self:_BuildStatsPanel(self.panels[PANEL_STATS])
    self:_BuildZonesPanel(self.panels[PANEL_ZONES])
    self:_BuildLeaderPanel(self.panels[PANEL_LEADERS])
    self:_BuildCustomPanel(self.panels[PANEL_CUSTOM])

    self:ShowPanel(PANEL_STATS)
    f:Hide()

    -- Live refresh: subscribe to the same Tracker event bus as the Overlay.
    -- All panels update in real time whenever a jump is recorded.
    B.Tracker:RegisterCallback(function(event, data)
        if not self.frame:IsShown() then return end
        if event == "JUMP" or event == "STREAK_BREAK" or event == "OVERLAY_REFRESH" then
            self:Refresh()
        end
    end)

    -- Fallback throttled OnUpdate (catches edge cases: zone changes, level-ups
    -- triggered from other code paths that don't go through Tracker callbacks).
    local tickElapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        tickElapsed = tickElapsed + dt
        if tickElapsed < 1.0 then return end
        tickElapsed = 0
        Details:Refresh()
    end)
end

-------------------------------------------------------------------------------
-- Panel switcher
-------------------------------------------------------------------------------
function Details:ShowPanel(idx)
    activePanel = idx
    for i, p in ipairs(self.panels) do
        p:SetShown(i == idx)
        self.tabs[i]:SetActive(i == idx)
    end
    if B.Overlay and B.Overlay.frame and activePanel == PANEL_CUSTOM then
        B.Overlay.frame:Show()
    end
    self:Refresh()
end

-------------------------------------------------------------------------------
-- PANEL 1 — Stats: bunny art + XP + totals + title
-------------------------------------------------------------------------------
function Details:_BuildStatsPanel(p)
    local artwork = p:CreateTexture(nil, "ARTWORK")
    artwork:SetSize(128, 128)
    artwork:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -10)
    artwork:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
    artwork:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    p.artwork = artwork
    local eggFrame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    eggFrame:SetSize(84, 84)
    eggFrame:SetPoint("CENTER", artwork, "CENTER", 0, 0)
    eggFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left=3, right=3, top=3, bottom=3 },
    })
    eggFrame:SetBackdropColor(0.03, 0.03, 0.08, 0.85)
    eggFrame:SetBackdropBorderColor(0.5, 0.7, 1.0, 0.75)
    eggFrame:Hide()
    p.eggFrame = eggFrame

    local lvlName = MakeFont(p, 15, "OUTLINE")
    lvlName:SetPoint("TOPLEFT", artwork, "TOPRIGHT", 18, -6)
    p.lvlName = lvlName

    -- Title line (player title from jumps milestone)
    local titleLine = MakeFont(p, 11, "")
    titleLine:SetPoint("TOPLEFT", artwork, "TOPRIGHT", 18, -26)
    p.titleLine = titleLine

    local xpBar = CreateFrame("StatusBar", nil, p)
    xpBar:SetSize(230, 14)
    xpBar:SetPoint("TOPLEFT", artwork, "TOPRIGHT", 18, -46)
    xpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBar:SetStatusBarColor(0.40, 0.95, 0.40)
    xpBar:SetMinMaxValues(0, 1)
    local xpBG = xpBar:CreateTexture(nil, "BACKGROUND")
    xpBG:SetAllPoints(); xpBG:SetColorTexture(0.10, 0.10, 0.10, 0.80)
    p.xpBar = xpBar

    local xpLabel = MakeFont(p, 10, "")
    xpLabel:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -2)
    p.xpLabel = xpLabel

    local playerXPBar = CreateFrame("StatusBar", nil, p)
    playerXPBar:SetSize(230, 10)
    playerXPBar:SetPoint("TOPLEFT", xpLabel, "BOTTOMLEFT", 0, -8)
    playerXPBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    playerXPBar:SetStatusBarColor(0.35, 0.55, 1.0)
    playerXPBar:SetMinMaxValues(0, 1)
    local pbg = playerXPBar:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints(); pbg:SetColorTexture(0.10, 0.10, 0.10, 0.80)
    p.playerXPBar = playerXPBar

    local playerXPLabel = MakeFont(p, 10, "")
    playerXPLabel:SetPoint("TOPLEFT", playerXPBar, "BOTTOMLEFT", 0, -2)
    p.playerXPLabel = playerXPLabel

    local playerLvlLabel = MakeFont(p, 10, "OUTLINE")
    playerLvlLabel:SetPoint("TOPLEFT", playerXPLabel, "BOTTOMLEFT", 0, -2)
    p.playerLvlLabel = playerLvlLabel

    local streakLabel = MakeFont(p, 11, "OUTLINE")
    streakLabel:SetPoint("TOPLEFT", playerLvlLabel, "BOTTOMLEFT", 0, -8)
    p.streakLabel = streakLabel

    -- Next title goal
    local nextTitleLabel = MakeFont(p, 10, "")
    nextTitleLabel:SetPoint("TOPLEFT", streakLabel, "BOTTOMLEFT", 0, -8)
    p.nextTitleLabel = nextTitleLabel

    local sep = HSep(p, -246)
    p.statsSep = sep

    local statY = -258
    local function StatRow(label, yoff)
        local lbl = MakeFont(p, 11, "")
        lbl:SetPoint("TOPLEFT", p, "TOPLEFT", 20, yoff)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))
        local val = MakeFont(p, 13, "OUTLINE")
        val:SetPoint("TOPLEFT", p, "TOPLEFT", 210, yoff)
        return lbl, val
    end

    local _, r1 = StatRow("Jumps - Total",  statY)
    local _, r2 = StatRow("Jumps - Today",  statY - 22)
    local _, r3 = StatRow("Jumps - Week",   statY - 44)
    local _, r4 = StatRow("Jumps / Minute", statY - 66)
    local _, r5 = StatRow("Jumps / Hour",   statY - 88)

    p._r = { r1, r2, r3, r4, r5 }

    local function MakeSmallButton(label, width, onClick)
        local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    p.evolveBtn = MakeSmallButton("Feed", 90, function()
        local prog = B.DB:GetProgression()
        if B.Leveling:CanEvolve(prog) then
            local req = B.Leveling:GetCreatureXPRequirement(prog.level or 1)
            prog.creatureXP = math.max(0, (prog.creatureXP or 0) - req)
            prog.level = (prog.level or 1) + 1
            PlayCreatureEvolveAnim(p)
            SpawnCreatureParticles(p, true)
            PlayCreaturePopup(p, "Level up!", {0.4, 1.0, 0.3})
            if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\Bouncy\\media\\LevelUp.ogg", "SFX") end
        else
            local feedAmount = 50
            if (prog.xp or 0) >= feedAmount then
                prog.xp = prog.xp - feedAmount
                prog.creatureXP = (prog.creatureXP or 0) + feedAmount
                local autoLevel = B.Leveling:AdvanceCreatureNonEvolutionLevels(prog)
                PlayCreatureFeedAnim(p)
                SpawnCreatureParticles(p, false)
                PlayCreaturePopup(p, autoLevel and "Level up!" or "+50 EXP", {0.4, 1.0, 0.3})
                if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\Bouncy\\media\\iEating1.ogg", "SFX") end
            else
                PlayCreaturePopup(p, "Not enough player EXP", {1.0, 0.2, 0.2})
            end
        end
        Details:Refresh()
    end)
    p.evolveBtn:SetPoint("TOP", artwork, "BOTTOM", 0, -8)

    p.typeHint = MakeFont(p, 10, "")
    p.typeHint:SetPoint("BOTTOM", p.statsSep, "TOP", 0, 34)

    p.typeButtons = {}
    local bx = 0
    for _, creatureType in ipairs(B.CREATURE_TYPES or {}) do
        local btn = MakeSmallButton(creatureType, 72, function()
            B.DB:SetCreatureType(creatureType)
            Details:Refresh()
        end)
        btn:SetPoint("BOTTOMLEFT", p.typeHint, "TOPLEFT", bx, 6)
        bx = bx + 76
        table.insert(p.typeButtons, btn)
    end
    local spacing = 76
    local startX = -math.floor(((#p.typeButtons - 1) * spacing) / 2)
    for i, btn in ipairs(p.typeButtons) do
        btn:ClearAllPoints()
        btn:SetPoint("TOP", p.typeHint, "BOTTOM", startX + ((i - 1) * spacing), -6)
    end

    local popupText = MakeFont(p, 12, "OUTLINE")
    popupText:SetPoint("CENTER", artwork, "CENTER", 0, 12)
    popupText:SetAlpha(0)
    p.popupText = popupText
    local pag = popupText:CreateAnimationGroup()
    local hold = pag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(0.25); hold:SetOrder(1)
    local fade = pag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.8); fade:SetOrder(2)
    local rise = pag:CreateAnimation("Translation")
    rise:SetOffset(0, 22); rise:SetDuration(1.05); rise:SetOrder(1)
    pag:SetScript("OnFinished", function()
        popupText:SetAlpha(0)
        popupText:ClearAllPoints()
        popupText:SetPoint("CENTER", artwork, "CENTER", 0, 12)
    end)
    p._popupAnim = pag

    local evolveOldFx = p:CreateTexture(nil, "OVERLAY")
    evolveOldFx:SetAllPoints(artwork); evolveOldFx:SetAlpha(0)
    p._evolveOldFx = evolveOldFx
    local evolveNewFx = p:CreateTexture(nil, "OVERLAY")
    evolveNewFx:SetAllPoints(artwork); evolveNewFx:SetAlpha(0)
    p._evolveNewFx = evolveNewFx
end

function Details:_RefreshStats(p)
    local char = B.DB:GetChar()
    if not char then return end
    local prog = B.DB:GetProgression()

    local creatureLvl = prog.level or 1
    local stage = B.Leveling:GetCreatureStage(creatureLvl)
    local reqXP = B.Leveling:GetCreatureXPRequirement(creatureLvl)
    local frac = math.min(1, (prog.creatureXP or 0) / math.max(1, reqXP))
    local creatureLocked = not prog.creatureType
    if creatureLocked then
        p.artwork:SetTexture("Interface\\Icons\\INV_Egg_02")
        p.artwork:SetSize(64, 64)
        p.artwork:ClearAllPoints()
        p.artwork:SetPoint("TOPLEFT", p, "TOPLEFT", 48, -38)
        p.eggFrame:Show()
        p.lvlName:SetText("|cffffcc00Creature not selected|r")
        p.evolveBtn:Hide()
        p.xpBar:Hide()
        p.xpLabel:Hide()
    else
        p.eggFrame:Hide()
        p.artwork:SetSize(128, 128)
        p.artwork:ClearAllPoints()
        p.artwork:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -10)
        p.artwork:SetTexture(string.format("Interface\\AddOns\\Bouncy\\media\\Astral_%02d.tga", stage.art))
        local bonusPct = B.Leveling:GetCreatureBonusPercent(prog.level or 1)
        p.lvlName:SetText(string.format("|cff%sLevel %d|r  %s  |cff66AAFF+%d%% Bonus XP|r",
            B.COLOR.LEVEL_UP, creatureLvl, stage.label, bonusPct))
        p.evolveBtn:Show()
        p.xpBar:SetValue(frac)
        p.xpLabel:SetText(string.format("|cff%s%s|r / |cff%s%s|r creature XP",
            B.COLOR.XP, B.FormatNum(prog.creatureXP or 0), B.COLOR.DIM, B.FormatNum(reqXP)))
        p.xpBar:Show()
        p.xpLabel:Show()
    end
    local playerLevelData = B.Leveling:GetLevelForXP(prog.xp or 0)
    local _, pCur, pNext = B.Leveling:GetProgress(prog.xp or 0)
    local playerFrac = 1
    if pNext then
        local need = math.max(1, (pNext.threshold - pCur.threshold))
        playerFrac = math.min(1, ((prog.xp or 0) - pCur.threshold) / need)
    end
    p.playerXPBar:SetValue(playerFrac)
    p.playerXPLabel:SetText(string.format("|cff88AAFFPlayer XP reserve:|r %s", B.FormatNum(prog.xp or 0)))
    p.playerLvlLabel:SetText(string.format("|cff88AAFFPlayer Level:|r %d - %s",
        playerLevelData.level or 1, playerLevelData.name or ""))
    p.streakLabel:SetText(string.format("Best streak: |cff%s%d|r jumps",
        B.COLOR.STREAK, char.bestStreak or 0))

    -- Current title
    local curTitle = B.GetTitle(char.totalJumps)
    if curTitle then
        p.titleLine:SetText(string.format("Title: |cff%s%s|r",
            curTitle.color, curTitle.title))
    else
        p.titleLine:SetText(string.format("|cff%sNo title yet|r", B.COLOR.DIM))
    end

    -- Next title goal
    local nextTitle = B.GetNextTitle(char.totalJumps)
    if nextTitle then
        local remaining = nextTitle.jumps - char.totalJumps
        p.nextTitleLabel:SetText(string.format(
            "|cff%sNext: |r|cff%s%s|r |cff%s(%s jumps away)|r",
            B.COLOR.DIM, nextTitle.color, nextTitle.title,
            B.COLOR.DIM, B.FormatNum(remaining)))
    else
        p.nextTitleLabel:SetText(string.format("|cff%sAll titles unlocked!|r", B.COLOR.LEVEL_UP))
    end

    local sessionJumps = (B.Tracker and B.Tracker.GetSessionJumps and B.Tracker:GetSessionJumps()) or 0
    local sessionTime = (B.Tracker and B.Tracker.GetSessionDuration and B.Tracker:GetSessionDuration()) or 1
    local jpm = sessionJumps / (sessionTime / 60)
    local jph = sessionJumps / (sessionTime / 3600)
    local r = p._r
    r[1]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.totalJumps)))
    r[2]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.daily.jumps or 0)))
    r[3]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.weekly.jumps or 0)))
    r[4]:SetText(string.format("|cff%s%.2f|r", B.COLOR.JUMP, jpm))
    r[5]:SetText(string.format("|cff%s%.2f|r", B.COLOR.JUMP, jph))

    local playerLevel = (playerLevelData and playerLevelData.level) or 1
    local shouldChooseType = (playerLevel >= 2 and not prog.creatureType)
    p.typeHint:SetShown((prog.creatureType ~= nil) or shouldChooseType)
    if shouldChooseType then
        p.typeHint:SetText("|cffffcc00Select a creature type (unlocked at player level 2).|r")
    elseif creatureLocked then
        p.typeHint:SetText("|cffff8800Reach player level 2 to choose your creature type.|r")
    elseif prog.creatureType then
        p.typeHint:SetText("")
    end
    for _, btn in ipairs(p.typeButtons or {}) do
        btn:SetShown(shouldChooseType)
    end
    if prog.creatureType then
        p.evolveBtn:SetText(B.Leveling:CanEvolve(prog) and "Evolve" or "Feed")
    end
end

-------------------------------------------------------------------------------
-- PANEL 2 — Zones: per-character zone breakdown
-------------------------------------------------------------------------------
function Details:_BuildZonesPanel(p)
    -- Character selector (dropdown-style list on the left)
    local charList = CreateFrame("Frame", nil, p, "BackdropTemplate")
    charList:SetSize(150, 420)
    charList:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
    charList:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                           edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                           edgeSize = 10, insets={left=3,right=3,top=3,bottom=3} })
    charList:SetBackdropColor(0.05, 0.05, 0.12, 0.92)
    charList:SetBackdropBorderColor(0.3, 0.4, 0.7, 0.5)
    p.charList = charList

    -- Zone scroll on the right
    local sf, content = CreateScrollPanel(p, 380, 400)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 162, -4)
    p.zoneSF      = sf
    p.zoneContent = content
end

function Details:_RefreshZones(p)
    local chars = B.DB:GetAllChars()
    local keys  = {}
    for k in pairs(chars) do table.insert(keys, k) end
    table.sort(keys, function(a,b)
        return (chars[a].totalJumps or 0) > (chars[b].totalJumps or 0)
    end)

    if not activeCharKey or not chars[activeCharKey] then
        activeCharKey = B.DB:CharKey()
        if not chars[activeCharKey] then
            activeCharKey = keys[1]
        end
    end

    -------- Char list: rebuild buttons only when the key set changes --------
    local charList = p.charList
    local keySet   = table.concat(keys, "|")
    if p._lastKeySet ~= keySet then
        -- Key list changed (new character logged in) → full rebuild of buttons
        if charList._btns then
            for _, b in ipairs(charList._btns) do b:Hide() end
        end
        charList._btns  = {}
        charList._btext = {}   -- store label fontstrings for live update
        p._lastKeySet = keySet

        local btnY = -8
        for _, key in ipairs(keys) do
            local char = chars[key]
            local btn  = CreateFrame("Button", nil, charList, "BackdropTemplate")
            btn:SetSize(136, 28)
            btn:SetPoint("TOP", charList, "TOP", 0, btnY)
            btn:SetBackdrop({ bgFile="Interface\\ChatFrame\\ChatFrameBackground",
                              edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                              edgeSize=8, insets={left=2,right=2,top=2,bottom=2} })
            btn._key = key

            local bfs = btn:CreateFontString(nil, "OVERLAY")
            bfs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            bfs:SetAllPoints(); bfs:SetJustifyH("CENTER")
            btn._fs = bfs

            local capturedKey = key
            btn:SetScript("OnClick", function()
                activeCharKey = capturedKey
                p._lastZoneKey = nil   -- force zone list rebuild on next refresh
                Details:_RefreshZones(p)
            end)
            table.insert(charList._btns, btn)
            btnY = btnY - 32
        end
    end

    -- Update button labels + highlight in place (cheap, every refresh)
    for _, btn in ipairs(charList._btns) do
        local key  = btn._key
        local char = chars[key]
        if char then
            local isActive = (key == activeCharKey)
            btn:SetBackdropColor(isActive and 0.12 or 0.06, isActive and 0.18 or 0.06,
                                 isActive and 0.38 or 0.12, 0.95)
            btn:SetBackdropBorderColor(isActive and 0.5 or 0.25,
                                       isActive and 0.75 or 0.35,
                                       isActive and 1.0 or 0.55, 0.8)
            local classHex = ClassColorHex(char.class)
            btn._fs:SetText(string.format("|cff%s%s|r\n|cff%s%s jumps|r",
                classHex, char.name or key,
                B.COLOR.DIM, B.FormatNum(char.totalJumps or 0)))
            btn:Show()
        end
    end

    -------- Zone list: rebuild only when active char or zone set changes --------
    local char = activeCharKey and chars[activeCharKey]
    if not char then return end

    -- Build a lightweight key from current zone data to detect changes
    local zones = {}
    for zone, count in pairs(char.byZone or {}) do
        table.insert(zones, { zone = zone, count = count })
    end
    table.sort(zones, function(a,b) return a.count > b.count end)

    local zoneKey = activeCharKey .. ":" .. #zones
    local needRebuild = (p._lastZoneKey ~= zoneKey)
    p._lastZoneKey = zoneKey

    local content  = p.zoneContent
    local maxCount = (zones[1] and zones[1].count) or 1
    local cW       = 310

    if needRebuild then
        -- Full rebuild of zone rows (zone count changed or char switched)
        content:SetHeight(1)
        for _, child in ipairs({content:GetChildren()}) do child:Hide() end
        for _, child in ipairs({content:GetRegions()}) do child:Hide() end
        p._zoneWidgets = {}   -- { fill, cnt, lbl } per row

        local rowH = 24
        local yOff = -8

        local hdr = content:CreateFontString(nil,"OVERLAY")
        hdr:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOff)
        hdr:SetText(string.format("|cff%sJumps by zone - %s|r",
            B.COLOR.TITLE, char.name or activeCharKey))
        p._zoneHdr = hdr
        yOff = yOff - 22

        for i, entry in ipairs(zones) do
            local lbl = content:CreateFontString(nil,"OVERLAY")
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOff + 2)

            local barBG = content:CreateTexture(nil, "BACKGROUND")
            barBG:SetHeight(12)
            barBG:SetPoint("TOPLEFT",  content, "TOPLEFT", 4,  yOff - 10)
            barBG:SetPoint("TOPRIGHT", content, "TOPLEFT", cW, yOff - 10)
            barBG:SetColorTexture(0.1, 0.1, 0.1, 0.7)

            local barFill = content:CreateTexture(nil, "ARTWORK")
            barFill:SetHeight(12)
            barFill:SetPoint("TOPLEFT", barBG, "TOPLEFT", 0, 0)
            local r = i == 1 and 1.0 or 0.2
            local g = i == 1 and 0.7 or 0.5
            local bb= i == 1 and 0.0 or 1.0
            barFill:SetColorTexture(r, g, bb, 0.75)

            local cnt = content:CreateFontString(nil,"OVERLAY")
            cnt:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            cnt:SetPoint("RIGHT", barBG, "RIGHT", -4, 0)
            cnt:SetJustifyH("RIGHT")

            table.insert(p._zoneWidgets, { fill=barFill, cnt=cnt, lbl=lbl,
                                           barBG=barBG, isFirst=(i==1) })
            yOff = yOff - rowH - 4
        end
        content:SetHeight(math.abs(yOff) + 20)
    end

    -- Update values in place (every refresh, cheap)
    if p._zoneHdr then
        p._zoneHdr:SetText(string.format("|cff%sJumps by zone - %s|r",
            B.COLOR.TITLE, char.name or activeCharKey))
    end
    for i, w in ipairs(p._zoneWidgets or {}) do
        local entry = zones[i]
        if entry then
            w.lbl:SetText(string.format("|cff%s%s|r",
                w.isFirst and "FFD700" or "CCCCCC", entry.zone))
            w.cnt:SetText(string.format("|cff%s%s|r",
                B.COLOR.JUMP, B.FormatNum(entry.count)))
            local frac  = entry.count / maxCount
            local fillW = math.max(4, math.floor(frac * (cW - 8)))
            w.fill:SetWidth(fillW)
        end
    end
end

-------------------------------------------------------------------------------
-- PANEL 3 — Leaderboard
-------------------------------------------------------------------------------
function Details:_BuildLeaderPanel(p)
    local sf, content = CreateScrollPanel(p, DW - 20, 420)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
    p.leaderSF      = sf
    p.leaderContent = content
end

function Details:_RefreshLeaders(p)
    local lb = B.DB:GetLeaderboard()
    local entries = {}
    for key, data in pairs(lb) do
        table.insert(entries, { key=key, name=data.name, realm=data.realm,
                                 class=data.class, jumps=data.jumps or 0, level=data.level or 1,
                                 petLevel=data.petLevel or 1, bestStreak=data.bestStreak or 0 })
    end
    table.sort(entries, function(a,b) return a.jumps > b.jumps end)

    local content = p.leaderContent
    local maxJ    = (entries[1] and entries[1].jumps) or 1

    -------- Rebuild rows only when entry count changes --------
    if p._leaderCount ~= #entries then
        p._leaderCount = #entries
        content:SetHeight(1)
        for _, child in ipairs({content:GetChildren()}) do child:Hide() end
        for _, child in ipairs({content:GetRegions()}) do child:Hide() end
        p._leaderWidgets = {}

        local rowH = 36
        local yOff = -10

        local hdr = content:CreateFontString(nil,"OVERLAY")
        hdr:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
        hdr:SetText(string.format("|cff%sLeaderboard - Total Jumps|r", B.COLOR.TITLE))
        yOff = yOff - 28

        for rank = 1, #entries do
            local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetSize(490, rowH)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 8, yOff)
            row:SetBackdrop({ bgFile="Interface\\ChatFrame\\ChatFrameBackground",
                              edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                              edgeSize=8, insets={left=2,right=2,top=2,bottom=2} })

            local rankColors = { "FFD700", "C0C0C0", "CD7F32" }
            local rankFS = row:CreateFontString(nil,"OVERLAY")
            rankFS:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            rankFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            rankFS:SetText(string.format("|cff%s#%d|r", rankColors[rank] or B.COLOR.DIM, rank))

            local nameFS = row:CreateFontString(nil,"OVERLAY")
            nameFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            nameFS:SetPoint("LEFT", row, "LEFT", 52, 4)

            local realmFS = row:CreateFontString(nil,"OVERLAY")
            realmFS:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            realmFS:SetPoint("LEFT", row, "LEFT", 52, -8)

            local jumpFS = row:CreateFontString(nil,"OVERLAY")
            jumpFS:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
            jumpFS:SetPoint("RIGHT", row, "RIGHT", -12, 0)

            local lvlFS = row:CreateFontString(nil,"OVERLAY")
            lvlFS:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            lvlFS:SetPoint("RIGHT", jumpFS, "LEFT", -10, 0)

            local bar = row:CreateTexture(nil,"ARTWORK")
            bar:SetHeight(3)
            bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 50, 4)

            table.insert(p._leaderWidgets, {
                row=row, nameFS=nameFS, realmFS=realmFS, jumpFS=jumpFS, lvlFS=lvlFS, bar=bar
            })
            yOff = yOff - rowH - 4
        end

        if #entries == 0 then
            local empty = content:CreateFontString(nil,"OVERLAY")
            empty:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
            empty:SetPoint("TOP", content, "TOP", 0, -40)
            empty:SetText(string.format("|cff%sNo jumps recorded yet.|r", B.COLOR.DIM))
        end
        content:SetHeight(math.abs(yOff) + 20)
    end

    -------- Update values in place (every refresh) --------
    local selfKey = B.DB:CharKey()
    for rank, w in ipairs(p._leaderWidgets or {}) do
        local entry = entries[rank]
        if entry then
            local isSelf = (entry.key == selfKey)
            w.row:SetBackdropColor(isSelf and 0.08 or 0.04, isSelf and 0.12 or 0.04,
                                   isSelf and 0.30 or 0.10, 0.92)
            w.row:SetBackdropBorderColor(isSelf and 0.5 or 0.2, isSelf and 0.8 or 0.3,
                                         isSelf and 1.0 or 0.5, 0.7)
            local nameHex = ClassColorHex(entry.class)
            w.nameFS:SetText(string.format("|cff%s%s|r",
                nameHex, entry.name or "?"))
            w.realmFS:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, entry.realm or ""))
            w.jumpFS:SetText(string.format("|cff%s%s|r  |cff%sjumps|r",
                B.COLOR.JUMP, B.FormatNum(entry.jumps), B.COLOR.DIM))
            w.lvlFS:SetText(string.format("|cff66AAFFLv.%d|r", entry.level or 1))
            local barW = math.max(4, math.floor((entry.jumps / maxJ) * 280))
            w.bar:SetWidth(barW)
            w.bar:SetColorTexture(isSelf and 0.4 or 0.25, isSelf and 0.85 or 0.5,
                                   isSelf and 1.0 or 0.7, 0.8)
            w.row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText((entry.name or "?") .. " - " .. (entry.realm or ""))
                GameTooltip:AddLine(string.format("Jump Level: %d", entry.level or 1), 0.4, 0.8, 1.0)
                GameTooltip:AddLine(string.format("Pet Max Level: %d", entry.petLevel or 1), 0.7, 1.0, 0.7)
                GameTooltip:AddLine(string.format("Best Streak: %d", entry.bestStreak or 0), 1.0, 0.85, 0.3)
                GameTooltip:Show()
            end)
            w.row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
end

-------------------------------------------------------------------------------
-- Particle background (subtle animated dots)
-------------------------------------------------------------------------------
function Details:_BuildParticleBG(parent)
    local NUM   = 18
    local dots  = {}
    local pf    = CreateFrame("Frame", nil, parent)
    pf:SetAllPoints()
    pf:SetFrameLevel(parent:GetFrameLevel())

    for i = 1, NUM do
        local d = pf:CreateTexture(nil, "BACKGROUND")
        d:SetSize(3, 3)
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        local alpha = 0.03 + math.random() * 0.06
        d:SetColorTexture(0.4, 0.6, 1.0, alpha)
        d:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT",
            math.random(10, DW - 10), math.random(10, DH - 10))
        dots[i] = { tex=d, x=math.random(10,DW-10), y=math.random(5, 40),
                    speed=4+math.random()*8, phase=math.random()*6.28 }
    end

    local elapsed = 0
    pf:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        for _, dot in ipairs(dots) do
            dot.y = dot.y + dot.speed * dt
            if dot.y > DH then dot.y = 0 end
            local wobbleX = dot.x + math.sin(elapsed * 0.5 + dot.phase) * 6
            dot.tex:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT", wobbleX, dot.y)
        end
    end)
end

-------------------------------------------------------------------------------
-- PANEL 4 — Customize
-- All controls apply immediately and call Overlay:ApplySettings().
-------------------------------------------------------------------------------

-- Palette of preset colors for the jump counter
local PALETTE_COLORS = {
    "FFFFFF", "FFFF00", "FFD700", "FF8844", "FF4444", "FF00BB", "CC44FF", "6688FF",
    "00AAFF", "00DDCC", "00FF88", "66FF33", "A0E4FF", "FFB6C1", "CCCCCC", "888888",
}

local function HexToRGB(hex)
    return tonumber(hex:sub(1,2),16)/255,
           tonumber(hex:sub(3,4),16)/255,
           tonumber(hex:sub(5,6),16)/255
end

local function RGBToHex(r, g, b)
    return string.format("%02X%02X%02X",
        math.floor(r*255+0.5), math.floor(g*255+0.5), math.floor(b*255+0.5))
end

local function BuildFontList()
    local list = {
        { name = "Friz Quadrata",  path = "Fonts\\FRIZQT__.TTF"  },
        { name = "Arial Narrow",   path = "Fonts\\ARIALN.TTF"    },
        { name = "Morpheus",       path = "Fonts\\MORPHEUS.TTF"  },
        { name = "Skurri",         path = "Fonts\\skurri.TTF"    },
        { name = "Expressway",     path = "Fonts\\EXPRESWAY.TTF" },
    }
    if LibStub then
        local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and LSM then
            local ht  = LSM:HashTable("font")
            local seen = {}
            for _, f in ipairs(list) do seen[f.path] = true end
            for name, path in pairs(ht) do
                if not seen[path] then
                    table.insert(list, { name=name, path=path })
                    seen[path] = true
                end
            end
            table.sort(list, function(a,b) return a.name:lower() < b.name:lower() end)
        end
    end
    return list
end

function Details:_BuildCustomPanel(p)
    local s = B.DB:GetSettings()
    local sf, c = CreateScrollPanel(p, DW - 16, 420)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)

    p._updaters = {}
    local y = -8

    local function ApplyNow()
        if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
    end

    -- Helper: section header
    local function SectionHdr(label)
        local sep = c:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  c, "TOPLEFT",  4, y - 16)
        sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y - 16)
        sep:SetColorTexture(0.3, 0.5, 0.9, 0.25)
        local hdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y)
        hdr:SetText(string.format("|cff%s%s|r", B.COLOR.TITLE, label))
        y = y - 28
    end

    -- Helper: checkbox
    local function Checkbox(label, tooltip, getter, setter)
        local cb = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y)
        cb:SetChecked(getter())
        if cb.Text then cb.Text:SetText(label) end
        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked())
            ApplyNow()
        end)
        if tooltip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1,1,1)
                GameTooltip:AddLine(tooltip, 0.8,0.8,0.8, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        table.insert(p._updaters, function() cb:SetChecked(getter()) end)
        y = y - 26
        return cb
    end

    -- Helper: slider
    local function Slider(label, minV, maxV, step, getter, setter, fmt)
        fmt = fmt or "%.0f"
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))
        local sl = CreateFrame("Slider", nil, c, "OptionsSliderTemplate")
        sl:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y - 14)
        sl:SetWidth(DW - 80)
        sl:SetMinMaxValues(minV, maxV)
        sl:SetValueStep(step)
        sl:SetValue(getter())
        if sl.Low  then sl.Low:SetText(string.format(fmt, minV))  end
        if sl.High then sl.High:SetText(string.format(fmt, maxV)) end
        if sl.Text then sl.Text:SetText(string.format(fmt, getter())) end
        sl:SetScript("OnValueChanged", function(self, val)
            val = math.floor(val / step + 0.5) * step
            if sl.Text then sl.Text:SetText(string.format(fmt, val)) end
            setter(val)
            ApplyNow()
        end)
        table.insert(p._updaters, function() sl:SetValue(getter()) end)
        y = y - 42
        return sl
    end

    -- Helper: dropdown (cycle button)
    local function Dropdown(label, options, getter, setter)
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))
        local btn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
        local function UpdateBtn() btn:SetText(getter()) end
        UpdateBtn()
        btn:SetScript("OnClick", function()
            local cur = getter(); local nextOpt = options[1]
            for i, opt in ipairs(options) do
                if opt == cur then nextOpt = options[(i % #options) + 1]; break end
            end
            setter(nextOpt); UpdateBtn(); ApplyNow()
        end)
        table.insert(p._updaters, function() UpdateBtn() end)
        y = y - 28
    end

    -- Helper: color palette (16 swatches, 8 per row)
    local function ColorPalette(label, getter, setter)
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))
        y = y - 22

        local SW, GAP, COLS = 24, 4, 8
        local swatches = {}

        local function GetCurHex()
            local col = getter()
            return RGBToHex(col.r, col.g, col.b):upper()
        end
        local function UpdateSelection()
            local cur = GetCurHex()
            for _, sw in ipairs(swatches) do
                sw:SetBackdropBorderColor(sw._hex == cur and 1 or 0.15,
                                          sw._hex == cur and 1 or 0.15,
                                          sw._hex == cur and 1 or 0.15, 1)
            end
        end

        for i, hex in ipairs(PALETTE_COLORS) do
            local cr, cg, cb_val = HexToRGB(hex)
            local col_idx = i - 1
            local row_i   = math.floor(col_idx / COLS)
            local col_i   = col_idx % COLS
            local sw = CreateFrame("Button", nil, c, "BackdropTemplate")
            sw:SetSize(SW, SW)
            sw:SetPoint("TOPLEFT", c, "TOPLEFT",
                8  + col_i * (SW + GAP),
                y  - row_i * (SW + GAP))
            sw:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 4,
                insets   = { left=1, right=1, top=1, bottom=1 },
            })
            sw:SetBackdropColor(cr, cg, cb_val, 1)
            sw:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
            sw._hex = hex:upper()
            sw:SetScript("OnClick", function()
                setter({ r=cr, g=cg, b=cb_val })
                UpdateSelection()
                ApplyNow()
            end)
            sw:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("#"..hex, cr, cg, cb_val)
                GameTooltip:Show()
            end)
            sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
            table.insert(swatches, sw)
        end

        local numRows = math.ceil(#PALETTE_COLORS / COLS)
        y = y - numRows * (SW + GAP) - 6
        table.insert(p._updaters, function() UpdateSelection() end)
        UpdateSelection()
    end

    -- Helper: font picker (scrollable dropdown)
    local function FontPicker(label)
        local fonts     = BuildFontList()

        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))

        local dd = CreateFrame("Frame", nil, c, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", c, "TOPLEFT", -8, y - 16)
        UIDropDownMenu_SetWidth(dd, 280)

        local function SetSelected(path)
            s.overlayFont = path
            ApplyNow()
        end

        UIDropDownMenu_Initialize(dd, function(self, level)
            local itemsPerPage = 18
            local startIdx = ((level or 1) - 1) * itemsPerPage + 1
            local stopIdx = math.min(#fonts, startIdx + itemsPerPage - 1)
            for i = startIdx, stopIdx do
                local info = UIDropDownMenu_CreateInfo()
                info.text = fonts[i].name
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(dd, fonts[i].path)
                    UIDropDownMenu_SetText(dd, fonts[i].name)
                    SetSelected(fonts[i].path)
                end
                info.value = fonts[i].path
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        table.insert(p._updaters, function()
            local path = s.overlayFont or "Fonts\\FRIZQT__.TTF"
            local found = false
            for i, f in ipairs(fonts) do
                if f.path == path then
                    UIDropDownMenu_SetSelectedValue(dd, path)
                    UIDropDownMenu_SetText(dd, f.name)
                    found = true
                    break
                end
            end
            if not found then UIDropDownMenu_SetText(dd, "Select font") end
        end)
        p._updaters[#p._updaters]()
        y = y - 54
    end

    -- ============================================================
    --  SECTION 1: Overlay
    -- ============================================================
    SectionHdr("Overlay")
    Checkbox("Transparent background",
        "Hides the backdrop panel and border, keeping only text elements.",
        function() return s.ultraMinimal end,
        function(v) s.ultraMinimal = v end)
    Checkbox("Show title  (\"BOUNCY\" label)", nil,
        function() return s.showTitle     end,
        function(v) s.showTitle = v        end)
    Checkbox("Show \"JUMPS\" sub-label", nil,
        function() return s.showJumpsLabel end,
        function(v) s.showJumpsLabel = v   end)
    Checkbox("Show XP bar + level", nil,
        function() return s.showXPBarAndLevel ~= false end,
        function(v) s.showXPBarAndLevel = v end)
    y = y - 4

    -- ============================================================
    --  SECTION 2: Appearance
    -- ============================================================
    SectionHdr("Appearance")

    Slider("Jump counter size", 18, 40, 1,
        function() return s.overlayFontSize or 26 end,
        function(v) s.overlayFontSize = v end,
        "%.0f px")
    Checkbox("Black outline on jump counter", nil,
        function() return s.jumpTextOutline ~= false end,
        function(v) s.jumpTextOutline = v end)
    Slider("Overlay opacity", 0.2, 1.0, 0.05,
        function() return s.overlayAlpha or 0.95 end,
        function(v) s.overlayAlpha = v end,
        "%.2f")
    Slider("Overlay scale", 0.5, 2.0, 0.05,
        function() return s.overlayScale or 1.0 end,
        function(v) s.overlayScale = v end,
        "%.2fx")
    Slider("XP bar vertical offset", -20, 150, 1,
        function() return s.xpBarOffsetY or 0 end,
        function(v) s.xpBarOffsetY = v end,
        "%.0f px")
    y = y - 4

    FontPicker("Font")
    y = y - 4

    ColorPalette("Jump counter color",
        function() return s.jumpTextColor or {r=1,g=1,b=1} end,
        function(v) s.jumpTextColor = v end)

    -- ============================================================
    --  SECTION 3: Animations
    -- ============================================================
    SectionHdr("Animations")

    Checkbox("Show +Exp animation", nil,
        function() return s.showPlusOne    end,
        function(v) s.showPlusOne = v       end)
    Slider("+Exp text size", 10, 26, 1,
        function() return s.plusOneSize or 16 end,
        function(v) s.plusOneSize = v end,
        "%.0f px")
    y = y - 4

    -- ============================================================
    --  SECTION 4: Data
    -- ============================================================
    SectionHdr("Data")

    Checkbox("Lock overlay position", nil,
        function() return s.overlayLocked  end,
        function(v) s.overlayLocked = v     end)
    y = y - 8

    local defaultsBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    defaultsBtn:SetSize(180, 24)
    defaultsBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
    defaultsBtn:SetText("Reset to defaults")
    defaultsBtn:SetScript("OnClick", function()
        B.DB:ResetSettings()
        for _, fn in ipairs(p._updaters) do fn() end
        ApplyNow()
        print(string.format("|cffA0E4FFBouncy|r  Settings reset to defaults."))
    end)
    y = y - 32

    local resetBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    resetBtn:SetSize(180, 24)
    resetBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
    resetBtn:SetText("Reset this character")
    resetBtn:SetScript("OnClick", function()
        B.DB:ResetChar()
        if B.Overlay then B.Overlay:Refresh() end
        if B.Details and B.Details.frame:IsShown() then B.Details:Refresh() end
        print(string.format("|cffA0E4FFBouncy|r  Character data reset."))
    end)
    y = y - 30

    c:SetHeight(math.abs(y) + 20)
end
function Details:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    if activePanel == PANEL_STATS then
        self:_RefreshStats(self.panels[PANEL_STATS])
    elseif activePanel == PANEL_ZONES then
        self:_RefreshZones(self.panels[PANEL_ZONES])
    elseif activePanel == PANEL_LEADERS then
        self:_RefreshLeaders(self.panels[PANEL_LEADERS])
    -- PANEL_CUSTOM has no periodic refresh — controls update settings live via callbacks
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function Details:Show()
    self.frame:Show()
    if B.Overlay and B.Overlay.frame then B.Overlay.frame:Show() end
    self:Refresh()
end
function Details:Hide()   self.frame:Hide() end
function Details:Toggle() if self.frame then if self.frame:IsShown() then self:Hide() else self:Show() end end end

function Details:IsCustomPanelVisible()
    return self.frame and self.frame:IsShown() and activePanel == PANEL_CUSTOM
end
