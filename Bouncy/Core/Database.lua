-------------------------------------------------------------------------------
-- Core/Database.lua
-- Owns all Bouncy_DB reads/writes. No other module touches Bouncy_DB directly.
-------------------------------------------------------------------------------

local B  = _G.Bouncy
B.DB     = {}
local DB = B.DB

local SCHEMA_VERSION = 2

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
        showTitle        = true,    -- selected unlocked title above the counter
        showJumpsLabel   = true,    -- "JUMPS" sub-label
        showXPBarAndLevel= true,    -- XP bar + level text (single toggle)
        showPlusOne      = true,    -- floating +Exp animation
        -- Appearance
        overlayFontSize  = 26,      -- main jump counter font size (18-40)
        jumpTextColor    = { r=1.0, g=1.0, b=1.0 },  -- jump counter color
        jumpTextOutline  = true,    -- black outline on jump counter text
        -- Animations
        plusOneDirection = "auto",  -- "auto" | "up" | "down"
        plusOneSize      = 16,      -- font size of +Exp text (10-22)
        plusOneOffsetX   = -54,     -- +Exp anchor offset relative to jump number
        xpBarOffsetY     = 12,      -- vertical offset for XP bar
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
    local oldVersion = Bouncy_DB.version or 0
    deepMerge(Bouncy_DB, DEFAULTS)
    if oldVersion < 2 then
        Bouncy_DB.settings.showTitle = true
    end
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
            achievements = {}, -- [achievementID] = { earnedAt = timestamp }
            creatureStats = { feeds = 0, consecutiveFeeds = 0, evolutions = 0, typeSelections = 0 },
            specialJumps = { raid = 0, instance = 0, night = 0, home = 0, mounted = 0 },
            byZoneID   = {},   -- [uiMapID/zoneID] = jumpCount
            bySubZone  = {},   -- [subZoneName] = jumpCount
            byZone     = {},   -- [zoneName] = jumpCount
            daily      = { dayStart = 0, jumps = 0 },
            weekly     = { weekStart = 0, jumps = 0 },
        }
    end
    local char = Bouncy_DB.characters[key]
    if type(char.bestStreak) ~= "number" then char.bestStreak = 0 end
    if type(char.achievements) ~= "table" then char.achievements = {} end
    if type(char.creatureStats) ~= "table" then char.creatureStats = {} end
    for _, field in ipairs({ "feeds", "consecutiveFeeds", "evolutions", "typeSelections" }) do
        if type(char.creatureStats[field]) ~= "number" then char.creatureStats[field] = 0 end
    end
    if type(char.specialJumps) ~= "table" then char.specialJumps = {} end
    if type(char.byZoneID) ~= "table" then char.byZoneID = {} end
    if type(char.bySubZone) ~= "table" then char.bySubZone = {} end
    for _, field in ipairs({ "raid", "instance", "night", "home", "mounted" }) do
        if type(char.specialJumps[field]) ~= "number" then char.specialJumps[field] = 0 end
    end
    return char
end

