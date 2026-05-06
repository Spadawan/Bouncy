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

local function SpecialCount(char, field)
    return (char.specialJumps and char.specialJumps[field]) or 0
end

local function ProgressAchievement(id, category, title, description, icon, points, goal, progressFn, rewardTitle)
    return {
        id = id,
        category = category,
        title = title,
        description = description,
        icon = icon,
        points = points or 5,
        goal = goal or 1,
        rewardTitle = rewardTitle,
        progress = progressFn,
    }
end

local function TotalJumps(goal, id, title, description, icon, points, rewardTitle)
    return ProgressAchievement(id, "Journey", title, description, icon, points, goal,
        function(char) return char.totalJumps or 0, goal end, rewardTitle)
end

local function DailyJumps(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Daily", title, description, icon, points, goal,
        function(char) return (char.daily and char.daily.jumps) or 0, goal end)
end

local function WeeklyJumps(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Weekly", title, description, icon, points, goal,
        function(char) return (char.weekly and char.weekly.jumps) or 0, goal end)
end

local function Streak(goal, id, title, description, icon, points, rewardTitle)
    return ProgressAchievement(id, "Streaks", title, description, icon, points, goal,
        function(char) return char.bestStreak or 0, goal end, rewardTitle)
end

local function PlayerLevel(goal, id, title, description, icon, points, rewardTitle)
    return ProgressAchievement(id, "Progression", title, description, icon, points, goal,
        function(_, prog)
            local lvlData = B.Leveling:GetLevelForXP((prog and prog.xp) or 0, true)
            return lvlData.level or 1, goal
        end, rewardTitle)
end

local function PetLevel(goal, id, title, description, icon, points)
    return ProgressAchievement(id, "Companion", title, description, icon, points, goal,
        function(_, prog) return (prog and prog.level) or 1, goal end)
end

local function Zone(goal, aliases, id, title, description, icon, points)
    return ProgressAchievement(id, "Zones", title, description, icon, points, goal,
        function(char) return ZoneCount(char, aliases), goal end)
end

local function Special(goal, field, id, title, description, icon, points, rewardTitle)
    return ProgressAchievement(id, "Special", title, description, icon, points, goal,
        function(char) return SpecialCount(char, field), goal end, rewardTitle)
end

