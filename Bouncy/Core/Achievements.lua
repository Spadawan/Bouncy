-------------------------------------------------------------------------------
-- Core/Achievements.lua
-- Per-character achievement definitions evaluated from existing jump data.
-------------------------------------------------------------------------------

local B = _G.Bouncy
B.Achievements = {}
local Achievements = B.Achievements

local function CountZones(char)
    local n = 0
    for _, count in pairs(char.byZone or {}) do
        if (count or 0) > 0 then n = n + 1 end
    end
    return n
end

local function ZoneCount(char, aliases)
    local total = 0
    for zone, count in pairs(char.byZone or {}) do
        local z = tostring(zone or ""):lower()
        for _, alias in ipairs(aliases or {}) do
            if z == tostring(alias):lower() then
                total = total + (count or 0)
                break
            end
        end
    end
    return total
end

local function HighestZoneCount(char)
    local best = 0
    for _, count in pairs(char.byZone or {}) do
        best = math.max(best, count or 0)
    end
    return best
end

local function ProgressAchievement(id, category, title, description, icon, points, goal, progressFn, reward)
    return {
        id = id,
        category = category,
        title = title,
        description = description,
        icon = icon,
        points = points or 5,
        goal = goal or 1,
        reward = reward,
        progress = progressFn,
    }
end

local function TotalJumps(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Journey", title, description, icon, points, goal,
        function(char) return char.totalJumps or 0, goal end)
end

local function DailyJumps(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Daily", title, description, icon, points, goal,
        function(char) return (char.daily and char.daily.jumps) or 0, goal end)
end

local function WeeklyJumps(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Weekly", title, description, icon, points, goal,
        function(char) return (char.weekly and char.weekly.jumps) or 0, goal end)
end

local function Streak(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Streaks", title, description, icon, points, goal,
        function(char) return char.bestStreak or 0, goal end)
end

local function PlayerLevel(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Progression", title, description, icon, points, goal,
        function(_, prog)
            local lvlData = B.Leveling:GetLevelForXP((prog and prog.xp) or 0, true)
            return lvlData.level or 1, goal
        end)
end

local function PetLevel(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Companion", title, description, icon, points, goal,
        function(_, prog) return (prog and prog.level) or 1, goal end)
end

local function Zone(goal, aliases, id, title, description, icon, points)
    return ProgressAchievement(id, "Zones", title, description, icon, points, goal,
        function(char) return ZoneCount(char, aliases), goal end)
end

