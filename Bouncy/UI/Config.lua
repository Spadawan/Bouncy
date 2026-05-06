-------------------------------------------------------------------------------
-- UI/Config.lua
-- Config is now embedded in the Details window as the "Customize" tab.
-- This file just provides the Config:Toggle() shim so /bouncy config
-- still works.
-------------------------------------------------------------------------------

local B      = _G.Bouncy
B.Config     = {}
local Config = B.Config

function Config:Init()
    -- No standalone window anymore; settings are in Details > Customize tab.
end

function Config:Toggle()
    -- Open Details and switch to the Customize tab (tab 5)
    if B.Details then
        B.Details:Show()
        B.Details:ShowPanel(5)
        if B.Overlay and B.Overlay.frame then
            B.Overlay:Show()
        end
    end
end
