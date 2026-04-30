-------------------------------------------------------------------------------
-- UI/Overlay.lua
-- Minimal draggable overlay. Respects all customization settings.
-- Ultra Minimal mode: transparent bg, no border, no title, no XP bar.
-------------------------------------------------------------------------------

local B       = _G.Bouncy
B.Overlay     = {}
local Overlay = B.Overlay

local OW, OH = 150, 64
local BG_R, BG_G, BG_B, BG_A = 0.04, 0.04, 0.10, 0.92

local function MakeFont(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "OUTLINE")
    return fs
end

-------------------------------------------------------------------------------
-- Squish animation
-------------------------------------------------------------------------------
local function AnimSquish(frame)
    if not frame._squishAG then
        local ag = frame:CreateAnimationGroup()
        local s1 = ag:CreateAnimation("Scale")
        s1:SetOrigin("BOTTOM",0,0); s1:SetScale(1,0.76); s1:SetDuration(0.06); s1:SetOrder(1)
        local s2 = ag:CreateAnimation("Scale")
        s2:SetOrigin("BOTTOM",0,0); s2:SetScale(1,1.14); s2:SetDuration(0.07); s2:SetOrder(2)
        local s3 = ag:CreateAnimation("Scale")
        s3:SetOrigin("BOTTOM",0,0); s3:SetScale(1,1.0);  s3:SetDuration(0.06); s3:SetOrder(3)
        frame._squishAG = ag
    end
    if frame._squishAG:IsPlaying() then frame._squishAG:Stop() end
    frame._squishAG:Play()
end

-------------------------------------------------------------------------------
-- +1 floating text — ease-out rise + fade
-------------------------------------------------------------------------------
local plusPool = {}

local function SpawnPlusOne(anchorFrame, label, hexColor, goUp, fontSize)
    local p
    for _, f in ipairs(plusPool) do
        if not f:IsShown() then p = f; break end
    end
    if not p then
        p = CreateFrame("Frame", nil, UIParent)
        p:SetSize(110, 24)
        p:SetFrameStrata("TOOLTIP")
        local fs = p:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints()
        p.fs = fs
        table.insert(plusPool, p)
    end

    local cx, cy = anchorFrame:GetCenter()
    if not cx then return end

    p.fs:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 13, "OUTLINE")
    p.fs:SetText(string.format("|cff%s%s|r", hexColor or "FFFFFF", label))
    p:ClearAllPoints()
    p:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    p:SetAlpha(1); p:SetScale(1); p:Show()

    local startY = cy
    local dir    = goUp and 1 or -1
    local elapsed = 0
    local RISE, DUR = 55, 1.3

    p:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = elapsed / DUR
        if t >= 1.0 then self:Hide(); self:SetScript("OnUpdate", nil); return end
        local ease = 1 - (1 - t)^3
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, startY + dir * RISE * ease)
        self:SetAlpha(t < 0.5 and 1.0 or (1.0 - (t - 0.5) / 0.5))
    end)
end

-------------------------------------------------------------------------------
-- Streak badge — alpha pulse, GameFontNormalSmall
-------------------------------------------------------------------------------
local STREAK_TIERS = {
    { min=10, r=0.90, g=0.38, b=0.02 },
    { min=6,  r=0.75, g=0.52, b=0.02 },
    { min=3,  r=0.14, g=0.48, b=0.18 },
}

local function CreateStreakBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(52, 16)
    badge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    badge.bg = bg

    local fs = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER"); fs:SetJustifyH("CENTER")
    badge.fs = fs
    badge:Hide()

    local ag = badge:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1.0); a:SetToAlpha(0.65); a:SetDuration(0.45)
    a:SetSmoothing("IN_OUT")
    badge._pulseAG = ag

    function badge:SetStreak(n, threshold)
        threshold = threshold or 3
        if n < threshold then
            self:Hide()
            if self._pulseAG:IsPlaying() then self._pulseAG:Stop() end
            return
        end
        local r, g, b = 0.14, 0.48, 0.18
        for _, tier in ipairs(STREAK_TIERS) do
            if n >= tier.min then r,g,b = tier.r, tier.g, tier.b; break end
        end
        self.bg:SetColorTexture(r, g, b, 0.82)
        local mult = n >= 10 and "x3" or (n >= 6 and "x2" or "x1.5")
        self.fs:SetText(n .. " " .. mult)
        self.fs:SetTextColor(1, 1, 1)
        self:Show()
        if not self._pulseAG:IsPlaying() then self._pulseAG:Play() end
    end
    return badge
