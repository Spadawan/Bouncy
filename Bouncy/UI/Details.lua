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

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function MakeFont(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "OUTLINE")
    return fs
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

    local streakLabel = MakeFont(p, 11, "OUTLINE")
    streakLabel:SetPoint("TOPLEFT", xpLabel, "BOTTOMLEFT", 0, -8)
    p.streakLabel = streakLabel

    -- Next title goal
    local nextTitleLabel = MakeFont(p, 10, "")
    nextTitleLabel:SetPoint("TOPLEFT", streakLabel, "BOTTOMLEFT", 0, -8)
    p.nextTitleLabel = nextTitleLabel

    HSep(p, -152)

    local statY = -164
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

    p._r = { r1, r2, r3 }
end

function Details:_RefreshStats(p)
    local char = B.DB:GetChar()
    if not char then return end
    local prog = B.DB:GetProgression()

    local lvlData = B.Leveling:GetLevelForXP(prog.xp)
    local frac    = B.Leveling:GetProgress(prog.xp)
    p.artwork:SetTexture(lvlData.artwork)
    p.lvlName:SetText(string.format("|cff%sLevel %d|r  %s",
        B.COLOR.LEVEL_UP, lvlData.level, lvlData.name))
    p.xpBar:SetValue(frac)
    p.xpLabel:SetText(B.Leveling:FormatXP(prog.xp))
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

    local r = p._r
    r[1]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.totalJumps)))
    r[2]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.daily.jumps or 0)))
    r[3]:SetText(string.format("|cff%s%s|r", B.COLOR.JUMP, B.FormatNum(char.weekly.jumps or 0)))
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
        activeCharKey = keys[1]
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
            btn._fs:SetText(string.format("|cff%s%s|r\n|cff%s%s jumps|r",
                "AADDFF", char.name or key,
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
                                 class=data.class, jumps=data.jumps or 0 })
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

            local bar = row:CreateTexture(nil,"ARTWORK")
            bar:SetHeight(3)
            bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 50, 4)

            table.insert(p._leaderWidgets, {
                row=row, nameFS=nameFS, realmFS=realmFS, jumpFS=jumpFS, bar=bar
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
            w.nameFS:SetText(string.format("|cff%s%s|r",
                isSelf and "AADDFF" or "CCCCCC", entry.name or "?"))
            w.realmFS:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, entry.realm or ""))
            w.jumpFS:SetText(string.format("|cff%s%s|r  |cff%sjumps|r",
                B.COLOR.JUMP, B.FormatNum(entry.jumps), B.COLOR.DIM))
            local barW = math.max(4, math.floor((entry.jumps / maxJ) * 280))
            w.bar:SetWidth(barW)
            w.bar:SetColorTexture(isSelf and 0.4 or 0.25, isSelf and 0.85 or 0.5,
                                   isSelf and 1.0 or 0.7, 0.8)
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
function Details:_BuildCustomPanel(p)
    local s = B.DB:GetSettings()
    local sf, c = CreateScrollPanel(p, DW - 16, 420)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    c:SetHeight(600)

    p._updaters = {}
    local y = -8

    -- Helper: section header
    local function SectionHdr(label)
        local sep = c:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y - 16)
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
            if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
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
            -- snap to step
            val = math.floor(val / step + 0.5) * step
            if sl.Text then sl.Text:SetText(string.format(fmt, val)) end
            setter(val)
            if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
        end)
        table.insert(p._updaters, function() sl:SetValue(getter()) end)
        y = y - 42
        return sl
    end

    -- Helper: color swatch row (R/G/B sliders)
    local function ColorPicker(label, getter, setter)
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))
        local swatch = c:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
        local col = getter()
        swatch:SetColorTexture(col.r, col.g, col.b, 1.0)
        swatch._col = col

        local function UpdateSwatch()
            local co = getter()
            swatch:SetColorTexture(co.r, co.g, co.b, 1.0)
        end

        y = y - 18
        -- R slider
        local function makeChannel(ch, chLabel, startY)
            local cLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 20, startY)
            cLbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, chLabel))
            local sl = CreateFrame("Slider", nil, c, "OptionsSliderTemplate")
            sl:SetPoint("TOPLEFT", c, "TOPLEFT", 50, startY - 12)
            sl:SetWidth(DW - 130)
            sl:SetMinMaxValues(0, 1); sl:SetValueStep(0.05)
            sl:SetValue(getter()[ch])
            if sl.Low  then sl.Low:SetText("0")  end
            if sl.High then sl.High:SetText("1") end
            if sl.Text then sl.Text:SetText(string.format("%.2f", getter()[ch])) end
            sl:SetScript("OnValueChanged", function(self, val)
                val = math.floor(val/0.05+0.5)*0.05
                local co = getter(); co[ch] = val; setter(co)
                if sl.Text then sl.Text:SetText(string.format("%.2f", val)) end
                UpdateSwatch()
                if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
            end)
            table.insert(p._updaters, function() sl:SetValue(getter()[ch]) end)
            return sl
        end
        makeChannel("r", "R", y);       y = y - 30
        makeChannel("g", "G", y);       y = y - 30
        makeChannel("b", "B", y);       y = y - 14
    end

    -- Helper: dropdown (simple button cycle)
    local function Dropdown(label, options, getter, setter)
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
        lbl:SetText(string.format("|cff%s%s|r", B.COLOR.DIM, label))

        local btn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("LEFT", lbl, "RIGHT", 10, 0)

        local function UpdateBtn()
            btn:SetText(getter())
        end
        UpdateBtn()

        btn:SetScript("OnClick", function()
            local cur = getter()
            local nextOpt = options[1]
            for i, opt in ipairs(options) do
                if opt == cur then nextOpt = options[(i % #options) + 1]; break end
            end
            setter(nextOpt)
            UpdateBtn()
            if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
        end)
        table.insert(p._updaters, function() UpdateBtn() end)
        y = y - 28
    end

    -- ============================================================
    --  SECTION 1: Ultra Minimal
    -- ============================================================
    SectionHdr("Ultra Minimal Mode")
    local umCB = Checkbox(
        "Ultra Minimal  (transparent bg, no title, no XP bar, no level)",
        "Hides the overlay background, border, title, XP bar and level label.\nKeeps the jump counter, streak badge and +1 animation.",
        function() return s.ultraMinimal end,
        function(v) s.ultraMinimal = v end)
    y = y - 4

    -- ============================================================
    --  SECTION 2: Overlay elements
    -- ============================================================
    SectionHdr("Overlay Elements")
    Checkbox("Show title  (\"BOUNCY\" label)",        nil,
        function() return s.showTitle     end,
        function(v) s.showTitle = v        end)
    Checkbox("Show \"JUMPS\" sub-label",               nil,
        function() return s.showJumpsLabel end,
        function(v) s.showJumpsLabel = v   end)
    Checkbox("Show level  (Lv.X)",                   nil,
        function() return s.showLevel      end,
        function(v) s.showLevel = v         end)
    Checkbox("Show XP bar",                          nil,
        function() return s.showXPBar      end,
        function(v) s.showXPBar = v         end)
    Checkbox("Show streak badge",                    nil,
        function() return s.showStreak     end,
        function(v) s.showStreak = v        end)
    y = y - 4

    -- ============================================================
    --  SECTION 3: Appearance
    -- ============================================================
    SectionHdr("Appearance")

    Slider("Jump counter size", 18, 40, 1,
        function() return s.overlayFontSize or 26 end,
        function(v) s.overlayFontSize = v end,
        "%.0f px")

    Slider("Overlay opacity", 0.2, 1.0, 0.05,
        function() return s.overlayAlpha or 0.95 end,
        function(v) s.overlayAlpha = v end,
        "%.0f%%")  -- we'll format as percent below

    Slider("Overlay scale", 0.5, 2.0, 0.05,
        function() return s.overlayScale or 1.0 end,
        function(v) s.overlayScale = v end,
        "%.2fx")

    ColorPicker("Jump counter color",
        function() return s.jumpTextColor or {r=1,g=1,b=1} end,
        function(v) s.jumpTextColor = v end)

    -- ============================================================
    --  SECTION 4: Animations
    -- ============================================================
    SectionHdr("Animations")

    Checkbox("Squish animation on jump",             nil,
        function() return s.squishEnabled ~= false end,
        function(v) s.squishEnabled = v end)
    Checkbox("Show +1 animation",                    nil,
        function() return s.showPlusOne    end,
        function(v) s.showPlusOne = v       end)

    Slider("+1 text size", 10, 22, 1,
        function() return s.plusOneSize or 13 end,
        function(v) s.plusOneSize = v end,
        "%.0f px")

    Dropdown("+1 direction", { "auto", "up", "down" },
        function() return s.plusOneDirection or "auto" end,
        function(v) s.plusOneDirection = v end)
    y = y - 4

    -- ============================================================
    --  SECTION 5: Streak
    -- ============================================================
    SectionHdr("Streak")

    Slider("Streak badge threshold", 1, 10, 1,
        function() return s.streakThreshold or 3 end,
        function(v) s.streakThreshold = v end,
        "%.0f jumps")
    y = y - 4

    -- ============================================================
    --  SECTION 6: Data
    -- ============================================================
    SectionHdr("Data")

    local lockCB = Checkbox("Lock overlay position",  nil,
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
        if B.Overlay then B.Overlay:ApplySettings(); B.Overlay:Refresh() end
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
    self:Refresh()
end
function Details:Hide()   self.frame:Hide() end
function Details:Toggle() if self.frame:IsShown() then self:Hide() else self:Show() end end
