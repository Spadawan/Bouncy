-------------------------------------------------------------------------------
-- Core/Namespace.lua
-- Global namespace, constants, level definitions, titles.
-- Must load first.
-------------------------------------------------------------------------------

local B = {}
_G.Bouncy = B

B.ADDON_NAME = "Bouncy"
B.VERSION    = "1.0.0"

-------------------------------------------------------------------------------
-- Bunny evolution stages (XP-based)
-- artwork = placeholder — replace with your own TGA/BLP per level
-------------------------------------------------------------------------------
B.LEVELS = {
    { level = 1, name = "Fluffy Newcomer",  threshold = 0,     artwork = "Interface\\AddOns\\Bouncy\\media\\bunny1.tga" },
    { level = 2, name = "Hoppling",         threshold = 100,   artwork = "Interface\\AddOns\\Bouncy\\media\\bunny2.tga" },
    { level = 3, name = "Agile Leaper",     threshold = 500,   artwork = "Interface\\AddOns\\Bouncy\\media\\bunny3.tga" },
    { level = 4, name = "Acrobat",          threshold = 1500,  artwork = "Interface\\AddOns\\Bouncy\\media\\bunny4.tga" },
    { level = 5, name = "Jump Champion",    threshold = 4000,  artwork = "Interface\\AddOns\\Bouncy\\media\\bunny5.tga" },
    { level = 6, name = "Master Bouncer",   threshold = 10000, artwork = "Interface\\AddOns\\Bouncy\\media\\bunny6.tga" },
    { level = 7, name = "Jump Legend",      threshold = 25000, artwork = "Interface\\AddOns\\Bouncy\\media\\bunny7.tga" },
    { level = 8, name = "Bounce God",       threshold = 60000, artwork = "Interface\\AddOns\\Bouncy\\media\\bunny8.tga" },
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
    { min = 1,   max = 2,   mult = 1.0, color = "ffffff" },
    { min = 3,   max = 5,   mult = 1.5, color = "00ff88" },
    { min = 6,   max = 9,   mult = 2.0, color = "ffcc00" },
    { min = 10,  max = 999, mult = 3.0, color = "ff6600" },
}

-- Streak window: max seconds between jumps to keep the combo alive
B.STREAK_WINDOW = 1.2

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
