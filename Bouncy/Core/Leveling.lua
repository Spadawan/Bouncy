-------------------------------------------------------------------------------
-- Core/Leveling.lua
-- XP, level-up logic, title unlock detection.
-------------------------------------------------------------------------------

local B        = _G.Bouncy
B.Leveling     = {}
local Leveling = B.Leveling

local CREATURE_XP_REQUIREMENT_MULTIPLIER = 0.90

local EVOLUTION_STAGES = {
    { min = 1,  max = 5,  art = 1, label = "Astral Hatchling" },
    { min = 6,  max = 15, art = 2, label = "Astral Youngling" },
    { min = 16, max = 30, art = 3, label = "Astral Adept" },
    { min = 31, max = 45, art = 4, label = "Astral Ascendant" },
    { min = 46, max = 65, art = 5, label = "Astral Elder" },
    { min = 66, max = 999,art = 6, label = "Astral Mythic" },
}

local CREATURE_LABELS = {
    Astral = { "Astral Hatchling", "Astral Youngling", "Astral Adept", "Astral Ascendant", "Astral Elder", "Astral Mythic" },
    Fire   = { "Ember Wisp", "Flare Cub", "Blazeling", "Inferno Stalker", "Pyre Guardian", "Solar Phoenix" },
    Water  = { "Dew Sprite", "Ripple Cub", "Tide Dancer", "Current Keeper", "Abyss Warden", "Ocean Sovereign" },
    Lunar  = { "Moonlet", "Crescent Prowler", "Nightglow Adept", "Eclipse Hunter", "Starbound Sentinel", "Celestial Oracle" },
    Electric = { "Spark Pup", "Volt Runner", "Static Strider", "Storm Charger", "Thunder Warden", "Tempest Prime" },
}

function Leveling:GetLevelsForProgression(prog)
    local creatureType = prog and prog.creatureType
    if creatureType and B.CREATURE_LEVELS and B.CREATURE_LEVELS[creatureType] then
        return B.CREATURE_LEVELS[creatureType]
    end
    return B.LEVELS
end

function Leveling:GetLevelForXP(xp, forceBase)
    local levels = B.LEVELS
    if not forceBase then
        levels = B.LEVELS
    end
    local current = levels[1]
    for i = #levels, 1, -1 do
        if xp >= levels[i].threshold then
            current = levels[i]
            break
        end
    end
    return current
end

function Leveling:GetNextLevel(currentLevel, forceBase)
    local levels = B.LEVELS
    if not forceBase then
        levels = B.LEVELS
    end
    for _, lvl in ipairs(levels) do
        if lvl.level == currentLevel + 1 then return lvl end
    end
    return nil
end

-- Returns frac [0-1], current level data, next level data (or nil if max)
function Leveling:GetProgress(xp, forceBase)
    local cur  = self:GetLevelForXP(xp, forceBase)
    local next = self:GetNextLevel(cur.level, forceBase)
    if not next then return 1.0, cur, nil end
    local xpInto  = xp - cur.threshold
    local xpNeeded= next.threshold - cur.threshold
    return math.min(1.0, xpInto / xpNeeded), cur, next
end

