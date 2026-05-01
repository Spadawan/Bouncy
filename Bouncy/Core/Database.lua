-------------------------------------------------------------------------------
-- Core/Database.lua
-- Owns all Bouncy_DB reads/writes. No other module touches Bouncy_DB directly.
-------------------------------------------------------------------------------

local B  = _G.Bouncy
B.DB     = {}
local DB = B.DB

local SCHEMA_VERSION = 1

local DEFAULTS = {
    version  = SCHEMA_VERSION,
    settings = {
        -- Overlay position & visibility
        overlayVisible   = true,
        overlayLocked    = false,
        overlayScale     = 1.0,
        overlayPoint     = { point = "CENTER", x = 0, y = 200 },
        overlayAlpha     = 0.95,
        overlayFont      = "Fonts\\FRIZQT__.TTF",
        -- Minimal mode: transparent bg/border by default; elements controlled individually
        ultraMinimal     = true,
        -- Overlay elements
        showTitle        = false,   -- "BOUNCY" label
        showJumpsLabel   = true,    -- "JUMPS" sub-label
        showXPBarAndLevel= true,    -- XP bar + level text (single toggle)
        showPlusOne      = true,    -- floating +Exp animation
        showStreak       = true,    -- streak badge
        -- Appearance
        overlayFontSize  = 26,      -- main jump counter font size (18-40)
        jumpTextColor    = { r=1.0, g=1.0, b=1.0 },  -- jump counter color
        -- Animations
        plusOneDirection = "auto",  -- "auto" | "up" | "down"
        plusOneSize      = 16,      -- font size of +Exp text (10-22)
        plusOneOffsetX   = -54,     -- +Exp anchor offset relative to jump number
        xpBarOffsetY     = 0,       -- vertical offset for XP bar
        squishEnabled    = true,    -- squish animation on jump
        -- Streak badge
        streakThreshold  = 3,       -- minimum streak to show badge (1-10)
        -- Details window
        detailsWidth     = 560,
        detailsHeight    = 500,
    },
    -- Per character jump data: [realmName-charName] = { ... }
    characters = {},
    -- Global all-time totals across all chars (for leaderboard)
    leaderboard = {},
    -- Bunny progression (shared per account or per char? → per char)
    progression = {},   -- [realmName-charName] = { xp=N, level=N }
}

local function deepMerge(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            deepMerge(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------
function DB:Init()
    if type(Bouncy_DB) ~= "table" then Bouncy_DB = {} end
    deepMerge(Bouncy_DB, DEFAULTS)
    if (Bouncy_DB.version or 0) < SCHEMA_VERSION then
        Bouncy_DB.version = SCHEMA_VERSION
    end
end

-------------------------------------------------------------------------------
-- Character key helper
-------------------------------------------------------------------------------
function DB:CharKey()
    if B._charKey then return B._charKey end
    local name  = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    B._charKey = realm .. "-" .. name
    return B._charKey
end

function DB:EnsureChar(key)
    key = key or self:CharKey()
    if not Bouncy_DB.characters[key] then
        Bouncy_DB.characters[key] = {
            name       = UnitName("player") or key,
            realm      = GetRealmName() or "Unknown",
            class      = select(2, UnitClass("player")) or "UNKNOWN",
            totalJumps = 0,
                bestStreak = 0,
            byZone     = {},   -- [zoneName] = jumpCount
            daily      = { dayStart = 0, jumps = 0 },
            weekly     = { weekStart = 0, jumps = 0 },
        }
    end
    return Bouncy_DB.characters[key]
end

-------------------------------------------------------------------------------
-- Record a jump
-------------------------------------------------------------------------------
function DB:RecordJump(zoneName)
    local key  = self:CharKey()
    local char = self:EnsureChar(key)
    char.totalJumps = char.totalJumps + 1

    -- By zone
    zoneName = zoneName or "Unknown"
    char.byZone[zoneName] = (char.byZone[zoneName] or 0) + 1

    -- Daily / weekly resets
    local now = GetServerTime()
    local dayStart = now - (now % 86400)
    if char.daily.dayStart ~= dayStart then
        char.daily = { dayStart = dayStart, jumps = 0 }
    end
    char.daily.jumps = char.daily.jumps + 1

    local wday = tonumber(date("%w", now))
    local weekStart = dayStart - (((wday == 0) and 6 or (wday - 1)) * 86400)
    if char.weekly.weekStart ~= weekStart then
        char.weekly = { weekStart = weekStart, jumps = 0 }
    end
    char.weekly.jumps = char.weekly.jumps + 1

    -- Leaderboard
    if not Bouncy_DB.leaderboard[key] then
        Bouncy_DB.leaderboard[key] = { name = char.name, realm = char.realm, class = char.class, jumps = 0 }
    end
    Bouncy_DB.leaderboard[key].jumps = char.totalJumps
end

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Record best streak
-------------------------------------------------------------------------------
function DB:RecordStreak(n)
    local char = self:EnsureChar()
    if n > (char.bestStreak or 0) then
        char.bestStreak = n
    end
end

-------------------------------------------------------------------------------
-- Getters
-------------------------------------------------------------------------------
function DB:GetChar(key)
    return Bouncy_DB.characters[key or self:CharKey()]
end

function DB:GetAllChars()
    return Bouncy_DB.characters
end

function DB:GetLeaderboard()
    return Bouncy_DB.leaderboard
end

function DB:GetSettings()
    return Bouncy_DB.settings
end

-------------------------------------------------------------------------------
-- Progression (XP / level)
-------------------------------------------------------------------------------
function DB:GetProgression()
    local key = self:CharKey()
    if not Bouncy_DB.progression[key] then
        Bouncy_DB.progression[key] = { xp = 0, level = 1 }
    end
    return Bouncy_DB.progression[key]
end

function DB:AddXP(amount)
    local prog = self:GetProgression()
    prog.xp = prog.xp + amount
    return prog
end

-------------------------------------------------------------------------------
-- Save overlay position
-------------------------------------------------------------------------------
function DB:SaveOverlayPosition(point, x, y)
    local s = Bouncy_DB.settings
    s.overlayPoint = { point = point, x = x, y = y }
end

-------------------------------------------------------------------------------
-- Reset helpers
-------------------------------------------------------------------------------
function DB:ResetSettings()
    local s = Bouncy_DB.settings
    local pos = s.overlayPoint
    for k in pairs(s) do s[k] = nil end
    deepMerge(s, DEFAULTS.settings)
    s.overlayPoint = pos
end

function DB:ResetChar()
    local key = self:CharKey()
    Bouncy_DB.characters[key] = nil
    Bouncy_DB.progression[key] = nil
    self:EnsureChar(key)
end
