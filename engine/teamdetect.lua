-- engine/teamdetect.lua
-- AimHubNext Multi-Game Team Detection
-- Handles Bloxstrike's non-standard team system
-- so aimbot never locks onto teammates.
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local TeamDetect = {}

-- ==========================================
-- DETECTION SETTINGS
-- ==========================================
local TEAMDETECT_DEFAULTS = {
    TeamDetectMode = "Auto",
    -- "Auto"       = try all methods in order
    -- "Standard"   = Roblox Team only
    -- "Bloxstrike" = Bloxstrike-specific only
    -- "Disabled"   = treat everyone as enemy
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for k, v in pairs(TEAMDETECT_DEFAULTS) do
        if S[k]  == nil then S[k]  = v end
        if DS[k] == nil then DS[k] = v end
    end
end

-- ==========================================
-- METHOD 1: STANDARD ROBLOX TEAM
-- Works in most games.
-- ==========================================
local function CheckStandardTeam(player)
    local lp = Services.LocalPlayer
    if player.Team ~= nil and lp.Team ~= nil then
        if player.Team == lp.Team then return true end
    end
    if player.TeamColor ~= nil and lp.TeamColor ~= nil then
        if player.TeamColor == lp.TeamColor then return true end
    end
    return false
end

-- ==========================================
-- METHOD 2: BLOXSTRIKE BILLBOARD COLOR MATCH
-- Bloxstrike renders a BillboardGui above
-- each player's head. The team color is
-- visible as a colored TextLabel or Frame
-- inside that BillboardGui.
-- We read the color and compare to local
-- player's own billboard color.
--
-- BillboardGui search path:
--   Character -> Head -> BillboardGui
--   (name varies: "NameTag","Overhead","HUD")
-- ==========================================
local function GetBloxstrikeBillboardColor(character)
    if not character then return nil end

    local head = character:FindFirstChild("Head")
    if not head then return nil end

    -- Search all BillboardGuis on the head
    for _, obj in ipairs(head:GetChildren()) do
        if obj:IsA("BillboardGui") then
            -- Look for colored frames or labels
            -- Bloxstrike uses a Frame with team color
            -- as background or a colored TextLabel
            for _, child in ipairs(obj:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                    local col = nil
                    pcall(function()
                        if child:IsA("Frame") then
                            col = child.BackgroundColor3
                        elseif child:IsA("TextLabel") then
                            col = child.TextColor3
                        end
                    end)
                    -- Filter out pure white/black/gray
                    -- (those are UI chrome, not team colors)
                    if col then
                        local r, g, b = col.R, col.G, col.B
                        local isNeutral = (
                            math.abs(r - g) < 0.05 and
                            math.abs(g - b) < 0.05
                        )
                        if not isNeutral and (r + g + b) > 0.3 then
                            return col
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function ColorsMatch(c1, c2, tolerance)
    tolerance = tolerance or 0.12
    if not c1 or not c2 then return false end
    return math.abs(c1.R - c2.R) < tolerance
       and math.abs(c1.G - c2.G) < tolerance
       and math.abs(c1.B - c2.B) < tolerance
end

-- Cache local player billboard color
-- Refreshed every 3 seconds to handle
-- team changes mid-game
local localBillboardColor    = nil
local lastBillboardRefresh   = 0
local BILLBOARD_REFRESH_RATE = 3.0

local function GetLocalBillboardColor()
    local now = tick()
    if now - lastBillboardRefresh < BILLBOARD_REFRESH_RATE then
        return localBillboardColor
    end
    lastBillboardRefresh = now

    local lp   = Services.LocalPlayer
    local char = lp.Character
    localBillboardColor = char and GetBloxstrikeBillboardColor(char)
    return localBillboardColor
end

local function CheckBloxstrikeBillboard(player)
    local localCol  = GetLocalBillboardColor()
    if not localCol then return false end

    local enemyChar = player.Character
    if not enemyChar then return false end

    local enemyCol = GetBloxstrikeBillboardColor(enemyChar)
    if not enemyCol then return false end

    return ColorsMatch(localCol, enemyCol)
end

-- ==========================================
-- METHOD 3: CHARACTER VALUE SEARCH
-- Some Bloxstrike versions store team info
-- as a StringValue or IntValue named "Team"
-- or "TeamIndex" inside the character.
-- ==========================================
local function CheckCharacterTeamValue(player)
    local lp       = Services.LocalPlayer
    local lpChar   = lp.Character
    local epChar   = player.Character
    if not lpChar or not epChar then return false end

    local valueNames = { "Team", "TeamIndex", "TeamID", "TeamValue" }

    for _, name in ipairs(valueNames) do
        local lpVal = lpChar:FindFirstChild(name)
        local epVal = epChar:FindFirstChild(name)
        if lpVal and epVal then
            local lpV, epV = nil, nil
            pcall(function() lpV = lpVal.Value end)
            pcall(function() epV = epVal.Value end)
            if lpV ~= nil and epV ~= nil and lpV == epV then
                return true
            end
        end
    end
    return false
end

-- ==========================================
-- MAIN IS-TEAMMATE FUNCTION
-- Replaces Utils.IsTeammate for games that
-- need multi-method detection.
-- ==========================================
function TeamDetect.IsTeammate(player)
    local lp = Services.LocalPlayer
    if player == lp then return true end

    local mode = State.Settings.TeamDetectMode or "Auto"

    if mode == "Disabled" then
        return false
    end

    if mode == "Standard" then
        return CheckStandardTeam(player)
    end

    if mode == "Bloxstrike" then
        -- Bloxstrike: try billboard first (most reliable),
        -- then standard as fallback
        if CheckBloxstrikeBillboard(player) then return true end
        if CheckStandardTeam(player)        then return true end
        if CheckCharacterTeamValue(player)  then return true end
        return false
    end

    -- Auto: try all methods in order of reliability
    if CheckStandardTeam(player)       then return true end
    if CheckCharacterTeamValue(player) then return true end
    if CheckBloxstrikeBillboard(player)then return true end

    return false
end

-- ==========================================
-- INIT
-- ==========================================
function TeamDetect.Init()
    EnsureSettings()
end

-- ==========================================
-- GET MODES (for UI dropdown)
-- ==========================================
function TeamDetect.GetModes()
    return { "Auto", "Standard", "Bloxstrike", "Disabled" }
end

return TeamDetect