-------------------------------------------------------------------------------
-- Record a jump
-------------------------------------------------------------------------------
function DB:RecordJump(zoneName, context)
    local key  = self:CharKey()
    local char = self:EnsureChar(key)
    char.totalJumps = char.totalJumps + 1

    -- By zone
    zoneName = zoneName or "Unknown"
    char.byZone[zoneName] = (char.byZone[zoneName] or 0) + 1
    context = context or {}
    if context.mapID then
        local mapKey = tostring(context.mapID)
        char.byZoneID = char.byZoneID or {}
        char.byZoneID[mapKey] = (char.byZoneID[mapKey] or 0) + 1
    end
    if context.subZone and context.subZone ~= "" then
        char.bySubZone = char.bySubZone or {}
        char.bySubZone[context.subZone] = (char.bySubZone[context.subZone] or 0) + 1
    end

    -- Special achievement counters
    char.specialJumps = char.specialJumps or { raid = 0, instance = 0, night = 0, home = 0, mounted = 0 }
    if context.instanceType == "raid" then
        char.specialJumps.raid = (char.specialJumps.raid or 0) + 1
    elseif context.instanceType == "party" then
        char.specialJumps.instance = (char.specialJumps.instance or 0) + 1
    end
    if context.isNight then char.specialJumps.night = (char.specialJumps.night or 0) + 1 end
    if context.isHome then char.specialJumps.home = (char.specialJumps.home or 0) + 1 end
    if context.isMounted then char.specialJumps.mounted = (char.specialJumps.mounted or 0) + 1 end

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
        Bouncy_DB.leaderboard[key] = { name = char.name, realm = char.realm, class = char.class, jumps = 0, level = 1, petLevel = 1, bestStreak = 0 }
    end
    Bouncy_DB.leaderboard[key].jumps = char.totalJumps
    local prog = self:GetProgression()
    local lvlData = B.Leveling and B.Leveling.GetLevelForXP and B.Leveling:GetLevelForXP(prog.xp or 0, true) or { level = 1 }
    Bouncy_DB.leaderboard[key].level = lvlData.level or 1
    Bouncy_DB.leaderboard[key].petLevel = prog.level or 1
    Bouncy_DB.leaderboard[key].bestStreak = char.bestStreak or 0
end

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Record best streak
-------------------------------------------------------------------------------
function DB:RecordStreak(n)
    local char = self:EnsureChar()
    if n > (char.bestStreak or 0) then
        char.bestStreak = n
        local key = self:CharKey()
        Bouncy_DB.leaderboard[key] = Bouncy_DB.leaderboard[key] or { name = char.name, realm = char.realm, class = char.class, jumps = char.totalJumps or 0 }
        Bouncy_DB.leaderboard[key].bestStreak = n
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
local function CreatureUnlockRequirement(creatureIndex)
    local rule = B.CREATURE_UNLOCKS and B.CREATURE_UNLOCKS[creatureIndex]
    return rule and rule.unlockLevel or nil
end

local function CreatureSlotKey(creatureIndex)
    return tostring(tonumber(creatureIndex) or 1)
end

local function IsCreatureType(value)
    for _, creatureType in ipairs(B.CREATURE_TYPES or {}) do
        if creatureType == value then return true end
    end
    return false
end


local function LegacyCreatureScore(creature, preferred)
    if type(creature) ~= "table" then return -1 end
    local score = ((creature.level or 1) * 100000) + (creature.creatureXP or 0)
    if creature.unlocked then score = score + 10000 end
    if preferred then score = score + 1000 end
    return score
end

local function FindBestLegacyTypedCreature(prog, preferredType)
    local bestType, bestCreature, bestScore = nil, nil, -1
    if type(prog.creatures) ~= "table" then return nil, nil end
    for _, creatureType in ipairs(B.CREATURE_TYPES or {}) do
        local candidate = prog.creatures[creatureType]
        if type(candidate) == "table" and (candidate.unlocked or candidate.level or candidate.creatureXP) then
            local score = LegacyCreatureScore(candidate, creatureType == preferredType)
            if score > bestScore then
                bestType, bestCreature, bestScore = creatureType, candidate, score
            end
        end
    end
    return bestType, bestCreature
end

function DB:GetMaxCreatureLevel(prog)
    prog = prog or self:GetProgression()
    local maxLevel = 1
    for i = 1, #(B.CREATURE_UNLOCKS or B.CREATURE_TYPES or {}) do
        local c = prog.creatures and prog.creatures[CreatureSlotKey(i)]
        if c and c.unlocked and (c.level or 1) > maxLevel then
            maxLevel = c.level or 1
        end
    end
    return maxLevel
end