local ACHIEVEMENTS = {
    TotalJumps(1, "first_bounce", "First Bounce", "Perform your very first verified jump.", "Interface\\Icons\\Ability_Rogue_Sprint", 5),
    TotalJumps(100, "warm_soles", "Warm Soles", "Reach 100 total jumps.", "Interface\\Icons\\Ability_Monk_TigerPalm", 5),
    TotalJumps(1000, "thousand_springs", "A Thousand Springs", "Reach 1,000 total jumps.", "Interface\\Icons\\Ability_Hunter_AspectOfTheMonkey", 10),
    TotalJumps(10000, "ten_thousand_toes", "Ten Thousand Toes", "Reach 10,000 total jumps without blaming your spacebar.", "Interface\\Icons\\Achievement_FeatsOfStrength_Gladiator_10", 20),
    TotalJumps(50000, "spacebar_legend", "Spacebar Legend", "Reach 50,000 total jumps. Keyboards will remember your name.", "Interface\\Icons\\INV_Misc_EngGizmos_30", 30,
        { id="title_spacebar_legend", title="Spacebar Legend", color="FF8000", level=999 }),

    DailyJumps(250, "morning_calves", "Morning Calves", "Perform 250 jumps in a single day.", "Interface\\Icons\\Spell_Holy_BorrowedTime", 10),
    DailyJumps(1000, "daily_takeoff", "Daily Takeoff", "Perform 1,000 jumps in a single day.", "Interface\\Icons\\Achievement_BG_winWSG_3-0", 20),
    WeeklyJumps(2000, "weekly_routine", "Weekly Routine", "Perform 2,000 jumps in a single week.", "Interface\\Icons\\INV_Misc_Note_01", 10),
    WeeklyJumps(10000, "leg_day_never_ends", "Leg Day Never Ends", "Perform 10,000 jumps in a single week.", "Interface\\Icons\\Achievement_General_StayClassy", 25),

    Streak(5, "combo_spark", "Combo Spark", "Reach a best streak of 5 jumps.", "Interface\\Icons\\Spell_Nature_Lightning", 5),
    Streak(10, "combo_ignition", "Combo Ignition", "Reach a best streak of 10 jumps.", "Interface\\Icons\\Spell_Fire_FlameBolt", 10),
    Streak(25, "terminal_velocity", "Terminal Velocity", "Reach a best streak of 25 jumps.", "Interface\\Icons\\Ability_Druid_FlightForm", 20),
    Streak(50, "dont_touch_the_floor", "Don't Touch the Floor", "Reach a best streak of 50 jumps.", "Interface\\Icons\\Spell_Arcane_Blink", 35),
    Streak(100, "floor_is_a_myth", "The Floor Is a Myth", "Reach a best streak of 100 jumps.", "Interface\\Icons\\Spell_Arcane_PrismaticCloak", 45),
    Streak(250, "combo_constellation", "Combo Constellation", "Reach a best streak of 250 jumps.", "Interface\\Icons\\Spell_Arcane_Arcane04", 60,
        { id="title_combo_constellation", title="the Untouchable", color="A335EE", level=999 }),
    Streak(500, "sky_never_called_back", "The Sky Never Called Back", "Reach a best streak of 500 jumps.", "Interface\\Icons\\Spell_Arcane_ArcanePotency", 75,
        { id="title_sky_never_called_back", title="Skybound Myth", color="FF8000", level=999 }),

    PlayerLevel(10, "rising_bounder", "Rising Bounder", "Reach player jump level 10.", "Interface\\Icons\\Achievement_Level_10", 10),
    PlayerLevel(25, "cloud_training", "Cloud Training", "Reach player jump level 25.", "Interface\\Icons\\Ability_Monk_Roll", 15),
    PlayerLevel(50, "halfway_to_the_moon", "Halfway to the Moon", "Reach player jump level 50.", "Interface\\Icons\\Achievement_Level_50", 25),
    PlayerLevel(100, "lord_of_the_leap", "Lord of the Leap", "Reach player jump level 100.", "Interface\\Icons\\Achievement_Level_100", 50,
        { id="title_lord_of_the_leap_achievement", title="Lord of Every Leap", color="FF8000", level=999 }),

    PetLevel(3, "snack_apprentice", "Snack Apprentice", "Raise your companion to level 3.", "Interface\\Icons\\INV_Misc_Food_59", 10),
    PetLevel(6, "evolution_enthusiast", "Evolution Enthusiast", "Raise your companion to level 6.", "Interface\\Icons\\Ability_Hunter_BeastCall", 15),
    PetLevel(12, "beast_bond", "Beast Bond", "Raise your companion to level 12.", "Interface\\Icons\\Ability_Hunter_BeastWithin", 25),

    ProgressAchievement("world_sampler", "Exploration", "World Sampler", "Jump in 10 different zones.", "Interface\\Icons\\Achievement_Zone_EasternKingdoms_01", 10, 10,
        function(char) return CountZones(char), 10 end),
    ProgressAchievement("cartographers_calves", "Exploration", "Cartographer's Calves", "Jump in 25 different zones.", "Interface\\Icons\\Achievement_Zone_Kalimdor_01", 20, 25,
        function(char) return CountZones(char), 25 end),
    ProgressAchievement("local_hero", "Exploration", "Local Hero", "Perform 500 jumps in a single zone.", "Interface\\Icons\\Achievement_Quests_Completed_08", 15, 500,
        function(char) return HighestZoneCount(char), 500 end),

    Special(3000, "raid", "raid_calves", "Raid Calves", "Perform 3,000 jumps while in a raid.", "Interface\\Icons\\INV_Helmet_06", 30),
    Special(3000, "instance", "dungeon_spring_cleaning", "Dungeon Spring Cleaning", "Perform 3,000 jumps while in an instance group.", "Interface\\Icons\\INV_Misc_Key_03", 30),
    Special(6000, "night", "night_exercise", "Night Exercise", "Perform 6,000 jumps at night.", "Interface\\Icons\\Spell_Nature_StarFall", 40,
        { id="title_night_exercise", title="the Moonlit Bouncer", color="A335EE", level=999 }),
    Special(3000, "home", "home_exercise", "Home Exercise", "Perform 3,000 jumps at home.", "Interface\\Icons\\INV_Misc_Bag_08", 35,
        { id="title_home_exercise", title="Homebound Hopper", color="0070DD", level=999 }),
    Special(2500, "mounted", "it_still_counts", "It Still Counts", "Perform 2,500 jumps while mounted. Your mount did most of the work.", "Interface\\Icons\\Ability_Mount_RidingHorse", 25),

    Zone(100, { "Stormwind City", "Hurlevent" }, "stormwind_rooftops", "Stormwind Rooftop Inspector", "Perform 100 jumps in Stormwind City.", "Interface\\Icons\\Spell_Arcane_TeleportStormWind", 10),
    Zone(100, { "Orgrimmar" }, "orgrimmar_elevator", "Orgrimmar Elevator Tester", "Perform 100 jumps in Orgrimmar.", "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar", 10),
    Zone(100, { "Ironforge", "Forgefer" }, "ironforge_anvils", "Ironforge Anvil Acrobat", "Perform 100 jumps in Ironforge.", "Interface\\Icons\\Spell_Arcane_TeleportIronForge", 10),
    Zone(100, { "Thunder Bluff", "Les Pitons-du-Tonnerre" }, "thunder_bluff_edges", "Thunder Bluff Edge Dancer", "Perform 100 jumps in Thunder Bluff.", "Interface\\Icons\\Spell_Arcane_TeleportThunderBluff", 10),
    Zone(100, { "Darnassus" }, "darnassus_branches", "Darnassus Branch Bouncer", "Perform 100 jumps in Darnassus.", "Interface\\Icons\\Spell_Arcane_TeleportDarnassus", 10),
    Zone(100, { "Undercity", "Fossoyeuse" }, "undercity_knee_check", "Undercity Knee Check", "Perform 100 jumps in Undercity.", "Interface\\Icons\\Spell_Arcane_TeleportUnderCity", 10),
    Zone(100, { "The Exodar", "Exodar", "L'Exodar" }, "exodar_crystal_hops", "Exodar Crystal Hops", "Perform 100 jumps in the Exodar.", "Interface\\Icons\\Spell_Arcane_TeleportExodar", 10),
    Zone(250, { "Silvermoon City", "Lune-d'argent", "Lune d'argent" }, "silvermoon_midnight_warmup", "Silvermoon Midnight Warmup", "Perform 250 jumps in Silvermoon City.", "Interface\\Icons\\Spell_Arcane_TeleportSilvermoon", 20),
    Zone(250, { "Dalaran" }, "dalaran_lag_tester", "Dalaran Lag Tester", "Perform 250 jumps in Dalaran.", "Interface\\Icons\\Spell_Arcane_TeleportDalaran", 15),
    Zone(100, { "Valdrakken" }, "valdrakken_drake_dodger", "Valdrakken Drake Dodger", "Perform 100 jumps in Valdrakken.", "Interface\\Icons\\Ability_Mount_Drake_Bronze", 15),
    Zone(100, { "Dornogal" }, "dornogal_foundation_test", "Dornogal Foundation Test", "Perform 100 jumps in Dornogal.", "Interface\\Icons\\INV_Stone_15", 15),
    Zone(100, { "Boralus" }, "boralus_dock_bouncer", "Boralus Dock Bouncer", "Perform 100 jumps in Boralus.", "Interface\\Icons\\INV_Misc_Anchor", 10),
    Zone(100, { "Dazar'alor", "Dazaralor" }, "dazaralor_pyramid_steps", "Dazar'alor Pyramid Steps", "Perform 100 jumps in Dazar'alor.", "Interface\\Icons\\INV_Misc_Idol_02", 10),
    Zone(100, { "Shattrath City", "Shattrath" }, "shattrath_lower_city_springs", "Shattrath Springs", "Perform 100 jumps in Shattrath City.", "Interface\\Icons\\Spell_Holy_BorrowedTime", 10),
    Zone(100, { "Arcantina" }, "arcantina_bar_hops", "Arcantina Bar Hops", "Perform 100 jumps in the Arcantina.", "Interface\\Icons\\INV_Drink_18", 15),
    Zone(50, { "Goldshire", "Comté-de-l'Or", "Comte-de-l'Or" }, "goldshire_ceiling", "Goldshire Ceiling Inspector", "Perform 50 jumps in Goldshire.", "Interface\\Icons\\INV_Misc_Herb_08", 5),
    Zone(50, { "Darkmoon Island", "Île de Sombrelune", "Ile de Sombrelune" }, "darkmoon_trampoline", "Darkmoon Trampoline", "Perform 50 jumps on Darkmoon Island.", "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01", 10),
}

