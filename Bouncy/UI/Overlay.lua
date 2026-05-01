-------------------------------------------------------------------------------
-- UI/Overlay.lua
-- Minimal draggable overlay. Respects all customization settings.
-------------------------------------------------------------------------------

local B       = _G.Bouncy
B.Overlay     = {}
local Overlay = B.Overlay

local OW, OH = 150, 68
local BG_R, BG_G, BG_B, BG_A = 0.04, 0.04, 0.10, 0.92

local function GetFontPath()
    if B.DB then
        local s = B.DB:GetSettings()
        if s and s.overlayFont then return s.overlayFont end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function MakeFont(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GetFontPath(), size, flags or "OUTLINE")
    return fs
end

-------------------------------------------------------------------------------
-- Squish animation — applied to the jumpNumFrame wrapper
-------------------------------------------------------------------------------
local function AnimSquish(target)
    if not target._squishAG then
        local ag = target:CreateAnimationGroup()
        local s1 = ag:CreateAnimation("Scale")
        s1:SetOrigin("CENTER",0,0); s1:SetScale(1,0.76); s1:SetDuration(0.06); s1:SetOrder(1)
        local s2 = ag:CreateAnimation("Scale")
        s2:SetOrigin("CENTER",0,0); s2:SetScale(1,1.14); s2:SetDuration(0.07); s2:SetOrder(2)
        local s3 = ag:CreateAnimation("Scale")
        s3:SetOrigin("CENTER",0,0); s3:SetScale(1,1.0);  s3:SetDuration(0.06); s3:SetOrder(3)
        target._squishAG = ag
    end
    if target._squishAG:IsPlaying() then target._squishAG:Stop() end
    target._squishAG:Play()
end

-------------------------------------------------------------------------------
-- Floating text pool
-- isCombo=true  → diagonal up-right, scale punch, gold text
-- isCombo=false → straight rise, plain text
-------------------------------------------------------------------------------
local plusPool = {}

local function SpawnFloating(anchorFrame, label, hexColor, fontSize, isCombo, offsetX, offsetY, goDown)
    local p
    for _, f in ipairs(plusPool) do
        if not f:IsShown() then p = f; break end
    end
    if not p then
        p = CreateFrame("Frame", nil, UIParent)
        p:SetSize(200, 32)
        p:SetFrameStrata("TOOLTIP")
        local fs = p:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints()
        fs:SetWordWrap(false)
        fs:SetJustifyH("CENTER")
        p.fs = fs
        table.insert(plusPool, p)
    end

    p.fs:SetFont(GetFontPath(), fontSize or 16, "THICKOUTLINE")
    p.fs:SetText(string.format("|cff%s%s|r", hexColor or "FFFFFF", label))
    local baseX, baseY = (offsetX or 0), (offsetY or 0)
    p:ClearAllPoints()
    p:SetPoint("CENTER", anchorFrame, "CENTER", baseX, baseY)
    p:SetAlpha(1)
    p:SetScale(isCombo and 0.75 or 1.0)
    p:Show()

    local elapsed = 0
    local sign = goDown and -1 or 1
    local DX  = isCombo and -32 or -8
    local DY  = sign * (isCombo and 21 or 27.5)
    local DUR = isCombo and 1.5 or 1.3

    p:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = elapsed / DUR
        if t >= 1.0 then
            self:SetScale(1.0)
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        local ease = 1 - (1 - t)^3

        -- scale punch for combos: 0.75 → 1.3 → 1.0
        local sc = 1.0
        if isCombo then
            if t < 0.12 then
                sc = 0.75 + 0.55 * (t / 0.12)
            elseif t < 0.28 then
                sc = 1.30 - 0.30 * ((t - 0.12) / 0.16)
            end
        end
        self:SetScale(sc)

        self:ClearAllPoints()
        self:SetPoint("CENTER", anchorFrame, "CENTER", baseX + DX * ease, baseY + DY * ease)
        self:SetAlpha(t < 0.5 and 1.0 or (1.0 - (t - 0.5) / 0.5))
    end)
end

-------------------------------------------------------------------------------
-- Streak badge — colored text with THICKOUTLINE, no background fill
-------------------------------------------------------------------------------
local STREAK_TIERS = {
    { min=10, hex="FF6600", mult="x3"   },
    { min=6,  hex="FFCC00", mult="x2"   },
    { min=3,  hex="00FF88", mult="x1.5" },
}

