-- engine/esp.lua
-- AimHubNext ESP System
-- Multi-method team detection for Bloxstrike + generic games
-- Renders all players with friend/foe color coding
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local ESP = {}

-- ==========================================
-- ESP SETTINGS
-- ==========================================
local ESP_DEFAULTS = {
    ESPEnabled            = true,
    ESPShowTeammates      = true,   -- show teammates in different color
    ESPTeammateColor      = Color3.fromRGB(100, 180, 255),  -- blue
    ESPEnemyColor         = Color3.fromRGB(255, 80,  80),   -- red
    ESPUnknownColor       = Color3.fromRGB(200, 200, 200),  -- gray
    ESPTransparency       = 0.4,
    ESPOutlineTransparency= 0.2,
    ESPMode               = "Auto",
    -- "Auto"       = try all detection methods
    -- "Bloxstrike" = scoreboard + billboard scan
    -- "Standard"   = Roblox Team only
    -- "AllEnemy"   = everyone red, no team check
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for k, v in pairs(ESP_DEFAULTS) do
        if S[k]  == nil then S[k]  = v end
        if DS[k] == nil then DS[k] = v end
    end
end

local ESP_TAG   = "AimHubNext_ESP"

-- ==========================================
-- TEAM COLOR CACHE
-- Avoids rescanning every frame.
-- { [player] = { isTeammate=bool, color=Color3 } }
-- ==========================================
local TeamCache       = {}
local LastCacheReset  = 0
local CACHE_LIFETIME  = 4.0  -- seconds between full rescans

-- ==========================================
-- METHOD 1: STANDARD ROBLOX TEAM
-- ==========================================
local function GetStandardTeamInfo(player)
    local lp = Services.LocalPlayer
    local isTeammate = false
    local color      = nil

    if player.Team ~= nil then
        color = player.TeamColor and player.TeamColor.Color
            or nil
        if lp.Team ~= nil then
            isTeammate = (player.Team == lp.Team)
        end
    end

    return isTeammate, color
end

-- ==========================================
-- METHOD 2: BLOXSTRIKE SCOREBOARD SCAN
-- When Tab is pressed, Bloxstrike shows a
-- ScreenGui scoreboard. We scan it even when
-- it's hidden (Visible=false) because the
-- data is still populated.
--
-- Structure (typical Bloxstrike):
-- PlayerGui
--   └── ScoreboardGui (or "Scoreboard","TabMenu")
--         └── Frame
--               └── TeamFrame (x2, one per team)
--                     ├── ColorFrame (team color)
--                     └── PlayerEntry (x N)
--                           └── NameLabel
-- ==========================================
local ScoreboardCache    = {}   -- { [playerName] = {isTeammate, color} }
local LastScoreboardScan = 0
local SCOREBOARD_SCAN_RATE = 5.0

local SCOREBOARD_NAMES = {
    "ScoreboardGui", "Scoreboard", "TabMenu",
    "ScoreGui", "TeamGui", "HUDScoreboard",
    "ScoreboardFrame", "TabScoreboard",
}

local function ScanBloxstrikeScoreboard()
    local now = tick()
    if now - LastScoreboardScan < SCOREBOARD_SCAN_RATE then
        return
    end
    LastScoreboardScan = now
    ScoreboardCache    = {}

    local lp        = Services.LocalPlayer
    local playerGui = lp:FindFirstChild("PlayerGui")
    if not playerGui then return end

    -- Find the scoreboard GUI
    local scoreboardGui = nil
    for _, name in ipairs(SCOREBOARD_NAMES) do
        local found = playerGui:FindFirstChild(name, true)
        if found then
            scoreboardGui = found
            break
        end
    end
    if not scoreboardGui then return end

    -- Determine local player's team color from scoreboard
    -- by finding which team entry contains our username
    local localName   = lp.Name
    local localColor  = nil
    local teamEntries = {}  -- { color=Color3, names={string} }

    -- Deep scan for team color frames and name labels
    -- Bloxstrike team blocks have a distinctive colored header
    local function ScanFrame(frame, depth)
        if depth > 8 then return end
        for _, child in ipairs(frame:GetChildren()) do
            -- Look for frames that might be team containers
            if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                -- Check if this frame has a strong background color
                -- (team color frames have saturated colors)
                local bgColor = child.BackgroundColor3
                local r, g, b = bgColor.R, bgColor.G, bgColor.B
                local saturation = math.max(r, g, b)
                              - math.min(r, g, b)

                local isColoredFrame = saturation > 0.2
                                   and (r + g + b) > 0.3
                                   and (r + g + b) < 2.8

                if isColoredFrame then
                    -- This looks like a team color frame
                    -- Collect all player names under it
                    local entry = { color = bgColor, names = {} }
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local text = ""
                            pcall(function() text = desc.Text end)
                            -- Check if any player name matches
                            for _, plr in ipairs(
                                Services.Players:GetPlayers()
                            ) do
                                if text == plr.Name
                                or text == plr.DisplayName then
                                    table.insert(entry.names, plr.Name)
                                end
                            end
                        end
                    end
                    if #entry.names > 0 then
                        table.insert(teamEntries, entry)
                    end
                end
                ScanFrame(child, depth + 1)
            end
        end
    end

    pcall(ScanFrame, scoreboardGui, 0)

    -- Determine which team entry the local player belongs to
    for _, entry in ipairs(teamEntries) do
        for _, name in ipairs(entry.names) do
            if name == localName then
                localColor = entry.color
                break
            end
        end
        if localColor then break end
    end

    -- Build cache: is each player on local player's team?
    for _, entry in ipairs(teamEntries) do
        local entryIsLocalTeam = localColor ~= nil
            and math.abs(entry.color.R - localColor.R) < 0.1
            and math.abs(entry.color.G - localColor.G) < 0.1
            and math.abs(entry.color.B - localColor.B) < 0.1

        for _, name in ipairs(entry.names) do
            ScoreboardCache[name] = {
                isTeammate = entryIsLocalTeam,
                color      = entry.color,
            }
        end
    end
end

local function GetBloxstrikeTeamInfo(player)
    -- Trigger rescan if needed
    pcall(ScanBloxstrikeScoreboard)

    local cached = ScoreboardCache[player.Name]
    if cached then
        return cached.isTeammate, cached.color
    end
    return nil, nil  -- unknown
end

-- ==========================================
-- METHOD 3: BILLBOARD COLOR MATCH
-- (Carried over from teamdetect.lua,
--  used as ESP-specific fallback)
-- ==========================================
local function GetBillboardColor(character)
    if not character then return nil end
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    for _, obj in ipairs(head:GetChildren()) do
        if obj:IsA("BillboardGui") then
            for _, child in ipairs(obj:GetDescendants()) do
                local col = nil
                pcall(function()
                    if child:IsA("Frame") then
                        col = child.BackgroundColor3
                    elseif child:IsA("TextLabel") then
                        col = child.TextColor3
                    end
                end)
                if col then
                    local r, g, b   = col.R, col.G, col.B
                    local isNeutral = math.abs(r-g) < 0.05
                                  and math.abs(g-b) < 0.05
                    if not isNeutral and (r+g+b) > 0.3
                    and (r+g+b) < 2.8 then
                        return col
                    end
                end
            end
        end
    end
    return nil
end

local LocalBillboardColor   = nil
local LastBillboardRefresh  = 0

local function GetLocalBillboardColor()
    local now = tick()
    if now - LastBillboardRefresh < 3.0 then
        return LocalBillboardColor
    end
    LastBillboardRefresh = now
    local lp   = Services.LocalPlayer
    local char = lp.Character
    LocalBillboardColor = char and GetBillboardColor(char) or nil
    return LocalBillboardColor
end

local function ColorsMatch(c1, c2)
    if not c1 or not c2 then return false end
    return math.abs(c1.R - c2.R) < 0.12
       and math.abs(c1.G - c2.G) < 0.12
       and math.abs(c1.B - c2.B) < 0.12
end

local function GetBillboardTeamInfo(player)
    local localCol = GetLocalBillboardColor()
    if not localCol then return nil, nil end
    local enemyChar = player.Character
    if not enemyChar then return nil, nil end
    local enemyCol = GetBillboardColor(enemyChar)
    if not enemyCol then return nil, nil end
    local isTeammate = ColorsMatch(localCol, enemyCol)
    return isTeammate, enemyCol
end

-- ==========================================
-- METHOD 4: CHARACTER VALUE SCAN
-- ==========================================
local function GetCharacterValueTeamInfo(player)
    local lp     = Services.LocalPlayer
    local lpChar = lp.Character
    local epChar = player.Character
    if not lpChar or not epChar then return nil, nil end

    local valueNames = { "Team","TeamIndex","TeamID","TeamValue","TeamName" }
    for _, name in ipairs(valueNames) do
        local lpVal = lpChar:FindFirstChild(name)
        local epVal = epChar:FindFirstChild(name)
        if lpVal and epVal then
            local lpV, epV = nil, nil
            pcall(function() lpV = lpVal.Value end)
            pcall(function() epV = epVal.Value end)
            if lpV ~= nil and epV ~= nil then
                return lpV == epV, nil
            end
        end
    end
    return nil, nil
end

-- ==========================================
-- MASTER TEAM RESOLVER
-- Returns: isTeammate (bool), displayColor (Color3)
-- ==========================================
local function ResolvePlayerTeam(player)
    local S    = State.Settings
    local mode = S.ESPMode or "Auto"
    local lp   = Services.LocalPlayer

    if player == lp then
        return true, Color3.fromRGB(100, 180, 255)
    end

    if mode == "AllEnemy" then
        return false, S.ESPEnemyColor
    end

    -- Check team cache first
    local cached = TeamCache[player]
    if cached then
        return cached.isTeammate, cached.color
    end

    local isTeammate = nil
    local color      = nil

    if mode == "Bloxstrike" or mode == "Auto" then
        -- Try scoreboard first (most reliable for Bloxstrike)
        local sbTeam, sbColor = GetBloxstrikeTeamInfo(player)
        if sbTeam ~= nil then
            isTeammate = sbTeam
            color      = sbColor
        end
    end

    if isTeammate == nil and (mode == "Standard" or mode == "Auto") then
        -- Standard Roblox team
        local stTeam, stColor = GetStandardTeamInfo(player)
        isTeammate = stTeam
        color      = stColor
    end

    if isTeammate == nil and mode == "Auto" then
        -- Character value fallback
        local cvTeam, _ = GetCharacterValueTeamInfo(player)
        if cvTeam ~= nil then isTeammate = cvTeam end
    end

    if isTeammate == nil and mode == "Auto" then
        -- Billboard color last resort
        local bbTeam, bbColor = GetBillboardTeamInfo(player)
        if bbTeam ~= nil then
            isTeammate = bbTeam
            color      = bbColor
        end
    end

    -- Default: unknown = treat as enemy, show gray
    if isTeammate == nil then
        isTeammate = false
        color      = S.ESPUnknownColor
    end

    -- Assign display color based on result
    if color == nil then
        color = isTeammate and S.ESPTeammateColor or S.ESPEnemyColor
    end

    -- Cache result
    TeamCache[player] = { isTeammate = isTeammate, color = color }

    return isTeammate, color
end

-- ==========================================
-- APPLY ESP VISUALS
-- Renders ALL players with correct colors.
-- Teammates shown in blue (or hidden if
-- ESPShowTeammates = false).
-- Enemies shown in red.
-- Unknown shown in gray.
-- ==========================================
function ESP.ApplyVisuals()
    local S       = State.Settings
    local Players = Services.Players
    local lp      = Services.LocalPlayer

    if not S.ESPEnabled then
        ESP.Cleanup()
        return
    end

    -- Reset cache periodically
    local now = tick()
    if now - LastCacheReset > CACHE_LIFETIME then
        LastCacheReset = now
        TeamCache      = {}
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end

        local char = player.Character
        if not char then continue end

        local hrp       = char:FindFirstChild("HumanoidRootPart")
        local hum       = char:FindFirstChildOfClass("Humanoid")
        local highlight = char:FindFirstChild(ESP_TAG)

        -- Skip dead players
        if not hrp or not hum or hum.Health <= 0 then
            if highlight then highlight:Destroy() end
            continue
        end

        -- Resolve team
        local isTeammate, displayColor = pcall(ResolvePlayerTeam, player)
        if not isTeammate then
            -- pcall failed, treat as enemy
            isTeammate   = false
            displayColor = S.ESPEnemyColor
        else
            -- pcall succeeded, isTeammate is actually the bool result
            -- and displayColor is the color
            -- (pcall returns ok, result1, result2...)
            -- Fix: re-call without pcall wrapping the results
            local ok2, tm2, col2 = pcall(ResolvePlayerTeam, player)
            if ok2 then
                isTeammate   = tm2
                displayColor = col2
            end
        end

        -- Hide teammates if setting disabled
        if isTeammate and not S.ESPShowTeammates then
            if highlight then highlight:Destroy() end
            continue
        end

        -- Create or update highlight
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name               = ESP_TAG
            highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent             = char
        end

        highlight.FillColor          = displayColor or S.ESPEnemyColor
        highlight.OutlineColor       = displayColor or S.ESPEnemyColor
        highlight.FillTransparency   = math.clamp(S.ESPTransparency, 0, 1)
        highlight.OutlineTransparency= math.clamp(S.ESPOutlineTransparency, 0, 1)
    end
end

-- ==========================================
-- CLEANUP
-- ==========================================
function ESP.Cleanup()
    local Players = Services.Players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local h = player.Character:FindFirstChild(ESP_TAG)
            if h then pcall(function() h:Destroy() end) end
        end
    end
    TeamCache          = {}
    ScoreboardCache    = {}
    LocalBillboardColor= nil
end

-- ==========================================
-- INIT
-- ==========================================
function ESP.Init()
    EnsureSettings()
end

-- ==========================================
-- TICK (called every frame from lifecycle)
-- ==========================================
function ESP.Tick()
    pcall(ESP.ApplyVisuals)
end

-- ==========================================
-- GET MODES (for UI dropdown)
-- ==========================================
function ESP.GetModes()
    return { "Auto", "Bloxstrike", "Standard", "AllEnemy" }
end

return ESP