local byID = {}
local titleRewards = {}
for _, achievement in ipairs(ACHIEVEMENTS) do
    byID[achievement.id] = achievement
    if achievement.rewardTitle then
        titleRewards[#titleRewards + 1] = achievement.rewardTitle
    end
end

function Achievements:GetAll()
    return ACHIEVEMENTS
end

function Achievements:GetByID(id)
    return byID[id]
end

function Achievements:GetTitleRewards()
    return titleRewards
end

function Achievements:EnsureCharState(char)
    if not char then return end
    if type(char.achievements) ~= "table" then char.achievements = {} end
    if type(char.specialJumps) ~= "table" then char.specialJumps = {} end
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

function Achievements:UnlockRewardTitle(achievement, prog)
    if not achievement or not achievement.rewardTitle or not prog then return end
    if B.Leveling and B.Leveling.EnsurePlayerTitleState then
        B.Leveling:EnsurePlayerTitleState(prog)
    end
    prog.unlockedPlayerTitles = prog.unlockedPlayerTitles or {}
    prog.unlockedPlayerTitles[achievement.rewardTitle.id] = true
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
                self:UnlockRewardTitle(achievement, prog)
                newlyUnlocked[#newlyUnlocked + 1] = achievement
            end
        elseif achievement.rewardTitle and prog then
            self:UnlockRewardTitle(achievement, prog)
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