local ACHIEVEMENTS = {
    TotalJumps(1, "first_bounce", "First Bounce", "Perform your very first verified jump.", "Interface\\Icons\\Ability_Rogue_Sprint", 5),
    TotalJumps(100, "warm_soles", "Warm Soles", "Reach 100 total jumps.", "Interface\\Icons\\Ability_Monk_TigerPalm", 5),
    TotalJumps(1000, "thousand_springs", "A Thousand Springs", "Reach 1,000 total jumps.", "Interface\\Icons\\Ability_Hunter_AspectOfTheMonkey", 10),
    TotalJumps(10000, "ten_thousand_toes", "Ten Thousand Toes", "Reach 10,000 total jumps without blaming your spacebar.", "Interface\\Icons\\Achievement_FeatsOfStrength_Gladiator_10", 20),
    TotalJumps(50000, "spacebar_legend", "Spacebar Legend", "Reach 50,000 total jumps. Keyboards will remember your name.", "Interface\\Icons\\Achievement_LegendaryRing", 30),

    DailyJumps(250, "morning_calves", "Morning Calves", "Perform 250 jumps in a single day.", "Interface\\Icons\\Spell_Holy_BorrowedTime", 10),
    DailyJumps(1000, "daily_takeoff", "Daily Takeoff", "Perform 1,000 jumps in a single day.", "Interface\\Icons\\Achievement_BG_winWSG_3-0", 20),
    WeeklyJumps(2000, "weekly_routine", "Weekly Routine", "Perform 2,000 jumps in a single week.", "Interface\\Icons\\INV_Misc_Calendar_01", 10),
    WeeklyJumps(10000, "leg_day_never_ends", "Leg Day Never Ends", "Perform 10,000 jumps in a single week.", "Interface\\Icons\\Achievement_General_StayClassy", 25),

    Streak(5, "combo_spark", "Combo Spark", "Reach a best streak of 5 jumps.", "Interface\\Icons\\Spell_Nature_Lightning", 5),
    Streak(10, "combo_ignition", "Combo Ignition", "Reach a best streak of 10 jumps.", "Interface\\Icons\\Spell_Fire_FlameBolt", 10),
    Streak(25, "terminal_velocity", "Terminal Velocity", "Reach a best streak of 25 jumps.", "Interface\\Icons\\Ability_Druid_FlightForm", 20),
    Streak(50, "dont_touch_the_floor", "Don't Touch the Floor", "Reach a best streak of 50 jumps.", "Interface\\Icons\\Spell_Arcane_Blink", 35),

    PlayerLevel(10, "rising_bounder", "Rising Bounder", "Reach player jump level 10.", "Interface\\Icons\\Achievement_Level_10", 10),
    PlayerLevel(25, "cloud_training", "Cloud Training", "Reach player jump level 25.", "Interface\\Icons\\Achievement_Level_25", 15),
    PlayerLevel(50, "halfway_to_the_moon", "Halfway to the Moon", "Reach player jump level 50.", "Interface\\Icons\\Achievement_Level_50", 25),
    PlayerLevel(100, "lord_of_the_leap", "Lord of the Leap", "Reach player jump level 100.", "Interface\\Icons\\Achievement_Level_100", 50),

    PetLevel(3, "snack_apprentice", "Snack Apprentice", "Raise your companion to level 3.", "Interface\\Icons\\INV_Misc_Food_59", 10),
    PetLevel(6, "evolution_enthusiast", "Evolution Enthusiast", "Raise your companion to level 6.", "Interface\\Icons\\Ability_Hunter_BeastCall", 15),
    PetLevel(12, "beast_bond", "Beast Bond", "Raise your companion to level 12.", "Interface\\Icons\\Ability_Hunter_BeastWithin", 25),

    ProgressAchievement("world_sampler", "Exploration", "World Sampler", "Jump in 10 different zones.", "Interface\\Icons\\Achievement_Zone_EasternKingdoms_01", 10, 10,
        function(char) return CountZones(char), 10 end),
    ProgressAchievement("cartographers_calves", "Exploration", "Cartographer's Calves", "Jump in 25 different zones.", "Interface\\Icons\\Achievement_Zone_Kalimdor_01", 20, 25,
        function(char) return CountZones(char), 25 end),
    ProgressAchievement("local_hero", "Exploration", "Local Hero", "Perform 500 jumps in a single zone.", "Interface\\Icons\\Achievement_Quests_Completed_08", 15, 500,
        function(char) return HighestZoneCount(char), 500 end),

    Zone(100, { "Stormwind City", "Hurlevent" }, "stormwind_rooftops", "Stormwind Rooftop Inspector", "Perform 100 jumps in Stormwind City.", "Interface\\Icons\\Achievement_Zone_Stormwind", 10),
    Zone(100, { "Orgrimmar" }, "orgrimmar_elevator", "Orgrimmar Elevator Tester", "Perform 100 jumps in Orgrimmar.", "Interface\\Icons\\Achievement_Zone_Durotar", 10),
    Zone(100, { "Ironforge", "Forgefer" }, "ironforge_anvils", "Ironforge Anvil Acrobat", "Perform 100 jumps in Ironforge.", "Interface\\Icons\\Achievement_Zone_DunMorogh", 10),
    Zone(100, { "Thunder Bluff", "Les Pitons-du-Tonnerre" }, "thunder_bluff_edges", "Thunder Bluff Edge Dancer", "Perform 100 jumps in Thunder Bluff.", "Interface\\Icons\\Achievement_Zone_Mulgore", 10),
    Zone(250, { "Dalaran" }, "dalaran_lag_tester", "Dalaran Lag Tester", "Perform 250 jumps in Dalaran.", "Interface\\Icons\\Achievement_Zone_Dalaran", 15),
    Zone(100, { "Valdrakken" }, "valdrakken_drake_dodger", "Valdrakken Drake Dodger", "Perform 100 jumps in Valdrakken.", "Interface\\Icons\\Achievement_Zone_Thaldraszus", 15),
    Zone(50, { "Goldshire", "Comté-de-l'Or", "Comte-de-l'Or" }, "goldshire_ceiling", "Goldshire Ceiling Inspector", "Perform 50 jumps in Goldshire.", "Interface\\Icons\\Achievement_Zone_ElwynnForest", 5),
    Zone(50, { "Darkmoon Island", "Île de Sombrelune", "Ile de Sombrelune" }, "darkmoon_trampoline", "Darkmoon Trampoline", "Perform 50 jumps on Darkmoon Island.", "Interface\\Icons\\Achievement_Quests_Completed_Darkmoon", 10),
}

local byID = {}
for _, achievement in ipairs(ACHIEVEMENTS) do
    byID[achievement.id] = achievement
end

function Achievements:GetAll()
    return ACHIEVEMENTS
end

function Achievements:GetByID(id)
    return byID[id]
end

function Achievements:EnsureCharState(char)
    if not char then return end
    if type(char.achievements) ~= "table" then
        char.achievements = {}
    end
end

function Achievements:GetProgress(achievement, char, prog)
    local current, goal = achievement.progress(char or {}, prog or {})
    goal = goal or achievement.goal or 1
    current = current or 0
    return current, goal, current >= goal
end

function Achievements:IsUnlocked(char, id)
    self:EnsureCharState(char)
    return char and char.achievements and char.achievements[id] ~= nil
end

function Achievements:Evaluate(char, prog)
    char = char or (B.DB and B.DB:GetChar())
    prog = prog or (B.DB and B.DB:GetProgression())
    if not char then return nil end
    self:EnsureCharState(char)

    local newlyUnlocked = {}
    for _, achievement in ipairs(ACHIEVEMENTS) do
        if not char.achievements[achievement.id] then
            local _, _, complete = self:GetProgress(achievement, char, prog)
            if complete then
                char.achievements[achievement.id] = { earnedAt = GetServerTime and GetServerTime() or time() }
                newlyUnlocked[#newlyUnlocked + 1] = achievement
            end
        end
    end
    if #newlyUnlocked > 0 then return newlyUnlocked end
    return nil
end

function Achievements:GetSummary(char, prog)
    char = char or (B.DB and B.DB:GetChar())
    prog = prog or (B.DB and B.DB:GetProgression())
    if not char then return 0, #ACHIEVEMENTS, 0, 0 end
    self:EnsureCharState(char)
    local unlocked, totalPoints, earnedPoints = 0, 0, 0
    for _, achievement in ipairs(ACHIEVEMENTS) do
        local points = achievement.points or 0
        totalPoints = totalPoints + points
        if char.achievements[achievement.id] then
            unlocked = unlocked + 1
            earnedPoints = earnedPoints + points
        end
    end
    return unlocked, #ACHIEVEMENTS, earnedPoints, totalPoints
end