function DB:EnsureCreatureState(prog)
    if type(prog.creatures) ~= "table" then prog.creatures = {} end

    local activeType = prog.creatureType
    if activeType == "" or not IsCreatureType(activeType) then activeType = nil end

    -- Migrate both the original single-creature save and the previous keyed-by-type
    -- implementation into slot 1. Slot 1 is whatever creature the player already had.
    if not prog.creatureSlotsMigrated then
        local migratedType, migrated = FindBestLegacyTypedCreature(prog, activeType)
        if migratedType then activeType = migratedType end

        prog.creatures = {}
        local slot = {
            type = activeType,
            level = (migrated and migrated.level) or prog.level or 1,
            creatureXP = (migrated and migrated.creatureXP) or prog.creatureXP or 0,
            unlocked = true,
        }
        prog.creatures["1"] = slot
        prog.activeCreatureIndex = 1
        prog.creatureSlotsMigrated = true
    end

    -- Repair saves produced by the first multi-creature builds: if typed legacy
    -- entries are still present, keep the strongest/previously chosen one in slot 1
    -- instead of letting the default Astral level 1 entry win.
    if not prog.creatureSlotsMigrationV2 then
        local migratedType, migrated = FindBestLegacyTypedCreature(prog, activeType)
        local slot1 = prog.creatures["1"]
        if migrated and (not slot1 or LegacyCreatureScore(migrated, migratedType == activeType) > LegacyCreatureScore(slot1, slot1 and slot1.type == activeType)) then
            prog.creatures["1"] = {
                type = migratedType,
                level = migrated.level or 1,
                creatureXP = migrated.creatureXP or 0,
                unlocked = true,
            }
            prog.activeCreatureIndex = 1
        end
        prog.creatureSlotsMigrationV2 = true
    end

    local slotCount = #(B.CREATURE_UNLOCKS or {})
    if slotCount == 0 then slotCount = #(B.CREATURE_TYPES or {}) end
    if slotCount == 0 then slotCount = 5 end

    for i = 1, slotCount do
        local key = CreatureSlotKey(i)
        if type(prog.creatures[key]) ~= "table" then
            prog.creatures[key] = { level = 1, creatureXP = 0, unlocked = (i == 1), type = nil }
        end
        local c = prog.creatures[key]
        if c.type == "" or not IsCreatureType(c.type) then c.type = nil end
        if type(c.level) ~= "number" then c.level = 1 end
        if type(c.creatureXP) ~= "number" then c.creatureXP = 0 end
        if i == 1 then c.unlocked = true end
    end

    local first = prog.creatures["1"]
    local firstLevel = first and (first.level or 1) or 1
    local maxLevel = self:GetMaxCreatureLevel(prog)
    for i = 1, slotCount do
        local c = prog.creatures[CreatureSlotKey(i)]
        local req = CreatureUnlockRequirement(i)
        if i == 2 then
            c.unlocked = c.unlocked or (firstLevel >= (req or 999))
        elseif req then
            c.unlocked = c.unlocked or (maxLevel >= req)
        else
            c.unlocked = true
        end
    end

    local activeIndex = tonumber(prog.activeCreatureIndex) or 1
    local active = prog.creatures[CreatureSlotKey(activeIndex)]
    if not active or not active.unlocked then
        activeIndex = 1
        active = prog.creatures["1"]
    end
    prog.activeCreatureIndex = activeIndex

    prog.creatureType = active and active.type or nil
    prog.level = active and (active.level or 1) or 1
    prog.creatureXP = active and (active.creatureXP or 0) or 0
    return prog.creatures
end

function DB:GetProgression()
    local key = self:CharKey()
    if not Bouncy_DB.progression[key] then
        Bouncy_DB.progression[key] = { xp = 0, level = 1, creatureXP = 0, creatureType = nil, bonusXPFraction = 0, creatures = {}, activeCreatureIndex = 1 }
    end
    if type(Bouncy_DB.progression[key].bonusXPFraction) ~= "number" then
        Bouncy_DB.progression[key].bonusXPFraction = 0
    end
    self:EnsureCreatureState(Bouncy_DB.progression[key])
    if B.Leveling and B.Leveling.EnsurePlayerTitleState then
        B.Leveling:EnsurePlayerTitleState(Bouncy_DB.progression[key])
    end
    return Bouncy_DB.progression[key]
