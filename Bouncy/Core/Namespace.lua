-------------------------------------------------------------------------------
-- Core/Namespace.lua
-- Global namespace, constants, level definitions, titles.
-- Must load first.
-------------------------------------------------------------------------------

local B = {}
_G.Bouncy = B

B.ADDON_NAME = "Bouncy"
B.VERSION    = "1.0.0"

B.CREATURE_TYPES = {
    "Astral",
    "Fire",
    "Water",
    "Lunar",
}

local function BuildCreatureLevelSet(prefix)
    local out = {}
    for i = 1, 6 do
        out[i] = {
            level = i,
            name = string.format("%s Evolution %d", prefix, i),
            threshold = B.LEVELS and B.LEVELS[i] and B.LEVELS[i].threshold or 0,
            artwork = string.format("Interface\\AddOns\\Bouncy\\media\\%s_%02d.tga", prefix, i),
        }
    end
    return out
end

-------------------------------------------------------------------------------
-- Bunny evolution stages (XP-based)
-- artwork = placeholder — replace with your own TGA/BLP per level
-------------------------------------------------------------------------------
local PLAYER_TITLE_BY_MILESTONE = {
    [1]="First Hop",[5]="Light Feet",[10]="Springstep",[15]="Airborne",[20]="High Hopper",
    [25]="Bound Runner",[30]="Leap Adept",[35]="Momentum Keeper",[40]="Sky Strider",
    [45]="Vault Expert",[50]="Jump Veteran",[55]="Arc Master",[60]="Drift Walker",
    [65]="Elevation Knight",[70]="Gravity Challenger",[75]="Cloud Chaser",[80]="Horizon Leaper",
    [85]="Void Jumper",[90]="Apex Bounder",[95]="Zenith Strider",[100]="Lord of the Leap",
}

local function BuildPlayerLevels()
    local out = {}
    local threshold = 0
    local title = PLAYER_TITLE_BY_MILESTONE[1]
    for lvl = 1, 100 do
        if PLAYER_TITLE_BY_MILESTONE[lvl] then title = PLAYER_TITLE_BY_MILESTONE[lvl] end
        local artIdx = math.min(8, math.max(1, math.floor((lvl - 1) / 12) + 1))
        out[#out + 1] = {
            level = lvl,
            name = title,
            threshold = threshold,
            artwork = string.format("Interface\\AddOns\\Bouncy\\media\\bunny%d.tga", artIdx),
        }
        threshold = threshold + (80 + math.floor(lvl * 22))
    end
    return out
end

B.LEVELS = BuildPlayerLevels()

B.CREATURE_LEVELS = {
    Astral = BuildCreatureLevelSet("Astral"),
}

-------------------------------------------------------------------------------
-- Player titles — awarded at jump milestones (total jumps, not XP).
-- Displayed in the Stats panel and printed on unlock.
-- Inspired by WoW achievement titles but scoped to the absurdity of jumping.
-------------------------------------------------------------------------------
B.TITLES = {
    { jumps = 1,      title = "The Curious",        color = "AAAAAA" },
    { jumps = 50,     title = "The Restless",        color = "AAAAAA" },
    { jumps = 250,    title = "the Hopper",          color = "55FF55" },
    { jumps = 500,    title = "the Springy",         color = "55FF55" },
    { jumps = 1000,   title = "the Airborne",        color = "55CCFF" },
    { jumps = 2500,   title = "the Gravity-Defiant", color = "55CCFF" },
    { jumps = 5000,   title = "of the Broken Ankles",color = "FF9900" },
    { jumps = 10000,  title = "the Perpetual",       color = "FF9900" },
    { jumps = 25000,  title = "the Untethered",      color = "FF4444" },
    { jumps = 50000,  title = "Ascendant",           color = "FFD700" },
    { jumps = 100000, title = "of Pure Bounce",      color = "FFD700" },
}

-- Returns the highest unlocked title entry for a given jump count, or nil.
function B.GetTitle(totalJumps)
    local result = nil
    for _, t in ipairs(B.TITLES) do
        if totalJumps >= t.jumps then
            result = t
        end
    end
    return result
end

-- Returns the next locked title entry (next goal), or nil if all unlocked.
function B.GetNextTitle(totalJumps)
    for _, t in ipairs(B.TITLES) do
        if totalJumps < t.jumps then
            return t
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Streak multipliers
-------------------------------------------------------------------------------
B.STREAK_MULTIPLIERS = {
    { min = 1,   max = 1,   mult = 1.0, color = "ffffff" },
    { min = 2,   max = 3,   mult = 2.0, color = "00ff88" },
    { min = 4,   max = 6,   mult = 3.0, color = "ffcc00" },
    { min = 7,   max = 10,  mult = 4.0, color = "ff9900" },
    { min = 11,  max = 14,  mult = 5.0, color = "ff6600" },
    { min = 15,  max = 24,  mult = 7.0, color = "cc33ff" },
    { min = 25,  max = 999, mult = 10.0, color = "66ccff" },
}

-- Streak window: max seconds between jumps to keep the combo alive
B.STREAK_WINDOW = 2.2

-------------------------------------------------------------------------------
-- Colors
-------------------------------------------------------------------------------
B.COLOR = {
    TITLE    = "A0E4FF",
    JUMP     = "FFFFFF",
    STREAK   = "FFCC00",
    XP       = "AAF0AA",
    LEVEL_UP = "FFD700",
    DIM      = "888888",
    TITLE_LBL= "DDBBFF",   -- color for the title label in UI
}

function B.Hex(hex, text)
    return string.format("|cff%s%s|r", hex, text)
end

-- Format large numbers with commas: 1234567 -> "1,234,567"
function B.FormatNum(n)
    local s = tostring(math.floor(n or 0))
    local result, len = "", #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
        result = result .. s:sub(i, i)
    end
    return result
end