end

-------------------------------------------------------------------------------
-- XP bar
-------------------------------------------------------------------------------
local function CreateXPBar(parent, w)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(w - 12, 4)
    bar:SetPoint("BOTTOM", parent, "BOTTOM", 0, 4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.32, 0.80, 0.32)
    bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.07,0.07,0.07,0.80)
    function bar:Flash()
        self:SetStatusBarColor(1.0, 1.0, 0.35)
        C_Timer.After(0.18, function() self:SetStatusBarColor(0.32,0.80,0.32) end)
    end
    return bar
end

-------------------------------------------------------------------------------
-- Apply visual settings to the overlay (called on init + whenever settings change)
-------------------------------------------------------------------------------
function Overlay:ApplySettings()
    if not self.frame then return end
    local s = B.DB:GetSettings()
    local f = self.frame

    if s.ultraMinimal then
        -- Transparent: no backdrop bg, no border
        f:SetBackdropColor(0, 0, 0, 0)
        f:SetBackdropBorderColor(0, 0, 0, 0)
        self.titleText:Hide()
        self.jumpLbl:Hide()
        self.lvlText:Hide()
        self.xpBar:Hide()
    else
        f:SetBackdropColor(BG_R, BG_G, BG_B, BG_A)
        f:SetBackdropBorderColor(0.30, 0.55, 1.0, 0.55)
        self.titleText:SetShown(s.showTitle)
        self.jumpLbl:SetShown(s.showJumpsLabel)
        self.lvlText:SetShown(s.showLevel)
        self.xpBar:SetShown(s.showXPBar)
    end

    -- Jump counter font size + color
    local fontSize = s.overlayFontSize or 26
    self.jumpNum:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    local tc = s.jumpTextColor or { r=1, g=1, b=1 }
    self.jumpNum:SetTextColor(tc.r, tc.g, tc.b)

    -- Overlay scale
    f:SetScale(s.overlayScale or 1.0)
    -- Overlay alpha
    f:SetAlpha(s.overlayAlpha or 0.95)
end

-------------------------------------------------------------------------------
-- Build
-------------------------------------------------------------------------------
function Overlay:Init()
    local settings = B.DB:GetSettings()

    local f = CreateFrame("Frame", "Bouncy_Overlay", UIParent, "BackdropTemplate")
    f:SetSize(OW, OH)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left=3, right=3, top=3, bottom=3 },
    })

    local op = settings.overlayPoint
    f:ClearAllPoints()
    f:SetPoint(op.point or "CENTER", UIParent, op.point or "CENTER", op.x or 0, op.y or 200)

    -- Title
    local titleText = MakeFont(f, 8, "OUTLINE")
    titleText:SetPoint("TOP", f, "TOP", 0, -4)
    titleText:SetTextColor(0.63, 0.89, 1.0)
    titleText:SetText("BOUNCY")

    -- Big counter
    local jumpNum = MakeFont(f, settings.overlayFontSize or 26, "OUTLINE")
    jumpNum:SetPoint("CENTER", f, "CENTER", 0, 4)

    -- "JUMPS" sub-label
    local jumpLbl = MakeFont(f, 7, "")
    jumpLbl:SetPoint("TOP", jumpNum, "BOTTOM", 0, 2)
    jumpLbl:SetTextColor(0.45,0.45,0.45)
    jumpLbl:SetText("JUMPS")

    -- Level
    local lvlText = MakeFont(f, 9, "OUTLINE")
    lvlText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 9)
    lvlText:SetTextColor(1.0, 0.85, 0.0)

    -- Streak badge
    local badge = CreateStreakBadge(f)

    -- XP bar
    local xpBar = CreateXPBar(f, OW)

    self.frame     = f
    self.titleText = titleText
    self.jumpNum   = jumpNum
    self.jumpLbl   = jumpLbl
    self.lvlText   = lvlText
    self.badge     = badge
    self.xpBar     = xpBar

    -- Drag
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not B.DB:GetSettings().overlayLocked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point,_,_,x,y = self:GetPoint()
        B.DB:SaveOverlayPosition(point, x, y)
    end)
    f:SetScript("OnEnter", function(self)
        UIFrameFadeIn(self, 0.15, self:GetAlpha(), 1.0)
    end)
    f:SetScript("OnLeave", function(self)
        local s = B.DB:GetSettings()
        UIFrameFadeOut(self, 0.30, self:GetAlpha(), s.overlayAlpha)
    end)
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "RightButton" then B.Details:Toggle() end
    end)

    -- Apply all visual settings
    self:ApplySettings()
    self:Refresh()

    if settings.overlayVisible then f:Show() else f:Hide() end

    B.Tracker:RegisterCallback(function(event, data)
        if event == "JUMP"               then self:OnJump(data)
        elseif event == "STREAK_BREAK"   then self:OnStreakBreak()
        elseif event == "OVERLAY_REFRESH" then self:Refresh()
        end
    end)
    B.Leveling:RegisterLevelUpCallback(function(lvlData)
        self:OnLevelUp(lvlData)
    end)
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
function Overlay:Refresh()
    local char = B.DB:GetChar()
    if not char then return end
    local prog = B.DB:GetProgression()
    local s    = B.DB:GetSettings()

    self.jumpNum:SetText(B.FormatNum(char.totalJumps))

    local lvlData = B.Leveling:GetLevelForXP(prog.xp)
    self.lvlText:SetText("Lv." .. lvlData.level)

    self.xpBar:SetValue((B.Leveling:GetProgress(prog.xp)))
    self.badge:SetStreak(B.Tracker:GetStreak(), s.streakThreshold)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