local function CreateStreakBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(62, 18)
    badge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

    local fs = badge:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "THICKOUTLINE")
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
        local hex, mult = "00FF88", "x1.5"
        for _, tier in ipairs(STREAK_TIERS) do
            if n >= tier.min then hex, mult = tier.hex, tier.mult; break end
        end
        self.fs:SetText(string.format("|cff%s%d %s|r", hex, n, mult))
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
    bar:SetSize((w - 12) * 0.70, 6)
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
-- Apply visual settings
-------------------------------------------------------------------------------
function Overlay:ApplySettings()
    if not self.frame then return end
    local s = B.DB:GetSettings()
    local f = self.frame

    -- ultraMinimal controls only bg + border
    if s.ultraMinimal then
        f:SetBackdropColor(0, 0, 0, 0)
        f:SetBackdropBorderColor(0, 0, 0, 0)
    else
        f:SetBackdropColor(BG_R, BG_G, BG_B, BG_A)
        f:SetBackdropBorderColor(0.30, 0.55, 1.0, 0.55)
    end

    -- All elements controlled individually regardless of ultraMinimal
    self.titleText:SetShown(s.showTitle)
    self.jumpLbl:SetShown(s.showJumpsLabel)
    local showXPAndLevel = (s.showXPBarAndLevel ~= false)
    self.lvlText:SetShown(showXPAndLevel)
    self.xpBar:SetShown(showXPAndLevel)
    local yOffset = s.xpBarOffsetY or 0
    self.xpBar:ClearAllPoints()
    self.xpBar:SetPoint("BOTTOM", f, "BOTTOM", 0, 4 + yOffset)
    self.lvlText:ClearAllPoints()
    self.lvlText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 9 + yOffset)

    -- Jump counter font, size + color
    local fontSize = s.overlayFontSize or 26
    local fontPath = s.overlayFont or "Fonts\\FRIZQT__.TTF"
    local jumpFlags = s.jumpTextOutline and "OUTLINE" or ""
    self.jumpNum:SetFont(fontPath, fontSize, jumpFlags)
    self.titleText:SetFont(fontPath, 8, "OUTLINE")
    self.jumpLbl:SetFont(fontPath, 7, "")
    self.lvlText:SetFont(fontPath, 9, "OUTLINE")
    local tc = s.jumpTextColor or { r=1, g=1, b=1 }
    self.jumpNum:SetTextColor(tc.r, tc.g, tc.b)

    -- Overlay scale + alpha
    f:SetScale(s.overlayScale or 1.0)
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

    -- Wrapper frame — squish target for the jump counter area
    local jumpNumFrame = CreateFrame("Frame", nil, f)
    jumpNumFrame:SetSize(OW, 46)
    jumpNumFrame:SetPoint("CENTER", f, "CENTER", 0, 2)

    -- Big counter (child of jumpNumFrame so squish applies to it)
    local jumpNum = MakeFont(jumpNumFrame, settings.overlayFontSize or 26, "OUTLINE")
    jumpNum:SetPoint("CENTER", jumpNumFrame, "CENTER", 0, 8)

    -- "JUMPS" sub-label (also in jumpNumFrame)
    local jumpLbl = MakeFont(jumpNumFrame, 7, "")
    jumpLbl:SetPoint("TOP", jumpNum, "BOTTOM", 0, 1)
    jumpLbl:SetTextColor(0.45, 0.45, 0.45)
    jumpLbl:SetText("JUMPS")

    -- Level
    local lvlText = MakeFont(f, 9, "OUTLINE")
    lvlText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 9)
    lvlText:SetTextColor(1.0, 0.85, 0.0)

    -- Streak badge
    local badge = CreateStreakBadge(f)

    -- XP bar
    local xpBar = CreateXPBar(f, OW)

    self.frame        = f
    self.jumpNumFrame = jumpNumFrame
    self.titleText    = titleText
    self.jumpNum      = jumpNum
    self.jumpLbl      = jumpLbl
    self.lvlText      = lvlText
    self.badge        = badge
    self.xpBar        = xpBar

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
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "RightButton" then B.Details:Toggle() end
    end)

    self:ApplySettings()
    self:Refresh()

    f:Hide()  -- auto-shows on each jump, hides after

    B.Tracker:RegisterCallback(function(event, data)
        if event == "JUMP"                then self:OnJump(data)
        elseif event == "STREAK_BREAK"    then self:OnStreakBreak()
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
    self.badge:Hide()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local OVERLAY_SHOW_DUR = 4.0   -- seconds overlay stays visible after a jump
local OVERLAY_FADE_DUR = 1.2   -- seconds for fade-out

function Overlay:OnJump(data)
    local s = B.DB:GetSettings()

    -- Auto-show overlay, restart hide timer
    if s.overlayVisible then
        local targetAlpha = s.overlayAlpha or 0.95
        if self._fadeTimer then self._fadeTimer:Cancel(); self._fadeTimer = nil end
        UIFrameFadeRemoveFrame(self.frame)
        self.frame:Show()
        self.frame:SetAlpha(targetAlpha)
        self._timerToken = (self._timerToken or 0) + 1
        local token = self._timerToken
        if self._hideTimer then self._hideTimer:Cancel() end
        self._hideTimer = C_Timer.After(OVERLAY_SHOW_DUR, function()
            if token ~= self._timerToken then return end
            if B.Details and B.Details:IsCustomPanelVisible() then
                self._hideTimer = nil
                return
            end
            UIFrameFadeOut(self.frame, OVERLAY_FADE_DUR, self.frame:GetAlpha(), 0)
            self._fadeTimer = C_Timer.After(OVERLAY_FADE_DUR, function()
                if token ~= self._timerToken then return end
                self.frame:Hide()
                self.frame:SetAlpha(targetAlpha)
                self._hideTimer = nil
                self._fadeTimer = nil
            end)
        end)
    end

    -- Squish animation disabled (unreliable on some clients/fontstrings)

    if s.showPlusOne then
        local isCombo = data.mult > 1
        local label = isCombo
            and string.format("+%d Exp (x%.1f)", data.xpGained, data.mult)
            or  string.format("+%d Exp", data.xpGained)
        local col = isCombo and "FFD700" or "FFFFFF"
        local _, fy = self.frame:GetCenter()
        local goDown = fy and fy > (UIParent:GetHeight() * 0.55)
        SpawnFloating(self.jumpNum, label, col, s.plusOneSize or 16, isCombo, s.plusOneOffsetX or -54, 2, goDown)
    end

    self.badge:Hide()

    if s.showXPBarAndLevel ~= false then
        self.xpBar:Flash()
    end

    self:Refresh()

    if data.newTitle then self:OnTitleUnlock(data.newTitle) end
end

function Overlay:OnStreakBreak()
    self.badge:Hide()
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