function Leveling:GetCreatureStage(level)
    for _, s in ipairs(EVOLUTION_STAGES) do
        if level >= s.min and level <= s.max then return s end
    end
    return EVOLUTION_STAGES[#EVOLUTION_STAGES]
end

function Leveling:GetCreatureLabel(creatureType, level)
    local stage = self:GetCreatureStage(level or 1)
    local labels = CREATURE_LABELS[creatureType or "Astral"] or CREATURE_LABELS.Astral
    return labels[stage.art] or stage.label or "Companion"
end

function Leveling:GetCreatureXPRequirement(level)
    level = math.max(1, tonumber(level) or 1)

    local function ReduceRequirement(req)
        return math.max(1, math.floor((req or 1) * CREATURE_XP_REQUIREMENT_MULTIPLIER + 0.5))
    end

    local anchors = {
        [1] = 200, -- lvl 1 -> 2
        [2] = 300, -- lvl 2 -> 3
        [3] = 400, -- lvl 3 -> 4
        [4] = 550, -- lvl 4 -> 5
    }
    if anchors[level] then
        return ReduceRequirement(anchors[level])
    end

    local req = anchors[4]
    for _ = 5, level do
        req = math.floor(req * 1.35 + 0.5)
    end
    return ReduceRequirement(req)
end

function Leveling:GetCreatureBonusPercent(level, prog)
    if prog and not prog.creatureType then return 0 end
    local stage = self:GetCreatureStage(level or 1)
    local evolutions = math.max(0, (stage.art or 1) - 1)
    local perLevel = math.max(0, level or 1) * 1
    local evoBonus = evolutions * 3
    return perLevel + evoBonus
end

function Leveling:GetTotalCreatureBonusPercent(prog)
    if type(prog) ~= "table" then return 0 end
    local total = 0
    if type(prog.creatures) == "table" then
        for _, creature in pairs(prog.creatures) do
            if type(creature) == "table" and creature.unlocked and creature.type then
                total = total + self:GetCreatureBonusPercent(creature.level or 1, { creatureType = creature.type })
            end
        end
    end
    if total == 0 and prog.creatureType then
        total = self:GetCreatureBonusPercent(prog.level or 1, prog)
    end
    return total
end


-------------------------------------------------------------------------------
-- Level title unlocks (persistent per character)
-------------------------------------------------------------------------------
function Leveling:EnsurePlayerTitleState(prog)
    if type(prog.unlockedPlayerTitles) ~= "table" then
        prog.unlockedPlayerTitles = {}
    end

    local currentLevel = 1
    if prog and type(prog.xp) == "number" then
        local levelData = self:GetLevelForXP(prog.xp, true)
        currentLevel = levelData and levelData.level or currentLevel
    end

    for _, title in ipairs(B.GetLevelTitleMilestones()) do
        if title.source == "level" and (title.level or 1) <= currentLevel then
            prog.unlockedPlayerTitles[title.id] = true
        end
    end

    if prog.selectedPlayerTitle and (not B.GetLevelTitleByID(prog.selectedPlayerTitle) or not prog.unlockedPlayerTitles[prog.selectedPlayerTitle]) then
        prog.selectedPlayerTitle = nil
    end
    if not prog.selectedPlayerTitle then
        for _, title in ipairs(B.GetLevelTitleMilestones()) do
            if prog.unlockedPlayerTitles[title.id] then
                prog.selectedPlayerTitle = title.id
                break
            end
        end
    end
end

function Leveling:GetUnlockedPlayerTitles(prog)
    self:EnsurePlayerTitleState(prog)
    local out = {}
    for _, title in ipairs(B.GetLevelTitleMilestones()) do
        if prog.unlockedPlayerTitles[title.id] then
            out[#out + 1] = title
        end
    end
    return out
end

function Leveling:SetSelectedPlayerTitle(prog, titleID)
    self:EnsurePlayerTitleState(prog)
    if prog.unlockedPlayerTitles[titleID] and B.GetLevelTitleByID(titleID) then
        prog.selectedPlayerTitle = titleID
        return true
    end
    return false
end

function Leveling:GetSelectedPlayerTitle(prog)
    self:EnsurePlayerTitleState(prog)
    if prog.selectedPlayerTitle and prog.unlockedPlayerTitles[prog.selectedPlayerTitle] then
        return B.GetLevelTitleByID(prog.selectedPlayerTitle)
    end
    return nil
end

function Leveling:UnlockPlayerTitlesForLevelRange(prog, oldLevel, newLevel)
    self:EnsurePlayerTitleState(prog)
    local unlocked = {}
    for _, title in ipairs(B.GetLevelTitleMilestones()) do
        local level = title.level or 1
        if level > (oldLevel or 1) and level <= (newLevel or 1) and not prog.unlockedPlayerTitles[title.id] then
            prog.unlockedPlayerTitles[title.id] = true
            if not prog.selectedPlayerTitle then prog.selectedPlayerTitle = title.id end
            unlocked[#unlocked + 1] = title
        end
    end
    return unlocked
end

function Leveling:IsEvolutionLevel(level)
    local stage = self:GetCreatureStage(level or 1)
    local nextStage = self:GetCreatureStage((level or 1) + 1)
    return nextStage.art ~= stage.art
end

function Leveling:CanEvolve(prog)
    local level = prog.level or 1
    if not self:IsEvolutionLevel(level) then return false end
    local req = self:GetCreatureXPRequirement(level)
    return (prog.creatureXP or 0) >= req
end

function Leveling:AdvanceCreatureNonEvolutionLevels(prog)
    local changed = false
    while true do
        local level = prog.level or 1
        if self:IsEvolutionLevel(level) then break end
        local req = self:GetCreatureXPRequirement(level)
        if (prog.creatureXP or 0) < req then break end
        prog.creatureXP = (prog.creatureXP or 0) - req
        prog.level = level + 1
        changed = true
    end
    return changed
end

-- Evaluate XP progression, fire level-up callbacks if needed.
-- Also checks for new title unlocks based on total jumps.
function Leveling:Evaluate(prog)
    local newLevelData = self:GetLevelForXP(prog.xp)
    if newLevelData.level > (prog.level or 1) then
        prog.level = newLevelData.level
        for _, fn in ipairs(B._levelUpCallbacks or {}) do
            pcall(fn, newLevelData)
        end
        return newLevelData
    end
    return nil
end

-- Check if a new title was just unlocked; called after RecordJump.
-- Returns the title entry if newly unlocked, else nil.
function Leveling:CheckTitleUnlock(totalJumps)
    for _, t in ipairs(B.TITLES) do
        if totalJumps == t.jumps then
            return t
        end
    end
    return nil
end

function Leveling:RegisterLevelUpCallback(fn)
    B._levelUpCallbacks = B._levelUpCallbacks or {}
    table.insert(B._levelUpCallbacks, fn)
end

function Leveling:FormatXP(xp)
    local frac, cur, next = self:GetProgress(xp)
    if not next then
        return string.format("|cff%sMAX LEVEL|r", B.COLOR.LEVEL_UP)
    end
    return string.format("|cff%s%s|r / |cff%s%s|r XP",
        B.COLOR.XP,  B.FormatNum(xp - cur.threshold),
        B.COLOR.DIM, B.FormatNum(next.threshold - cur.threshold))
end