end

function DB:AddXP(amount)
    local prog = self:GetProgression()
    prog.xp = prog.xp + amount
    return prog
end

function DB:GetCreatureProgression(creatureIndex)
    local prog = self:GetProgression()
    self:EnsureCreatureState(prog)
    return prog.creatures and prog.creatures[CreatureSlotKey(creatureIndex)]
end

function DB:SetActiveCreature(creatureIndex)
    local prog = self:GetProgression()
    self:EnsureCreatureState(prog)
    local idx = tonumber(creatureIndex) or 1
    local creature = prog.creatures and prog.creatures[CreatureSlotKey(idx)]
    if creature and creature.unlocked then
        prog.activeCreatureIndex = idx
        prog.creatureType = creature.type
        prog.level = creature.level or 1
        prog.creatureXP = creature.creatureXP or 0
        return prog
    end
    return nil
end

function DB:SetCreatureType(creatureType)
    if not IsCreatureType(creatureType) then return nil end
    local prog = self:GetProgression()
    self:EnsureCreatureState(prog)
    local idx = tonumber(prog.activeCreatureIndex) or 1
    local creature = prog.creatures and prog.creatures[CreatureSlotKey(idx)]
    if creature and creature.unlocked then
        creature.type = creatureType
        prog.creatureType = creatureType
        prog.level = creature.level or 1
        prog.creatureXP = creature.creatureXP or 0
        return prog
    end
    return nil
end

function DB:SaveCreatureProgression(prog, creatureIndex)
    prog = prog or self:GetProgression()
    if type(prog.creatures) ~= "table" then prog.creatures = {} end
    local idx = tonumber(creatureIndex) or tonumber(prog.activeCreatureIndex) or 1
    local key = CreatureSlotKey(idx)
    if type(prog.creatures[key]) ~= "table" then
        prog.creatures[key] = { level = 1, creatureXP = 0, unlocked = (idx == 1), type = nil }
    end
    local creature = prog.creatures[key]
    if creature then
        creature.type = prog.creatureType or creature.type
        creature.level = prog.level or creature.level or 1
        creature.creatureXP = prog.creatureXP or creature.creatureXP or 0
    end
    self:EnsureCreatureState(prog)
    return creature
end


function DB:RecordCreatureFeed()
    local char = self:EnsureChar()
    char.creatureStats.feeds = (char.creatureStats.feeds or 0) + 1
    char.creatureStats.consecutiveFeeds = (char.creatureStats.consecutiveFeeds or 0) + 1
    return char.creatureStats
end

function DB:RecordCreatureEvolution()
    local char = self:EnsureChar()
    char.creatureStats.evolutions = (char.creatureStats.evolutions or 0) + 1
    char.creatureStats.consecutiveFeeds = 0
    return char.creatureStats
end

function DB:RecordCreatureTypeSelection()
    local char = self:EnsureChar()
    char.creatureStats.typeSelections = (char.creatureStats.typeSelections or 0) + 1
    return char.creatureStats
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

function DB:ResetCharWithConfirmation(confirm)
    if confirm == true then
        self:ResetChar()
        return true
    end
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["BOUNCY_RESET_CHARACTER"] = StaticPopupDialogs["BOUNCY_RESET_CHARACTER"] or {
        text = "Are you sure you want to reset this character's Bouncy data?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            B.DB:ResetChar()
            if B.Overlay then B.Overlay:Refresh() end
            if B.Details and B.Details.frame and B.Details.frame:IsShown() then B.Details:Refresh() end
            print(string.format("|cff%sBouncy|r Character data reset.", B.COLOR.TITLE))
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    if StaticPopup_Show then
        StaticPopup_Show("BOUNCY_RESET_CHARACTER")
        return false
    end
    return false
end
