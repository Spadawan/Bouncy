-------------------------------------------------------------------------------
-- Core/Community.lua
-- Community sync via the same addon channel used by UGC.
-------------------------------------------------------------------------------

local B = _G.Bouncy
B.Community = {}
local Community = B.Community

local PREFIX = "UGC_SYNC"
local CHANNEL_NAME = "UGC"
local THROTTLE = 20

Community._lastSend = 0

local function split(msg, sep)
    local out = {}
    for token in string.gmatch(msg or "", string.format("([^%s]+)", sep)) do
        out[#out + 1] = token
    end
    return out
end

function Community:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    if type(JoinChannelByName) == "function" then
        JoinChannelByName(CHANNEL_NAME)
    end
end

function Community:Broadcast(force)
    local now = GetTime()
    if not force and (now - (self._lastSend or 0)) < THROTTLE then
        return
    end
    self._lastSend = now

    local char = B.DB:GetChar() or {}
    local prog = B.DB:GetProgression() or {}
    local lvlData = B.Leveling:GetLevelForXP(prog.xp or 0)
    local payload = table.concat({
        "B",
        tostring((char.totalJumps or 0)),
        tostring(lvlData.level or 1),
        tostring(prog.level or 1),
        tostring(char.bestStreak or 0),
        tostring(select(2, UnitClass("player")) or "UNKNOWN"),
    }, "|")

    local channelID = GetChannelName(CHANNEL_NAME)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage and channelID and channelID > 0 then
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "CHANNEL", channelID)
    end
end

function Community:OnAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX or type(message) ~= "string" then return end
    local parts = split(message, "|")
    if parts[1] ~= "B" then return end

    local senderName = sender or "Unknown"
    local key = "peer:" .. senderName
    local lb = B.DB:GetLeaderboard()
    lb[key] = lb[key] or { name = senderName, realm = "", class = "UNKNOWN", jumps = 0 }
    lb[key].jumps = tonumber(parts[2]) or 0
    lb[key].level = tonumber(parts[3]) or 1
    lb[key].petLevel = tonumber(parts[4]) or 1
    lb[key].bestStreak = tonumber(parts[5]) or 0
    lb[key].class = parts[6] or lb[key].class
end

