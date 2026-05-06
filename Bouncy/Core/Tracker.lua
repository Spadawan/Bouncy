-------------------------------------------------------------------------------
-- Core/Tracker.lua
-- Jump detection via IsFalling() with strict airtime + cooldown filters.
-- Sit tracking removed (too unreliable across all WoW versions/situations).
-- Cross-version: Retail, Classic Era, TBC, Wrath, Cata, MoP.
-------------------------------------------------------------------------------

local B        = _G.Bouncy
B.Tracker      = {}
local Tracker  = B.Tracker

local streak        = 0
local streakTimer   = nil
local lastJumpTime  = 0
local wasInAir      = false
local airborneStart = nil

-- A real jump keeps IsFalling() true for at least this long.
-- Walking over a bench/rock/slope: typically 80-180ms.
-- Shortest real jump on flat ground: ~350ms.
-- Set to 250ms: strict enough to kill almost all false positives,
-- generous enough to catch jumps on steep terrain.
local MIN_JUMP_DURATION = 0.25   -- 250ms

-- Hard cooldown: even if IsFalling fires again, we cannot count two jumps
-- closer than this. WoW's server-side jump cooldown is ~600ms.
local MIN_JUMP_INTERVAL = 0.65   -- 650ms

local callbacks = {}
local sessionStart = 0
local sessionJumps = 0

function Tracker:RegisterCallback(fn)
    table.insert(callbacks, fn)
end

local function Fire(event, data)
    for _, fn in ipairs(callbacks) do pcall(fn, event, data) end
end

local function GetStreakMultiplier(n)
    for _, bucket in ipairs(B.STREAK_MULTIPLIERS) do
        if n >= bucket.min and n <= bucket.max then
            return bucket.mult, bucket.color
        end
    end
    return 1.0, "ffffff"
end

local function BreakStreak(reason)
    if streak > 0 then
        B.DB:RecordStreak(streak)
        local newAchievements = B.Achievements and B.Achievements:Evaluate(B.DB:GetChar(), B.DB:GetProgression()) or nil
        Fire("STREAK_BREAK", { streak = streak, reason = reason, newAchievements = newAchievements })
    end
    streak = 0
    if streakTimer then
        streakTimer:Cancel()
        streakTimer = nil
    end
end

local function OnJump()
    local now  = GetTime()
    local zone = GetZoneText() or "Unknown"

    -- Hard interval cooldown (second filter after MIN_JUMP_DURATION)
    if (now - lastJumpTime) < MIN_JUMP_INTERVAL then return end

    local delta = now - lastJumpTime
    lastJumpTime = now

    if streak > 0 and delta <= B.STREAK_WINDOW then
        streak = streak + 1
    else
        if streak > 0 then BreakStreak("timeout") end
        streak = 1
    end

    if streakTimer then streakTimer:Cancel() end
    streakTimer = C_Timer.NewTimer(B.STREAK_WINDOW + 0.05, function()
        BreakStreak("timeout")
        streakTimer = nil
        Fire("OVERLAY_REFRESH", {})
    end)

    local mult, multColor = GetStreakMultiplier(streak)
    local baseXP = math.floor(2 * mult)
    local prog = B.DB:GetProgression()
    local oldLvlData = B.Leveling:GetLevelForXP(prog.xp or 0, true)
    local creatureLevel = prog.level or 1
    local bonusPct = (B.Leveling and B.Leveling.GetCreatureBonusPercent and B.Leveling:GetCreatureBonusPercent(creatureLevel)) or 0
    local bonusExact = (baseXP * (bonusPct * 0.01)) + (prog.bonusXPFraction or 0)
    local bonusXP = math.floor(bonusExact)
    prog.bonusXPFraction = bonusExact - bonusXP
    local xpGained = baseXP + bonusXP
    B.DB:AddXP(xpGained)
    local newLvlData = B.Leveling:GetLevelForXP(prog.xp or 0, true)

    B.DB:RecordJump(zone)
    local newAchievements = B.Achievements and B.Achievements:Evaluate(B.DB:GetChar(), prog) or nil
    local newLevel  = nil
    local newTitles = nil
    if (newLvlData.level or 1) > (oldLvlData.level or 1) then
        newTitles = B.Leveling:UnlockPlayerTitlesForLevelRange(prog, oldLvlData.level or 1, newLvlData.level or 1)
        if #newTitles == 0 then newTitles = nil end
    end

    Fire("JUMP", {
        zone      = zone,
        streak    = streak,
        mult      = mult,
        multColor = multColor,
        xpGained  = xpGained,
        baseXP    = baseXP,
        bonusXP   = bonusXP,
        prog      = prog,
        levelUp   = newLevel,
        newTitles = newTitles,
        newTitle  = newTitles and newTitles[1] or nil,
        newAchievements = newAchievements,
    })
end

function Tracker:Init()
    streak        = 0
    sessionStart  = GetTime()
    sessionJumps  = 0
    lastJumpTime  = 0
    wasInAir      = false
    airborneStart = nil

    local pollFrame = CreateFrame("Frame", "Bouncy_TrackerFrame")

    pollFrame:SetScript("OnUpdate", function(self, dt)
        -- Trailing-edge detection with strict duration + interval guards
        local inAir = IsFalling()
        if inAir and not wasInAir then
            airborneStart = GetTime()
        elseif not inAir and wasInAir then
            if airborneStart and (GetTime() - airborneStart) >= MIN_JUMP_DURATION then
                OnJump()
                sessionJumps = sessionJumps + 1
            end
            airborneStart = nil
        end
        wasInAir = inAir
    end)
end

function Tracker:GetStreak() return streak end
function Tracker:GetSessionJumps() return sessionJumps end
function Tracker:GetSessionDuration() return math.max(1, GetTime() - (sessionStart or GetTime())) end