function Overlay:OnJump(data)
    local s = B.DB:GetSettings()

    if s.squishEnabled ~= false then
        AnimSquish(self.frame)
    end

    if s.showPlusOne then
        local _, screenH = UIParent:GetSize()
        local _, oy = self.frame:GetCenter()
        local goUp
        if s.plusOneDirection == "up" then
            goUp = true
        elseif s.plusOneDirection == "down" then
            goUp = false
        else
            goUp = (oy or 0) < (screenH / 2)
        end

        local label = data.mult > 1
            and string.format("+%d (x%.1f)", data.xpGained, data.mult)
            or  string.format("+%d", data.xpGained)
        local col = data.mult > 1 and "FFD700" or "FFFFFF"
        SpawnPlusOne(self.frame, label, col, goUp, s.plusOneSize or 13)
    end

    if s.showStreak then
        self.badge:SetStreak(data.streak, s.streakThreshold)
    end

    if s.showXPBar and not s.ultraMinimal then
        self.xpBar:Flash()
    end

    self:Refresh()

    if data.newTitle then self:OnTitleUnlock(data.newTitle) end

    if s.soundOnStreak and data.streak == 10 then PlaySound(5274) end
end

function Overlay:OnStreakBreak()
    local s = B.DB:GetSettings()
    self.badge:SetStreak(0, s.streakThreshold)
    self:Refresh()
end

function Overlay:OnLevelUp(lvlData)
    if not B.DB:GetSettings().ultraMinimal then
        self.frame:SetBackdropBorderColor(1.0, 0.85, 0.0, 1.0)
        C_Timer.After(1.0, function()
            self.frame:SetBackdropBorderColor(0.30, 0.55, 1.0, 0.55)
        end)
    end
    print(string.format("|cffA0E4FFBouncy|r  Your bunny evolved! |cffFFD700Level %d - %s|r",
        lvlData.level, lvlData.name))
    self:Refresh()
end

function Overlay:OnTitleUnlock(titleData)
    print(string.format("|cffA0E4FFBouncy|r  New title unlocked: |cff%s%s|r",
        titleData.color, titleData.title))
    if not B.DB:GetSettings().ultraMinimal then
        self.frame:SetBackdropBorderColor(0.6, 1.0, 1.0, 1.0)
        C_Timer.After(0.7, function()
            self.frame:SetBackdropBorderColor(0.30, 0.55, 1.0, 0.55)
        end)
    end
end

function Overlay:Show()   self.frame:Show(); B.DB:GetSettings().overlayVisible = true  end
function Overlay:Hide()   self.frame:Hide(); B.DB:GetSettings().overlayVisible = false end
function Overlay:Toggle() if self.frame:IsShown() then self:Hide() else self:Show() end end
