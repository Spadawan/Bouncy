-------------------------------------------------------------------------------
-- Core/Init.lua
-- Main event frame. Wires all modules together, handles WoW events,
-- registers /bouncy slash command. Must load last.
-------------------------------------------------------------------------------

local B = _G.Bouncy

local eventFrame = CreateFrame("Frame", "Bouncy_InitFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)

    if event == "ADDON_LOADED" then
        if arg1 == B.ADDON_NAME then
            B.DB:Init()
        end

    elseif event == "PLAYER_LOGIN" then
        -- Ensure char entry exists before any UI reads it
        B.DB:EnsureChar()
        if B.Achievements then B.Achievements:InitChatLinks() end

        B.Tracker:Init()
        if B.Community then B.Community:Init() end
        B.Overlay:Init()
        B.Details:Init()
        B.Config:Init()

        print(string.format(
            "|cff%sBouncy|r v%s loaded.  |cff%s/bouncy help|r for commands.",
            B.COLOR.TITLE, B.VERSION, B.COLOR.LEVEL_UP))

        if B.Tracker and B.Community and B.Tracker.RegisterCallback then
            B.Tracker:RegisterCallback(function(event)
                if event == "JUMP" then
                    B.Community:Broadcast(false)
                end
            end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh overlay after loading screens
        if B.Overlay and B.Overlay.frame then
            B.Overlay:Refresh()
        end
        if B.Community then B.Community:Broadcast(true) end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, ...
        if B.Community then
            B.Community:OnAddonMessage(prefix, message, channel, sender)
        end

    elseif event == "PLAYER_LOGOUT" then
        if B.Overlay and B.Overlay.frame then
            local f = B.Overlay.frame
            local point, _, _, x, y = f:GetPoint()
            B.DB:SaveOverlayPosition(point or "CENTER", x or 0, y or 200)
        end
    end
end)

-------------------------------------------------------------------------------
-- /bouncy slash command
-------------------------------------------------------------------------------
SLASH_BOUNCY1 = "/bouncy"
SLASH_BOUNCY2 = "/bcy"

SlashCmdList["BOUNCY"] = function(msg)
    local raw = strtrim(msg or "")
    local cmd, rest = raw:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        B.Details:Toggle()

    elseif cmd == "show" then
        B.Overlay:Show()
        print(string.format("|cff%sBouncy|r Overlay shown.", B.COLOR.TITLE))

    elseif cmd == "hide" then
        B.Overlay:Hide()
        print(string.format("|cff%sBouncy|r Overlay hidden.", B.COLOR.TITLE))

    elseif cmd == "stats" or cmd == "details" then
        B.Details:Toggle()

    elseif cmd == "config" or cmd == "options" then
        B.Config:Toggle()

    elseif cmd == "reset" then
        B.DB:ResetCharWithConfirmation()

    elseif cmd == "xp" then
        local amount = tonumber(rest or "")
        if not amount then
            print(string.format("|cff%sUsage: /bouncy xp <amount>|r", B.COLOR.DIM))
            return
        end
        local prog = B.DB:AddXP(math.floor(amount))
        if B.Achievements then B.Achievements:Evaluate(B.DB:GetChar(), prog) end
        if B.Overlay then B.Overlay:Refresh() end
        if B.Details and B.Details.frame and B.Details.frame:IsShown() then B.Details:Refresh() end
        print(string.format("|cff%sBouncy|r Added %d XP.", B.COLOR.TITLE, math.floor(amount)))

    elseif cmd == "evolve" then
        local prog = B.DB:GetProgression()
        if B.Leveling:CanEvolve(prog) then
            local req = B.Leveling:GetCreatureXPRequirement(prog.level or 1)
            prog.creatureXP = math.max(0, (prog.creatureXP or 0) - req)
            prog.level = (prog.level or 1) + 1
            if B.Achievements then B.Achievements:Evaluate(B.DB:GetChar(), prog) end
            if B.Overlay then B.Overlay:Refresh() end
            if B.Details and B.Details.frame and B.Details.frame:IsShown() then B.Details:Refresh() end
            print(string.format("|cff%sBouncy|r Evolved to level %d.", B.COLOR.TITLE, prog.level))
        else
            print(string.format("|cff%sBouncy|r Not ready to evolve yet.", B.COLOR.TITLE))
        end

    elseif cmd == "type" then
        local wanted = rest and rest:lower() or ""
        for _, t in ipairs(B.CREATURE_TYPES or {}) do
            if t:lower() == wanted then
                B.DB:SetCreatureType(t)
                if B.Details and B.Details.frame and B.Details.frame:IsShown() then B.Details:Refresh() end
                print(string.format("|cff%sBouncy|r Creature type set to %s.", B.COLOR.TITLE, t))
                return
            end
        end
        print(string.format("|cff%sUsage: /bouncy type astral|fire|water|lunar|r", B.COLOR.DIM))

    elseif cmd == "version" then
        print(string.format("|cff%sBouncy|r v%s", B.COLOR.TITLE, B.VERSION))

    elseif cmd == "help" then
        print(string.format("|cff%s————— BOUNCY %s —————|r", B.COLOR.TITLE, B.VERSION))
        print(string.format("|cff%s/bouncy|r              Open/close statistics", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy show|r         Show overlay", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy hide|r         Hide overlay", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy stats|r        Open statistics", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy config|r       Open settings", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy reset|r        Reset this character", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy xp 250|r       Add XP for testing", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy evolve|r       Force next evolution", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy type astral|r  Set creature type", B.COLOR.LEVEL_UP))
        print(string.format("|cff%s/bouncy help|r         Show this help", B.COLOR.LEVEL_UP))
        print(string.format("|cff%sRight-click the overlay|r -> Statistics", B.COLOR.DIM))

    else
        print(string.format("|cff%sBouncy|r Unknown command : \"%s\". Type |cff%s/bouncy help|r.",
            B.COLOR.TITLE, cmd, B.COLOR.LEVEL_UP))
    end
end
