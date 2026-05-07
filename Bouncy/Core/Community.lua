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
local STATE_GRACE_SECONDS = 2.0
local SYNC_REQUEST = "BR"

Community._lastSend = 0
Community._pendingJoinUntil = 0
Community._pendingLeaveUntil = 0
Community._lastLocalKey = nil

local function split(msg, sep)
    local out = {}
    for token in string.gmatch(msg or "", string.format("([^%s]+)", sep)) do
        out[#out + 1] = token
    end
    return out
end

local function normalizeRealm(realm)
    return tostring(realm or ""):gsub("%s+", "")
end

local function normalizeSender(sender)
    local full = tostring(sender or "")
    local n, r = string.match(full, "^([^%-]+)%-(.+)$")
    if n and r then
        local realm = normalizeRealm(r)
        return n, realm, realm .. "-" .. n
    end
    local realm = normalizeRealm(GetRealmName and GetRealmName() or "")
    return full, realm, realm .. "-" .. full
end

local function getSelfCanonical()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = normalizeRealm(GetRealmName and GetRealmName() or "Unknown")
    return realm .. "-" .. name
end

local function getChannelOrder()
    if type(GetChannelList) ~= "function" then return {} end
    local raw = { GetChannelList() }
    local out = {}
    for i = 1, #raw, 3 do
        local id = tonumber(raw[i]); local name = tostring(raw[i + 1] or "")
        if id and id > 0 and name ~= "" then out[#out + 1] = { id = id, name = name } end
    end
    return out
end

function Community:_reorderChannelLast(maxPasses)
    if type(C_ChatInfo) ~= "table" or type(C_ChatInfo.SwapChatChannelsByChannelIndex) ~= "function" then return end
    for _ = 1, (maxPasses or 1) do
        local order = getChannelOrder()
        local idx
        for i, c in ipairs(order) do if c.name == CHANNEL_NAME then idx = i break end end
        if not idx or idx >= #order then return end
        C_ChatInfo.SwapChatChannelsByChannelIndex(order[idx].id, order[idx + 1].id)
    end
end

function Community:_scheduleReorderChannelLast()
    if not C_Timer or not C_Timer.After then self:_reorderChannelLast(8); return end
    for _, d in ipairs({ 0.2, 1.0, 2.0, 4.0 }) do
        C_Timer.After(d, function() Community:_reorderChannelLast(8) end)
    end
end

function Community:_joinChannel()
    if type(JoinChannelByName) ~= "function" then return false end
    JoinChannelByName(CHANNEL_NAME)
    self:_scheduleReorderChannelLast()
    if type(ChatFrame_RemoveChannel) == "function" then
        for i = 1, (NUM_CHAT_WINDOWS or 0) do
            local frame = _G["ChatFrame" .. i]
            if frame then ChatFrame_RemoveChannel(frame, CHANNEL_NAME) end
        end
    end
    return true
end

function Community:IsJoined()
    local now = GetTime and GetTime() or 0
    if (self._pendingLeaveUntil or 0) > now then return false end
    if (self._pendingJoinUntil or 0) > now then return true end
    local id = GetChannelName(CHANNEL_NAME)
    return id and id > 0
end

function Community:JoinLeaderboardChannel()
    if not self:_joinChannel() then return false end
    local now = GetTime and GetTime() or 0
    self._pendingJoinUntil = now + STATE_GRACE_SECONDS
    self._pendingLeaveUntil = 0
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, function()
            Community:RequestSync()
            Community:Broadcast(true)
            if B.Details and B.Details.frame and B.Details.frame:IsShown() then
                B.Details:Refresh()
            end
        end)
    end
    return true
end

function Community:LeaveLeaderboardChannel()
    if type(LeaveChannelByName) ~= "function" then return false end
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then
        LeaveChannelByName(CHANNEL_NAME)
        local now = GetTime and GetTime() or 0
        self._pendingLeaveUntil = now + STATE_GRACE_SECONDS
        self._pendingJoinUntil = 0
        if B.Details and B.Details.frame and B.Details.frame:IsShown() then
            B.Details:Refresh()
        end
        return true
    end
    return false
end

function Community:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    self:JoinLeaderboardChannel()
end

function Community:_send(payload)
    local channelID = GetChannelName(CHANNEL_NAME)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage and channelID and channelID > 0 then
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "CHANNEL", channelID)
        return true
    end
    return false
end

function Community:RequestSync()
    self:_send(SYNC_REQUEST .. "|1")
end

function Community:_upsertLocalLeaderboard(char, prog, lvlData)
    local key = B.DB:CharKey()
    local lb = B.DB:GetLeaderboard()
    if self._lastLocalKey and self._lastLocalKey ~= key then
        lb[self._lastLocalKey] = nil
    end
    self._lastLocalKey = key

    lb[key] = lb[key] or {
        name = char.name or (UnitName and UnitName("player")) or key,
        realm = char.realm or (GetRealmName and GetRealmName()) or "Unknown",
        class = char.class or (select(2, UnitClass("player")) or "UNKNOWN"),
        jumps = 0,
    }
    lb[key].name = char.name or lb[key].name
    lb[key].realm = char.realm or lb[key].realm
    lb[key].class = char.class or lb[key].class
    lb[key].jumps = char.totalJumps or 0
    lb[key].level = (lvlData and lvlData.level) or lb[key].level or 1
    lb[key].petLevel = (prog and prog.level) or lb[key].petLevel or 1
    lb[key].bestStreak = char.bestStreak or 0
end

function Community:Broadcast(force)
    local now = GetTime()
    if not force and (now - (self._lastSend or 0)) < THROTTLE then
        return
    end
    self._lastSend = now

    local char = B.DB:EnsureChar() or {}
    local prog = B.DB:GetProgression() or {}
    local lvlData = B.Leveling:GetLevelForXP(prog.xp or 0, true)
    self:_upsertLocalLeaderboard(char, prog, lvlData)

    local payload = table.concat({
        "B",
        tostring((char.totalJumps or 0)),
        tostring(lvlData.level or 1),
        tostring(prog.level or 1),
        tostring(char.bestStreak or 0),
        tostring(select(2, UnitClass("player")) or "UNKNOWN"),
    }, "|")

    self:_send(payload)
end

function Community:OnAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX or type(message) ~= "string" then return end
    local parts = split(message, "|")

    if parts[1] == SYNC_REQUEST then
        self:Broadcast(true)
        return
    end
    if parts[1] ~= "B" then return end

    local senderName, senderRealm, canonical = normalizeSender(sender)
    if canonical == getSelfCanonical() then return end

    local key = "peer:" .. canonical
    local lb = B.DB:GetLeaderboard()
    lb[key] = lb[key] or { name = senderName, realm = senderRealm, class = "UNKNOWN", jumps = 0 }
    lb[key].name = senderName
    lb[key].realm = senderRealm
    lb[key].jumps = tonumber(parts[2]) or 0
    lb[key].level = tonumber(parts[3]) or 1
    lb[key].petLevel = tonumber(parts[4]) or 1
    lb[key].bestStreak = tonumber(parts[5]) or 0
    lb[key].class = parts[6] or lb[key].class

    if B.Details and B.Details.frame and B.Details.frame:IsShown() then
        B.Details:Refresh()
    end
end
