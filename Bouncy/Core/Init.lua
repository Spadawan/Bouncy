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

eventFrame:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" then
        if arg1 == B.ADDON_NAME then
            B.DB:Init()
        end

    elseif event == "PLAYER_LOGIN" then
        -- Ensure char entry exists before any UI reads it
        B.DB:EnsureChar()

        B.Tracker:Init()
        B.Overlay:Init()
        B.Details:Init()
        B.Config:Init()

        print(string.format(
            "|cff%sBouncy|r v%s loaded.  |cff%s/bouncy help|r for commands.",
            B.COLOR.TITLE, B.VERSION, B.COLOR.LEVEL_UP))

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh overlay after loading screens
        if B.Overlay and B.Overlay.frame then
            B.Overlay:Refresh()
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
    local cmd = strtrim(msg or ""):lower()

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
        B.DB:ResetChar()
        if B.Overlay then B.Overlay:Refresh() end
        print(string.format("|cff%sBouncy|r Character data reset.", B.COLOR.TITLE))

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
        print(string.format("|cff%s/bouncy help|r         Show this help", B.COLOR.LEVEL_UP))
        print(string.format("|cff%sRight-click the overlay|r -> Statistics", B.COLOR.DIM))

    else
        print(string.format("|cff%sBouncy|r Unknown command : \"%s\". Type |cff%s/bouncy help|r.",
            B.COLOR.TITLE, cmd, B.COLOR.LEVEL_UP))
    end
end
